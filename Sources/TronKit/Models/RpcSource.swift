import Foundation

public struct RpcSource {
    let urls: [URL]
    let apiKeys: [String]
    let auth: String?

    public init(urls: [URL], apiKeys: [String] = [], auth: String? = nil) {
        self.urls = urls
        self.apiKeys = apiKeys
        self.auth = auth
    }

    public static func tronGrid(network: Network, apiKeys: [String]) -> RpcSource {
        RpcSource(urls: [URL(string: network.tronGridUrl)!], apiKeys: apiKeys)
    }
}
