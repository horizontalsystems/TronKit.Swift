import Foundation
import HsCryptoKit
import GRDB
import HsExtensions

public struct Address {
    public let raw: Data

    public init(raw: Data) {
        self.raw = raw
    }

    public init(address: String, network: Network) throws {
        let decoded = Base58.decode(address)
        guard decoded.count > 4 else {
            throw ValidationError.invalidAddressLength
        }

        let checksum = decoded.suffix(4)
        let hex = Data(decoded[0..<(decoded.count - 4)])

        let realChecksum = Crypto.doubleSha256(hex).prefix(4)

        guard realChecksum == checksum else {
            throw ValidationError.invalidChecksum
        }

        try Address.validate(data: hex, network: network)

        raw = hex
    }

    public var hex: String {
        raw.hs.hexString
    }

    public var base58: String {
        let checksum = Crypto.doubleSha256(raw).prefix(4)
        return Data(raw + checksum).hs.encodeBase58
    }

}

extension Address {

    private static func validate(data: Data, network: Network) throws {
        guard data[0] == network.addressPrefix else {
            throw ValidationError.wrongAddressPrefix
        }
        guard data.count == 21 else {
            throw ValidationError.invalidAddressLength
        }
    }

}

extension Address: CustomStringConvertible {

    public var description: String {
        hex
    }

}

extension Address: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(raw)
    }

    public static func ==(lhs: Address, rhs: Address) -> Bool {
        lhs.raw == rhs.raw
    }

}

extension Address: DatabaseValueConvertible {

    public var databaseValue: DatabaseValue {
        raw.databaseValue
    }

    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Address? {
        switch dbValue.storage {
            case .blob(let data):
                return Address(raw: data)
            default:
                return nil
        }
    }

}

extension Address {

    public enum ValidationError: Error {
        case invalidHex
        case invalidChecksum
        case invalidAddressLength
        case invalidSymbols
        case wrongAddressPrefix
    }

}
