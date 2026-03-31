import Foundation

public struct RpcSource {
    let urls: [URL]
    let apiKey: String?
    let auth: String?

    public init(urls: [URL], apiKey: String? = nil, auth: String? = nil) {
        self.urls = urls
        self.apiKey = apiKey
        self.auth = auth
    }

    public static func tronGrid(network: Network, apiKey: String?) -> RpcSource {
        RpcSource(urls: [URL(string: network.tronGridUrl)!], apiKey: apiKey)
    }
}
