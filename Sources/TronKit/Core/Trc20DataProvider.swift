import Foundation
import BigInt
import HsExtensions
import HsToolKit

public struct Trc20DataProvider {

    public static func fetchName(networkManager: NetworkManager, network: Network, apiKey: String?, contractAddress: Address) async throws -> String {
        let data = try await TronKit.Kit.call(networkManager: networkManager, network: network, contractAddress: contractAddress, data: NameMethod().encodedABI(), apiKey: apiKey)

        guard !data.isEmpty else {
            throw TokenError.invalidHex
        }

        let parsedArguments = try ContractMethodHelper.decodeABI(inputArguments: data, argumentTypes: [Data.self])

        guard let stringData = parsedArguments[0] as? Data else {
            throw ContractMethodFactories.DecodeError.invalidABI
        }

        guard let string = String(data: stringData, encoding: .utf8) else {
            throw TokenError.invalidHex
        }

        return string
    }

    public static func fetchSymbol(networkManager: NetworkManager, network: Network, apiKey: String?, contractAddress: Address) async throws -> String {
        let data = try await TronKit.Kit.call(networkManager: networkManager, network: network, contractAddress: contractAddress, data: SymbolMethod().encodedABI(), apiKey: apiKey)

        guard !data.isEmpty else {
            throw TokenError.invalidHex
        }

        let parsedArguments = try ContractMethodHelper.decodeABI(inputArguments: data, argumentTypes: [Data.self])

        guard let stringData = parsedArguments[0] as? Data else {
            throw ContractMethodFactories.DecodeError.invalidABI
        }

        guard let string = String(data: stringData, encoding: .utf8) else {
            throw TokenError.invalidHex
        }

        return string
    }

    public static func fetchDecimals(networkManager: NetworkManager, network: Network, apiKey: String?, contractAddress: Address) async throws -> Int {
        let data = try await TronKit.Kit.call(networkManager: networkManager, network: network, contractAddress: contractAddress, data: DecimalsMethod().encodedABI(), apiKey: apiKey)

        guard !data.isEmpty else {
            throw TokenError.invalidHex
        }

        guard let bigIntValue = BigUInt(data.prefix(32).hs.hex, radix: 16) else {
            throw TokenError.invalidHex
        }

        guard let value = Int(bigIntValue.description) else {
            throw TokenError.invalidHex
        }

        return value
    }

}

extension Trc20DataProvider {

    class NameMethod: ContractMethod {
        override var methodSignature: String { "name()" }
        override var arguments: [Any] { [] }
    }

    class SymbolMethod: ContractMethod {
        override var methodSignature: String { "symbol()" }
        override var arguments: [Any] { [] }
    }

    class DecimalsMethod: ContractMethod {
        override var methodSignature: String { "decimals()" }
        override var arguments: [Any] { [] }
    }

    public enum TokenError: Error {
        case invalidHex
        case notRegistered
        case alreadyRegistered
    }

}
