import BigInt
import Foundation

protocol INodeApiProvider {
    func fetchAccount(address: String) async throws -> NodeAccountResponse?
    func fetchChainParameters() async throws -> [ChainParameterResponse]
    func createTransaction(ownerAddress: String, toAddress: String, amount: Int) async throws -> CreatedTransactionResponse
    func triggerSmartContract(
        ownerAddress: String, contractAddress: String, functionSelector: String, parameter: String,
        callValue: Int?, callTokenValue: Int?, tokenId: Int?,
        feeLimit: Int
    ) async throws -> CreatedTransactionResponse
    func broadcastTransaction(hexData: Data) async throws
    func broadcastTransaction(createdTransaction: CreatedTransactionResponse, signature: Data) async throws
    func estimateEnergy(ownerAddress: String, contractAddress: String, functionSelector: String, parameter: String) async throws -> Int
}

struct NodeAccountResponse {
    let balance: BigUInt
}
