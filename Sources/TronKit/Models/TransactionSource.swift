import Foundation

public struct TransactionSource {
    public let name: String
    public let type: SourceType

    public enum SourceType {
        case tronGrid(url: URL, apiKeys: [String])
        case tronScan(url: URL, apiKey: String?)
    }

    public static func tronGrid(network: Network, apiKeys: [String]) -> TransactionSource {
        TransactionSource(
            name: "TronGrid",
            type: .tronGrid(url: URL(string: network.tronGridUrl)!, apiKeys: apiKeys)
        )
    }

    public static func tronScan(apiKey: String?) -> TransactionSource {
        TransactionSource(
            name: "TronScan",
            type: .tronScan(url: URL(string: "https://apilist.tronscanapi.com/api/")!, apiKey: apiKey)
        )
    }
}
