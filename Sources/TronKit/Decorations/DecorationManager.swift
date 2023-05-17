import Foundation
import BigInt

class DecorationManager {
    private let userAddress: Address
    private let storage: TransactionStorage
    private var transactionDecorators = [ITransactionDecorator]()

    init(userAddress: Address, storage: TransactionStorage) {
        self.userAddress = userAddress
        self.storage = storage
    }

    private func internalTransactionsMap(transactions: [Transaction]) -> [Data: [InternalTransaction]] {
        let internalTransactions: [InternalTransaction]

        if transactions.count > 100 {
            internalTransactions = storage.internalTransactions()
        } else {
            let hashes = transactions.map { $0.hash }
            internalTransactions = storage.internalTransactions(hashes: hashes)
        }

        var map = [Data: [InternalTransaction]]()

        for internalTransaction in internalTransactions {
            map[internalTransaction.transactionHash] = (map[internalTransaction.transactionHash] ?? []) + [internalTransaction]
        }

        return map
    }

    private func eventsMap(transactions: [Transaction]) -> [Data: [Event]] {
        let trc20Records: [Trc20EventRecord]

        if transactions.count > 100 {
            trc20Records = storage.trc20Events()
        } else {
            let hashes = transactions.map { $0.hash }
            trc20Records = storage.trc20Events(hashes: hashes)
        }

        var map = [Data: [Event]]()

        for eventRecord in trc20Records {
            if let event = EventHelper.eventFromRecord(record: eventRecord) {
                map[event.transactionHash] = (map[event.transactionHash] ?? []) + [event]
            }
        }

        return map
    }

    private func decoration(contract: Contract?, internalTransactions: [InternalTransaction], events: [Event]) -> TransactionDecoration {
        guard let contract = contract else {
            return UnknownTransactionDecoration(
                contract: nil,
                internalTransactions: internalTransactions,
                events: events
            )
        }

        if let contract = contract as? TriggerSmartContract {
            for decorator in transactionDecorators {
                if let decoration = decorator.decoration(contract: contract, internalTransactions: internalTransactions, events: events) {
                    return decoration
                }
            }

            return UnknownTransactionDecoration(
                contract: contract,
                internalTransactions: internalTransactions,
                events: events
            )
        }

        return NativeTransactionDecoration(contract: contract)
    }

}

extension DecorationManager {

    func add(transactionDecorator: ITransactionDecorator) {
        transactionDecorators.append(transactionDecorator)
    }

    func decorateTransaction(contract: Contract) -> TransactionDecoration? {
        if let contract = contract as? TriggerSmartContract {
            for decorator in transactionDecorators {
                if let decoration = decorator.decoration(contract: contract, internalTransactions: [], events: []) {
                    return decoration
                }
            }
        }


        return NativeTransactionDecoration(contract: contract)
    }

    func decorate(transactions: [Transaction]) -> [FullTransaction] {
        let internalTransactionsMap = internalTransactionsMap(transactions: transactions)
        let eventsMap = eventsMap(transactions: transactions)

        return transactions.map { transaction in
            let decoration = decoration(
                    contract: transaction.contract,
                    internalTransactions: internalTransactionsMap[transaction.hash] ?? [],
                    events: eventsMap[transaction.hash] ?? []
            )

            return FullTransaction(transaction: transaction, decoration: decoration)
        }
    }
}
