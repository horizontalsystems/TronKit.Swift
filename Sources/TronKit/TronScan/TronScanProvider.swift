import Alamofire
import BigInt
import Foundation
import HsToolKit

class TronScanProvider {
    private let networkManager: NetworkManager
    private let baseUrl: String
    private let apiKey: String?
    private let pageLimit = 50

    // Cursor format: "{effectiveMinTimestamp}:{start}"
    // When approaching the 10K offset cap, effectiveMinTimestamp shifts to the last-seen timestamp
    // so the next window starts fresh from that point.
    private struct Cursor {
        let effectiveMinTimestamp: Int
        let start: Int

        static func parse(_ string: String?) -> Cursor? {
            guard let string else { return nil }
            let parts = string.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2,
                  let ts = Int(parts[0]),
                  let start = Int(parts[1])
            else { return nil }
            return Cursor(effectiveMinTimestamp: ts, start: start)
        }

        func encoded() -> String {
            "\(effectiveMinTimestamp):\(start)"
        }
    }

    init(networkManager: NetworkManager, baseUrl: String = "https://apilist.tronscanapi.com/api/", apiKey: String?) {
        self.networkManager = networkManager
        self.baseUrl = baseUrl
        self.apiKey = apiKey
    }

    private func fetch(path: String, parameters: Parameters) async throws -> [String: Any] {
        var parameters = parameters
        if let apiKey {
            parameters["apikey"] = apiKey
        }

        let json = try await networkManager.fetchJson(
            url: "\(baseUrl)\(path)",
            method: .get,
            parameters: parameters,
            responseCacherBehavior: .doNotCache
        )

        guard let map = json as? [String: Any] else {
            throw RequestError.invalidResponse
        }

        return map
    }

    // Builds the next cursor after receiving `count` records from `currentCursor`.
    // Returns nil if there are no more pages.
    private func nextCursor(currentCursor: Cursor, receivedCount: Int, lastTimestamp: Int?) -> String? {
        guard receivedCount >= pageLimit else {
            return nil // last page
        }

        let nextStart = currentCursor.start + pageLimit

        // Approaching the 10K offset cap — shift the timestamp window
        if nextStart >= 9950, let lastTimestamp {
            return Cursor(effectiveMinTimestamp: lastTimestamp, start: 0).encoded()
        }

        return Cursor(effectiveMinTimestamp: currentCursor.effectiveMinTimestamp, start: nextStart).encoded()
    }
}

// MARK: - IHistoryProvider

extension TronScanProvider: IHistoryProvider {
    func fetchAccountInfo(address: String) async throws -> AccountInfoResponse {
        let map = try await fetch(path: "account", parameters: ["address": address])

        let balance = (map["balance"] as? Int) ?? 0

        var trc20 = [Address: BigUInt]()
        if let tokenBalances = map["trc20token_balances"] as? [[String: Any]] {
            for token in tokenBalances {
                guard let contractAddress = token["tokenId"] as? String,
                      let balanceStr = token["balance"] as? String,
                      let address = try? Address(address: contractAddress),
                      let value = BigUInt(balanceStr, radix: 10)
                else { continue }
                trc20[address] = value
            }
        }

        return AccountInfoResponse(balance: balance, trc20: trc20)
    }

