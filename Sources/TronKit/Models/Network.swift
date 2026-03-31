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
}
