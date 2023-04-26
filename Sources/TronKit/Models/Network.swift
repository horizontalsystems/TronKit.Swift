import Foundation

public struct Network {
    public let id: Int
    public let coinType: UInt32
    public let addressPrefix: UInt8

    public init(id: Int, coinType: UInt32, addressPrefix: UInt8) {
        self.id = id
        self.coinType = coinType
        self.addressPrefix = addressPrefix
    }

    public var isMainNet: Bool {
        coinType != 1
    }

}

extension Network: Equatable {

    public static func ==(lhs: Network, rhs: Network) -> Bool {
        lhs.id == rhs.id
    }

}

extension Network {

    public static var mainNet: Network {
        Network(
            id: 1,
            coinType: 195,
            addressPrefix: 0x41
        )
    }

    public static var shastaTestnet: Network {
        Network(
            id: 2,
            coinType: 1,
            addressPrefix: 0xa0
        )
    }

    public static var nileTestnet: Network {
        Network(
            id: 3,
            coinType: 1,
            addressPrefix: 0xa0
        )
    }

}
