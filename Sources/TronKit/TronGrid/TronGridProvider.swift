import Foundation
import BigInt
import Alamofire
import HsToolKit

class TronGridProvider {
    private let networkManager: NetworkManager
    private let baseUrl: String

    private let headers: HTTPHeaders
    private var currentRpcId = 0
    private let pageLimit = 200

    init(networkManager: NetworkManager, baseUrl: String, apiKey: String?) {
        self.networkManager = networkManager
        self.baseUrl = baseUrl

        var headers = HTTPHeaders()

        if let apiKey = apiKey {
            headers.add(.init(name: "TRON-PRO-API-KEY", value: apiKey))
        }

        self.headers = headers
    }

    private func rpcApiFetch(parameters: [String: Any]) async throws -> Any {
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
        let urlString = "\(baseUrl)\(path)"

        let json = try await networkManager.fetchJson(url: urlString, method: .get, parameters: parameters, headers: headers, responseCacherBehavior: .doNotCache)

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

    private func requestNodeApiFetch(path: String, parameters: Parameters) async throws -> [String: Any] {
        let urlString = "\(baseUrl)\(path)"

        let json = try await networkManager.fetchJson(url: urlString, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers, responseCacherBehavior: .doNotCache)

        guard let map = json as? [String: Any] else {
            throw RequestError.invalidResponse
        }

        guard let resultMap = map["result"] as? [String: Any],
              let successResult = resultMap["result"] as? Bool else {
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

    func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> ()) {
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

    func fetch<T>(rpc: JsonRpc<T>) async throws -> T {
        currentRpcId += 1

        let json = try await rpcApiFetch(parameters: rpc.parameters(id: currentRpcId))

        guard let rpcResponse = JsonRpcResponse.response(jsonObject: json) else {
            throw RequestError.invalidResponse
        }

        return try rpc.parse(response: rpcResponse)
    }

    func fetchAccountInfo(address: String) async throws -> AccountInfoResponse {
        let result = try await extensionApiFetch(path: "v1/accounts/\(address)", parameters: [:])

        guard !result.data.isEmpty else {
            throw RequestError.failedToFetchAccountInfo
        }

        return try AccountInfoResponse(JSON: result.data[0])
    }

    func fetchTransactions(address: String, minTimestamp: Int, fingerprint: String?) async throws -> (transactions: [ITransactionResponse], fingerprint: String?, completed: Bool) {
        let path = "v1/accounts/\(address)/\(ApiPath.transactions.rawValue)"
        var parameters: Parameters = [
            "only_confirmed": true,
            "order_by": "block_timestamp,asc",
            "limit": pageLimit,
            "min_timestamp": minTimestamp
        ]

        fingerprint.flatMap { parameters["fingerprint"] = $0 }

        let result = try await extensionApiFetch(path: path, parameters: parameters)
        let transactions = result.data.compactMap { json -> ITransactionResponse? in
            if json["internal_tx_id"] is String {
                return try? InternalTransactionResponse(JSON: json)
            } else {
                return try? TransactionResponse(JSON: json)
            }
        }

        let newFingerprint = result.meta["fingerprint"] as? String
        let completed = transactions.count < pageLimit

        return (transactions: transactions, fingerprint: newFingerprint, completed: completed)
    }

    func fetchTrc20Transactions(address: String, minTimestamp: Int, fingerprint: String?) async throws -> (transactions: [Trc20TransactionResponse], fingerprint: String?, completed: Bool) {
        let path = "v1/accounts/\(address)/\(ApiPath.transactionsTrc20.rawValue)"
        var parameters: Parameters = [
            "only_confirmed": true,
            "order_by": "block_timestamp,asc",
            "limit": pageLimit,
            "min_timestamp": minTimestamp
        ]

        fingerprint.flatMap { parameters["fingerprint"] = $0 }

        let result = try await extensionApiFetch(path: path, parameters: parameters)
        let transactions = result.data.compactMap { try? Trc20TransactionResponse(JSON: $0) }
        let fingerprint = result.meta["fingerprint"] as? String
        let completed = transactions.count < pageLimit

        return (transactions: transactions, fingerprint: fingerprint, completed: completed)
    }

    func estimateEnergy(ownerAddress: String, contractAddress: String, functionSelector: String, parameter: String) async throws -> Int {
        let path = "wallet/estimateenergy"
        let parameters: Parameters = [
            "owner_address": ownerAddress,
            "contract_address": contractAddress,
            "function_selector": functionSelector,
            "parameter": parameter
        ]

        let result = try await requestNodeApiFetch(path: path, parameters: parameters)

        guard let energyRequired = result["energy_required"] as? Int else {
            throw RequestError.invalidResponse
        }

        return energyRequired
    }

    func fetchChainParameters() async throws -> [ChainParameterResponse] {
        let urlString = "\(baseUrl)wallet/getchainparameters"
        let json = try await networkManager.fetchJson(url: urlString, method: .get, parameters: [:], responseCacherBehavior: .doNotCache)

        guard let map = json as? [String: Any] else {
            throw RequestError.invalidResponse
        }

        guard let chainParameter = map["chainParameter"] as? [[String: Any]] else {
            throw RequestError.invalidResponse
        }

        return try chainParameter.map { try ChainParameterResponse(JSON: $0) }
    }

    func createTransaction(ownerAddress: String, toAddress: String, amount: Int) async throws -> CreatedTransactionResponse {
        let urlString = "\(baseUrl)wallet/createtransaction"
        let parameters: Parameters = [
            "owner_address": ownerAddress,
            "to_address": toAddress,
            "amount": amount
        ]
        let json = try await networkManager.fetchJson(url: urlString, method: .post, parameters: parameters, encoding: JSONEncoding.default, responseCacherBehavior: .doNotCache)

        guard let map = json as? [String: Any] else {
            throw RequestError.invalidResponse
        }

        return try CreatedTransactionResponse(JSON: map)
    }

    func triggerSmartContract(
        ownerAddress: String, contractAddress: String, functionSelector: String, parameter: String,
        callValue: Int? = nil, callTokenValue: Int? = nil, tokenId: Int? = nil,
        feeLimit: Int) async throws -> CreatedTransactionResponse {
        let path = "wallet/triggersmartcontract"
        var parameters: Parameters = [
            "owner_address": ownerAddress,
            "contract_address": contractAddress,
            "function_selector": functionSelector,
            "parameter": parameter,
            "fee_limit": feeLimit
        ]

        callValue.flatMap { parameters["call_value"] = $0 }
        callTokenValue.flatMap { parameters["call_token_value"] = $0 }
        tokenId.flatMap { parameters["token_id"] = $0 }

        let json = try await requestNodeApiFetch(path: path, parameters: parameters)

        guard let transactionMap = json["transaction"] as? [String: Any] else {
            throw RequestError.invalidResponse
        }

        return try CreatedTransactionResponse(JSON: transactionMap)
    }

    func broadcastTransaction(hexData: Data) async throws {
        let urlString = "\(baseUrl)wallet/broadcasthex"
        let parameters: Parameters = [
            "transaction": hexData.hs.hex,
        ]

        _ = try await networkManager.fetchJson(url: urlString, method: .post, parameters: parameters, encoding: JSONEncoding.default, responseCacherBehavior: .doNotCache)
    }

}

extension TronGridProvider {

    public enum RequestError: Error {
        case invalidResponse
        case invalidStatus
        case failedToFetchAccountInfo
        case fullNodeApiError(code: String, message: String)
    }

}

extension TronGridProvider {

    enum ApiPath: String {
        case transactions = "transactions"
        case transactionsTrc20 = "transactions/trc20"
    }

}
