import Foundation

class TransactionSender {
    private let nodeApiProvider: INodeApiProvider

    init(nodeApiProvider: INodeApiProvider) {
        self.nodeApiProvider = nodeApiProvider
    }
}

extension TransactionSender {
    func sendTransaction(contract: Contract, signer: Signer, feeLimit: Int?) async throws -> CreatedTransactionResponse {
        var createdTransaction: CreatedTransactionResponse

        guard let contract = contract as? SupportedContract else {
            throw Kit.SendError.notSupportedContract
        }

        switch contract {
        case let transfer as TransferContract:
            createdTransaction = try await nodeApiProvider.createTransaction(
                ownerAddress: transfer.ownerAddress.hex,
                toAddress: transfer.toAddress.hex,
                amount: transfer.amount
            )

        case let smartContract as TriggerSmartContract:
            guard let functionSelector = smartContract.functionSelector,
                  let parameter = smartContract.parameter,
                  let feeLimit
            else {
                throw Kit.SendError.invalidParameter
            }

            createdTransaction = try await nodeApiProvider.triggerSmartContract(
                ownerAddress: smartContract.ownerAddress.hex,
                contractAddress: smartContract.contractAddress.hex,
                functionSelector: functionSelector,
                parameter: parameter,
                callValue: smartContract.callValue,
                callTokenValue: smartContract.callTokenValue,
                tokenId: smartContract.tokenId,
                feeLimit: feeLimit
            )

        default: throw Kit.SendError.notSupportedContract
        }

        let rawData = try Protocol_Transaction.raw(serializedBytes: createdTransaction.rawDataHex)

        guard rawData.contract.count == 1,
              let contractMessage = rawData.contract.first,
              try contractMessage.parameter.value == (contract.protoMessage.serializedData())
        else {
            throw Kit.SendError.abnormalSend
        }

        let signature = try signer.signature(hash: createdTransaction.txID)

        var transaction = Protocol_Transaction()
        transaction.rawData = rawData
        transaction.signature = [signature]

        try await nodeApiProvider.broadcastTransaction(hexData: transaction.serializedData())

        return createdTransaction
    }

    func broadcastTransaction(createdTransaction: CreatedTransactionResponse, signer: Signer) async throws {
        let signature = try signer.signature(hash: createdTransaction.txID)
        return try await nodeApiProvider.broadcastTransaction(createdTransaction: createdTransaction, signature: signature)
    }
}
