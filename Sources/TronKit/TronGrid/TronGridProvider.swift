import Foundation
import BigInt
import Alamofire
import HsToolKit

class TronGridProvider {
    private let networkManager: NetworkManager
    private let baseUrl: String

    private let headers: HTTPHeaders
    private var currentRpcId = 0

    init(networkManager: NetworkManager, baseUrl: String, auth: String?) {
        self.networkManager = networkManager
        self.baseUrl = baseUrl

        var headers = HTTPHeaders()

        if let auth = auth {
            headers.add(.authorization(username: "", password: auth))
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

    private func extensionApiFetch(path: String) async throws -> [[String: Any]] {
        let urlString = "\(baseUrl)/\(path)"

        let json = try await networkManager.fetchJson(url: urlString, method: .get, parameters: [:], responseCacherBehavior: .doNotCache)

        guard let map = json as? [String: Any] else {
            throw RequestError.invalidResponse
        }

        guard let status = map["success"] as? Bool, status else {
            throw RequestError.invalidStatus
        }

        guard let data = map["data"] as? [[String: Any]] else {
            throw RequestError.invalidResponse
        }

        return data
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
        let jsonObjects = try await extensionApiFetch(path: "v1/accounts/\(address)")

        guard !jsonObjects.isEmpty else {
            throw RequestError.failedToFetchAccountInfo
        }

        return try AccountInfoResponse(JSON: jsonObjects[0])
    }

    func fetchTransactions(address: String, lastTimestamp: Int) async throws -> [TransactionResponse] {
        let path = "v1/accounts/\(address)/\(ApiPath.transactions.rawValue)?min_timestamp=\(lastTimestamp)"
        let jsonObjects = try await extensionApiFetch(path: path)
        return try jsonObjects.compactMap { try TransactionResponse(JSON: $0) }
    }

    func fetchTrc20Transactions(address: String, lastTimestamp: Int) async throws -> [Trc20TransactionResponse] {
        let path = "v1/accounts/\(address)/\(ApiPath.transactionsTrc20.rawValue)?min_timestamp=\(lastTimestamp)"
        let jsonObjects = try await extensionApiFetch(path: path)
        return try jsonObjects.compactMap { try Trc20TransactionResponse(JSON: $0) }
    }

}

extension TronGridProvider {

    public enum RequestError: Error {
        case invalidResponse
        case invalidStatus
        case failedToFetchAccountInfo
    }

}

extension TronGridProvider {

    enum ApiPath: String {
        case transactions = "transactions"
        case transactionsTrc20 = "transactions/trc20"
    }

}