    func fetchTransactions(address: String, minTimestamp: Int, cursor: String?) async throws -> ([ITransactionResponse], nextCursor: String?) {
        let resolved = Cursor.parse(cursor) ?? Cursor(effectiveMinTimestamp: minTimestamp, start: 0)

        let map = try await fetch(path: "transaction", parameters: [
            "address": address,
            "start_timestamp": resolved.effectiveMinTimestamp,
            "confirm": 0,
            "sort": "timestamp",
            "limit": pageLimit,
            "start": resolved.start,
        ])

        guard let data = map["data"] as? [[String: Any]] else {
            return ([], nil)
        }

        let transactions: [ITransactionResponse] = data.compactMap { json -> TransactionResponse? in
            guard let hash = (json["hash"] as? String).flatMap({ $0.hs.hexData }),
                  let timestamp = json["timestamp"] as? Int,
                  let block = json["block"] as? Int
            else { return nil }

            let contractRet = (json["contractRet"] as? String) ?? "SUCCESS"
            let cost = json["cost"] as? [String: Any]
            let fee = cost.flatMap { $0["fee"] as? Int } ?? 0
            let netUsage = cost.flatMap { $0["net_usage"] as? Int } ?? 0
            let netFee = cost.flatMap { $0["net_fee"] as? Int } ?? 0
            let energyUsage = cost.flatMap { $0["energy_usage"] as? Int } ?? 0
            let energyFee = cost.flatMap { $0["energy_fee"] as? Int } ?? 0
            let energyUsageTotal = cost.flatMap { $0["energy_usage_total"] as? Int } ?? 0

            // Reconstruct raw_data.contract in TronGrid-compatible format so ContractHelper can parse it
            var contractsMap: [[String: Any]]? = nil
            if let contractType = json["contractType"] as? Int,
               let typeString = TronScanProvider.contractTypeName(contractType),
               let contractData = json["contractData"] as? [String: Any] {
                contractsMap = [[
                    "type": typeString,
                    "parameter": [
                        "value": contractData,
                        "type_url": "type.googleapis.com/protocol.\(typeString)",
                    ],
                ]]
            }

            return TransactionResponse(
                txId: hash,
                blockTimestamp: timestamp,
                blockNumber: block,
                ret: [TransactionResponse.Ret(contractRet: contractRet, fee: fee)],
                netUsage: netUsage,
                netFee: netFee,
                energyUsage: energyUsage,
                energyFee: energyFee,
                energyUsageTotal: energyUsageTotal,
                contractsMap: contractsMap
            )
        }

        let lastTimestamp = (data.last?["timestamp"] as? Int)
        let next = nextCursor(currentCursor: resolved, receivedCount: data.count, lastTimestamp: lastTimestamp)
        return (transactions, next)
    }

    func fetchTrc20Transactions(address: String, minTimestamp: Int, cursor: String?) async throws -> ([Trc20TransactionResponse], nextCursor: String?) {
        let resolved = Cursor.parse(cursor) ?? Cursor(effectiveMinTimestamp: minTimestamp, start: 0)

        let map = try await fetch(path: "token_trc20/transfers", parameters: [
            "relatedAddress": address,
            "start_timestamp": resolved.effectiveMinTimestamp,
            "limit": pageLimit,
            "start": resolved.start,
            "direction": 0,
            "db_version": 1,
        ])

        guard let transfers = map["token_transfers"] as? [[String: Any]] else {
            return ([], nil)
        }

        let transactions: [Trc20TransactionResponse] = transfers.compactMap { json -> Trc20TransactionResponse? in
            guard let txIdHex = json["transaction_id"] as? String,
                  let txId = txIdHex.hs.hexData,
                  let blockTs = json["block_ts"] as? Int,
                  let fromStr = json["from_address"] as? String,
                  let toStr = json["to_address"] as? String,
                  let from = try? Address(address: fromStr),
                  let to = try? Address(address: toStr),
                  let contractAddress = json["contract_address"] as? String,
                  let tokenAddress = try? Address(address: contractAddress),
                  let quantStr = json["quant"] as? String,
                  let value = BigUInt(quantStr, radix: 10),
                  let tokenInfo = json["tokenInfo"] as? [String: Any]
            else { return nil }

            let symbol = (tokenInfo["tokenAbbr"] as? String) ?? ""
            let name = (tokenInfo["tokenName"] as? String) ?? ""
            let decimals = (tokenInfo["tokenDecimal"] as? Int) ?? 0

            return Trc20TransactionResponse(
                transactionId: txId,
                blockTimestamp: blockTs,
                from: from,
                to: to,
                type: "Transfer",
                value: value,
                tokenInfo: Trc20TransactionResponse.TokenInfo(symbol: symbol, address: tokenAddress, decimals: decimals, name: name)
            )
        }

        let lastTimestamp = (transfers.last?["block_ts"] as? Int)
        let next = nextCursor(currentCursor: resolved, receivedCount: transfers.count, lastTimestamp: lastTimestamp)
        return (transactions, next)
    }
}

extension TronScanProvider {
    // Maps TronScan integer contractType to the string name used by ContractHelper
    private static func contractTypeName(_ type: Int) -> String? {
        switch type {
        case 1: return "TransferContract"
        case 2: return "TransferAssetContract"
        case 4: return "VoteWitnessContract"
        case 11: return "AssetIssueContract"
        case 13: return "AccountUpdateContract"
        case 15: return "FreezeBalanceContract"
        case 16: return "UnfreezeBalanceContract"
        case 17: return "WithdrawBalanceContract"
        case 31: return "TriggerSmartContract"
        case 41: return "FreezeBalanceV2Contract"
        case 42: return "UnfreezeBalanceV2Contract"
        case 44: return "DelegateResourceContract"
        case 45: return "UnDelegateResourceContract"
        default: return nil
        }
    }

    enum RequestError: Error {
        case invalidResponse
    }
}
