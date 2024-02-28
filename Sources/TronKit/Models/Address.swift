import Foundation
import GRDB
import HsCryptoKit
import HsExtensions

public struct Address {
    public let raw: Data
    public let base58: String

    public init(raw: Data) throws {
        var prefixedRaw = raw

        if prefixedRaw.count == 20 {
            prefixedRaw = [0x41] + prefixedRaw
        }

        try Address.validate(data: prefixedRaw)
        self.raw = prefixedRaw

        let checksum = Crypto.doubleSha256(prefixedRaw).prefix(4)
        base58 = Data(prefixedRaw + checksum).hs.encodeBase58
    }

    public init(address: String) throws {
        let decoded = Base58.decode(address)
        guard decoded.count > 4 else {
            throw ValidationError.invalidAddressLength
        }

        let checksum = decoded.suffix(4)
        let hex = Data(decoded[0 ..< (decoded.count - 4)])

        let realChecksum = Crypto.doubleSha256(hex).prefix(4)

        guard realChecksum == checksum else {
            throw ValidationError.invalidChecksum
        }

        try self.init(raw: hex)
    }

    public var hex: String {
        raw.hs.hex
    }

    public var nonPrefixed: Data {
        raw.suffix(from: 1)
    }
}

extension Address {
    private static func validate(data: Data) throws {
        guard data[0] == 0x41 else {
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

    public static func == (lhs: Address, rhs: Address) -> Bool {
        lhs.raw == rhs.raw
    }
}

extension Address: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue {
        raw.databaseValue
    }

    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Address? {
        switch dbValue.storage {
        case let .blob(data):
            return try! Address(raw: data)
        default:
            return nil
        }
    }
}

public extension Address {
    enum ValidationError: Error {
        case invalidHex
        case invalidChecksum
        case invalidAddressLength
        case invalidSymbols
        case wrongAddressPrefix
    }
}
