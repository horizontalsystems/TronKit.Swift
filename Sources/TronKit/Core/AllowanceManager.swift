import BigInt
import Foundation
import HsCryptoKit

enum AllowanceParsingError: Error {
    case notFound
    case illegalResponse
}

class AllowanceManager {
    private let rpcApiProvider: IRpcApiProvider
    private let address: Address

    init(rpcApiProvider: IRpcApiProvider, address: Address) {
        self.rpcApiProvider = rpcApiProvider
        self.address = address
    }

    func allowance(contractAddress: Address, spenderAddress: Address) async throws -> BigUInt {
        let methodData = AllowanceMethod(owner: address, spender: spenderAddress).encodedABI()

        let callJsonRpc = CallJsonRpc(contractAddress: contractAddress, data: methodData)
        let response: Data = try await rpcApiProvider.fetch(rpc: callJsonRpc)
        guard response.count >= 32 else {
            throw AllowanceParsingError.illegalResponse
        }

        return BigUInt(response[0 ... 31])
    }
}
