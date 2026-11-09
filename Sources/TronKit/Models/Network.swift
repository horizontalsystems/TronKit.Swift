import Foundation

public enum Network: String {
    case mainNet, shastaTestnet, nileTestnet

    public var tronGridUrl: String {
        switch self {
        case .mainNet: return "https://api.trongrid.io/"
        case .nileTestnet: return "https://nile.trongrid.io/"
        case .shastaTestnet: return "https://api.shasta.trongrid.io/"
        }
    }

    public var tronScanApiUrl: String {
        switch self {
        case .mainNet: return "https://apilist.tronscanapi.com/api/"
        case .nileTestnet: return "https://nileapi.tronscan.org/api/"
        case .shastaTestnet: return "https://shastapi.tronscan.org/api/"
        }
    }
}
