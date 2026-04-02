import Alamofire
import BigInt
import Foundation
import HsToolKit

class TronGridProvider {
    private let networkManager: NetworkManager
    private let baseUrl: String
    private let syncedState: SyncedState

    private let authHeaders: HTTPHeaders
    private var currentRpcId = 0
    private let pageLimit = 200

    init(networkManager: NetworkManager, baseUrl: String, apiKeys: [String], auth: String? = nil) {
        self.networkManager = networkManager
        self.baseUrl = baseUrl.hasSuffix("/") ? baseUrl : baseUrl + "/"

        syncedState = SyncedState(apiKeys: apiKeys)

        var headers = HTTPHeaders()

        if let auth {
            let base64 = Data(auth.utf8).base64EncodedString()
            headers.add(.init(name: "Authorization", value: "Basic \(base64)"))
        }

        authHeaders = headers
    }

    private func currentHeaders() async -> HTTPHeaders {
        var headers = authHeaders
        if let apiKey = await syncedState.getApiKey() {
            headers.add(.init(name: "TRON-PRO-API-KEY", value: apiKey))
        }
        return headers
    }

    private func rpcApiFetch(parameters: [String: Any]) async throws -> Any {
        let headers = await currentHeaders()
        return try await networkManager.fetchJson(
            url: baseUrl + "jsonrpc",
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: headers,
            interceptor: self,
            responseCacherBehavior: .doNotCache
        )
    }

    private func extensionApiFetch(path: String, parameters: Parameters) async throws -> (data: [[String: Any]], meta: [String: Any]) {
        let headers = await currentHeaders()
        let json = try await networkManager.fetchJson(url: "\(baseUrl)\(path)", method: .get, parameters: parameters, headers: headers, responseCacherBehavior: .doNotCache)

        guard let map = json as? [String: Any] else {
            throw RequestError.invalidResponse
        }

        guard let status = map["success"] as? Bool, status else {
            throw RequestError.invalidStatus
        }

        guard let data = map["data"] as? [[String: Any]] else {
            throw RequestError.invalidResponse
        }

        guard let meta = map["meta"] as? [String: Any] else {
            throw RequestError.invalidResponse
        }

        return (data, meta)
    }

    private func nodeApiFetch(path: String, parameters: Parameters) async throws -> [String: Any] {
        let headers = await currentHeaders()
        let json = try await networkManager.fetchJson(url: "\(baseUrl)\(path)", method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers, responseCacherBehavior: .doNotCache)

        guard let map = json as? [String: Any] else {
            throw RequestError.invalidResponse
        }

        return map
    }

    private func nodeApiFetchChecked(path: String, parameters: Parameters) async throws -> [String: Any] {
        let map = try await nodeApiFetch(path: path, parameters: parameters)

        guard let resultMap = map["result"] as? [String: Any],
              let successResult = resultMap["result"] as? Bool
        else {
            throw RequestError.invalidResponse
        }

        guard successResult else {
            throw RequestError.fullNodeApiError(
                code: (resultMap["code"] as? String) ?? "Unknown",
                message: (resultMap["message"] as? String) ?? ""
            )
        }

        return map
    }
}

extension TronGridProvider: RequestInterceptor {
    func retry(_: Request, for _: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        if case let JsonRpcResponse.ResponseError.rpcError(rpcError) = error, rpcError.code == -32005 {
            var backoffSeconds = 1.0

            if let errorData = rpcError.data as? [String: Any], let timeInterval = errorData["backoff_seconds"] as? TimeInterval {
                backoffSeconds = timeInterval
            }

            completion(.retryWithDelay(backoffSeconds))
        } else {
            completion(.doNotRetry)
        }
    }
}

extension TronGridProvider {
    var source: String {
        baseUrl
    }
}

// MARK: - IRpcApiProvider

extension TronGridProvider: IRpcApiProvider {
    func fetch<T>(rpc: JsonRpc<T>) async throws -> T {
        currentRpcId += 1

        let json = try await rpcApiFetch(parameters: rpc.parameters(id: currentRpcId))

        guard let rpcResponse = JsonRpcResponse.response(jsonObject: json) else {
            throw RequestError.invalidResponse
        }

        return try rpc.parse(response: rpcResponse)
    }
}

// MARK: - INodeApiProvider

extension TronGridProvider: INodeApiProvider {
    func fetchAccount(address: String) async throws -> NodeAccountResponse? {
        let map = try await nodeApiFetch(path: "wallet/getaccount", parameters: ["address": address, "visible": true])

        // Empty object {} or missing balance means account does not exist / is inactive
        guard let balance = map["balance"] as? Int else {
            return nil
        }

        return NodeAccountResponse(balance: BigUInt(balance))
    }

    func fetchChainParameters() async throws -> [ChainParameterResponse] {
        let headers = await currentHeaders()
        let json = try await networkManager.fetchJson(url: "\(baseUrl)wallet/getchainparameters", method: .get, parameters: [:], headers: headers, responseCacherBehavior: .doNotCache)

        guard let map = json as? [String: Any],
              let chainParameter = map["chainParameter"] as? [[String: Any]]
        else {
            throw RequestError.invalidResponse
        }

        return try chainParameter.map { try ChainParameterResponse(JSON: $0) }
    }

    func createTransaction(ownerAddress: String, toAddress: String, amount: Int) async throws -> CreatedTransactionResponse {
        let headers = await currentHeaders()
        let json = try await networkManager.fetchJson(
            url: "\(baseUrl)wallet/createtransaction",
            method: .post,
            parameters: ["owner_address": ownerAddress, "to_address": toAddress, "amount": amount],
            encoding: JSONEncoding.default,
            headers: headers,
            responseCacherBehavior: .doNotCache
        )

        guard let map = json as? [String: Any] else {
            throw RequestError.invalidResponse
        }

        return try CreatedTransactionResponse(JSON: map)
    }

