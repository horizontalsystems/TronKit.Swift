import Foundation
import Combine

class TransactionManager {
    private let userAddress: Address
    private let storage: TransactionStorage
    private let decorationManager: DecorationManager

    private let fullTransactionsSubject = PassthroughSubject<([FullTransaction], Bool), Never>()
    private let fullTransactionsWithTagsSubject = PassthroughSubject<[(transaction: FullTransaction, tags: [TransactionTag])], Never>()

    init(userAddress: Address, storage: TransactionStorage, decorationManager: DecorationManager) {
        self.userAddress = userAddress
        self.storage = storage
        self.decorationManager = decorationManager
    }
}

extension TransactionManager {

    var fullTransactionsPublisher: AnyPublisher<([FullTransaction], Bool), Never> {
        fullTransactionsSubject.eraseToAnyPublisher()
    }

    func fullTransactionsPublisher(tagQueries: [TransactionTagQuery]) -> AnyPublisher<[FullTransaction], Never> {
        fullTransactionsWithTagsSubject
            .map { transactionsWithTags in
                transactionsWithTags.compactMap { (transaction: FullTransaction, tags: [TransactionTag]) -> FullTransaction? in
                    for tagQuery in tagQueries {
                        for tag in tags {
                            if tag.conforms(tagQuery: tagQuery) {
                                return transaction
                            }
                        }
                    }

                    return nil
                }
            }
            .filter { transactions in
                transactions.count > 0
            }
            .eraseToAnyPublisher()
    }

    func fullTransactions(tagQueries: [TransactionTagQuery], fromHash: Data?, limit: Int?) -> [FullTransaction] {
        let transactions = storage.transactionsBefore(tagQueries: tagQueries, hash: fromHash, limit: limit)
        return decorationManager.decorate(transactions: transactions)
    }

    func save(transactionResponses: [ITransactionResponse]) {
        let internalTransactionRecords = transactionResponses.compactMap { response -> InternalTransaction? in
            guard let response = response as? InternalTransactionResponse else {
                return nil
            }

            return InternalTransaction(
                transactionHash: response.txId,
                timestamp: response.blockTimestamp,
                from: response.fromAddress,
                to: response.toAddress,
                value: response.data.value,
                internalTxId: response.internalTxId
            )
        }

        var transactionRecords = internalTransactionRecords.map { internalTx in
            Transaction(hash: internalTx.transactionHash, timestamp: internalTx.timestamp, isFailed: false)
        }
        storage.save(transactions: transactionRecords, replaceOnConflict: false)
        storage.save(internalTransactions: internalTransactionRecords)

        transactionRecords = transactionResponses.compactMap { response in
            guard let response = response as? TransactionResponse else {
                return nil
            }

            return Transaction(
                    hash: response.txId,
                    timestamp: response.blockTimestamp,
                    isFailed: response.ret.contains(where: { $0.contractRet != "SUCCESS" }),
                    contractsMap: response.rawData.contract
                )
        }
        storage.save(transactions: transactionRecords, replaceOnConflict: true)
    }


    func save(trc20TransferResponses: [Trc20TransactionResponse]) {
        let trc20TransferRecords = trc20TransferResponses.compactMap { response -> Trc20EventRecord? in
            return Trc20EventRecord(
                transactionHash: response.transactionId,
                type: response.type,
                blockTimestamp: response.blockTimestamp,
                contractAddress: response.tokenInfo.address,
                from: response.from,
                to: response.to,
                value: response.value,
                tokenName: response.tokenInfo.name,
                tokenSymbol: response.tokenInfo.symbol,
                tokenDecimal: response.tokenInfo.decimals
            )
        }

        let transactionRecords = trc20TransferRecords.map { transfer in
            Transaction(hash: transfer.transactionHash, timestamp: transfer.blockTimestamp, isFailed: false)
        }

        storage.save(transactions: transactionRecords, replaceOnConflict: false)
        storage.save(trc20Transfers: trc20TransferRecords)
    }

    func process(initial: Bool) {
        let transactions = storage.unprocessedTransactions()

        guard !transactions.isEmpty else {
            return
        }

        let fullTransactions = decorationManager.decorate(transactions: transactions)

        var fullTransactionsWithTags = [(transaction: FullTransaction, tags: [TransactionTag])]()
        var tagRecords = [TransactionTagRecord]()

        for fullTransaction in fullTransactions {
            let tags = fullTransaction.decoration.tags(userAddress: userAddress)
            tagRecords.append(contentsOf: tags.map {
                TransactionTagRecord(transactionHash: fullTransaction.transaction.hash, tag: $0)
            })
            fullTransactionsWithTags.append((transaction: fullTransaction, tags: tags))
        }

        storage.save(tags: tagRecords)

        fullTransactionsSubject.send((fullTransactions, initial))
        fullTransactionsWithTagsSubject.send(fullTransactionsWithTags)

        storage.markProcessed()
    }

}

public protocol ITransactionDecorator {
    func decoration(contract: TriggerSmartContract, internalTransactions: [InternalTransaction], events: [Event]) -> TransactionDecoration?
}
