import Foundation

class TransactionSender {
    private let tronGridProvider: TronGridProvider

    init(tronGridProvider: TronGridProvider) {
        self.tronGridProvider = tronGridProvider
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
                createdTransaction = try await tronGridProvider.createTransaction(ownerAddress: transfer.ownerAddress.hex, toAddress: transfer.toAddress.hex, amount: transfer.amount)

            case let smartContract as TriggerSmartContract:
                guard let functionSelector = smartContract.functionSelector,
                      let parameter = smartContract.parameter,
                      let feeLimit = feeLimit else {
                    throw Kit.SendError.invalidParameter
                }

                createdTransaction = try await tronGridProvider.triggerSmartContract(
                    ownerAddress: smartContract.ownerAddress.hex,
                    contractAddress: smartContract.contractAddress.hex,
                    functionSelector: functionSelector,
                    parameter: parameter,
                    feeLimit: feeLimit
                )

            default: throw Kit.SendError.notSupportedContract
        }

        let rawData = try Protocol_Transaction.raw(serializedData: createdTransaction.rawDataHex)

        guard rawData.contract.count == 1,
                let contractMessage = rawData.contract.first,
                contractMessage.parameter.value == (try contract.protoMessage.serializedData()) else {
            throw Kit.SendError.abnormalSend
        }

        let signature = try signer.signature(hash: createdTransaction.txID)

        var transaction = Protocol_Transaction()
        transaction.rawData = rawData
        transaction.signature = [signature]

        try await tronGridProvider.broadcastTransaction(hexData: transaction.serializedData())

        return createdTransaction
    }

}