    func triggerSmartContract(
        ownerAddress: String, contractAddress: String, functionSelector: String, parameter: String,
        callValue: Int? = nil, callTokenValue: Int? = nil, tokenId: Int? = nil,
        feeLimit: Int
    ) async throws -> CreatedTransactionResponse {
        var parameters: Parameters = [
            "owner_address": ownerAddress,
            "contract_address": contractAddress,
            "function_selector": functionSelector,
            "parameter": parameter,
            "fee_limit": feeLimit,
        ]

        callValue.flatMap { parameters["call_value"] = $0 }
        callTokenValue.flatMap { parameters["call_token_value"] = $0 }
        tokenId.flatMap { parameters["token_id"] = $0 }

        let json = try await nodeApiFetchChecked(path: "wallet/triggersmartcontract", parameters: parameters)

        guard let transactionMap = json["transaction"] as? [String: Any] else {
            throw RequestError.invalidResponse
        }

        return try CreatedTransactionResponse(JSON: transactionMap)
    }

    func broadcastTransaction(hexData: Data) async throws {
        let headers = await currentHeaders()
        _ = try await networkManager.fetchJson(
            url: "\(baseUrl)wallet/broadcasthex",
            method: .post,
            parameters: ["transaction": hexData.hs.hex],
            encoding: JSONEncoding.default,
            headers: headers,
            responseCacherBehavior: .doNotCache
        )
    }

    func broadcastTransaction(createdTransaction: CreatedTransactionResponse, signature: Data) async throws {
        let headers = await currentHeaders()
        _ = try await networkManager.fetchJson(
            url: "\(baseUrl)wallet/broadcasttransaction",
            method: .post,
            parameters: [
                "visible": createdTransaction.visible ?? false,
                "txID": createdTransaction.txID.hs.hex,
                "raw_data": createdTransaction.rawDataMap,
                "raw_data_hex": createdTransaction.rawDataHex.hs.hex,
                "signature": [signature.hs.hexString],
            ],
            encoding: JSONEncoding.default,
            headers: headers,
            responseCacherBehavior: .doNotCache
        )
    }

    func estimateEnergy(ownerAddress: String, contractAddress: String, functionSelector: String, parameter: String) async throws -> Int {
        let result = try await nodeApiFetchChecked(
            path: "wallet/estimateenergy",
            parameters: [
                "owner_address": ownerAddress,
                "contract_address": contractAddress,
                "function_selector": functionSelector,
                "parameter": parameter,
            ]
        )

        guard let energyRequired = result["energy_required"] as? Int else {
            throw RequestError.invalidResponse
        }

        return energyRequired
    }
}

// MARK: - IHistoryProvider

extension TronGridProvider: IHistoryProvider {
    func fetchAccountInfo(address: String) async throws -> AccountInfoResponse {
        let result = try await extensionApiFetch(path: "v1/accounts/\(address)", parameters: [:])

        guard !result.data.isEmpty else {
            throw RequestError.failedToFetchAccountInfo
        }

        return try AccountInfoResponse(JSON: result.data[0])
    }

    func fetchTransactions(address: String, minTimestamp: Int, cursor: String?) async throws -> ([ITransactionResponse], nextCursor: String?) {
        let path = "v1/accounts/\(address)/transactions"
        var parameters: Parameters = [
            "only_confirmed": true,
            "order_by": "block_timestamp,asc",
            "limit": pageLimit,
            "min_timestamp": minTimestamp,
        ]

        cursor.flatMap { parameters["fingerprint"] = $0 }

        let result = try await extensionApiFetch(path: path, parameters: parameters)
        let transactions = result.data.compactMap { json -> ITransactionResponse? in
            if json["internal_tx_id"] is String {
                return try? InternalTransactionResponse(JSON: json)
            } else {
                return try? TransactionResponse(JSON: json)
            }
        }

        let nextCursor: String? = transactions.count < pageLimit ? nil : (result.meta["fingerprint"] as? String)
        return (transactions, nextCursor)
    }

    func fetchTrc20Transactions(address: String, minTimestamp: Int, cursor: String?) async throws -> ([Trc20TransactionResponse], nextCursor: String?) {
        let path = "v1/accounts/\(address)/transactions/trc20"
        var parameters: Parameters = [
            "only_confirmed": true,
            "order_by": "block_timestamp,asc",
            "limit": pageLimit,
            "min_timestamp": minTimestamp,
        ]

        cursor.flatMap { parameters["fingerprint"] = $0 }

        let result = try await extensionApiFetch(path: path, parameters: parameters)
        let transactions = result.data.compactMap { try? Trc20TransactionResponse(JSON: $0) }
        let nextCursor: String? = transactions.count < pageLimit ? nil : (result.meta["fingerprint"] as? String)
        return (transactions, nextCursor)
    }
}

extension TronGridProvider {
    public enum RequestError: Error {
        case invalidResponse
        case invalidStatus
        case failedToFetchAccountInfo
        case fullNodeApiError(code: String, message: String)
    }

    actor SyncedState {
        private let apiKeys: [String]
        private var index = 0

        init(apiKeys: [String]) {
            self.apiKeys = apiKeys
        }

        func getApiKey() -> String? {
            guard !apiKeys.isEmpty else { return nil }
            index = (index + 1) % apiKeys.count
            return apiKeys[index]
        }
    }
}
