import Foundation
import Combine
import TronKit
import BigInt

class TrxAdapter {
    private let tronKit: Kit
    private let signer: Signer?
    private let decimal = 18

    init(TronKit: Kit, signer: Signer?) {
        self.tronKit = TronKit
        self.signer = signer
    }

    private func transactionRecord(fullTransaction: FullTransaction) -> TransactionRecord {
//        let transaction = fullTransaction.transaction
//
//        var amount: Decimal?
//
//        if let value = transaction.value, let significand = Decimal(string: value.description) {
//            amount = Decimal(sign: .plus, exponent: -decimal, significand: significand)
//        }

        return TransactionRecord(
                transactionHash: "transaction.hash.hs.hexString",
                transactionHashData: Data(),
                timestamp: 0,
                isFailed: false,
                from: nil,
                to: nil,
                amount: nil,
                input: nil,
                blockHeight: nil,
                transactionIndex: nil,
                decoration: ""
        )
    }

}

extension TrxAdapter {

    func start() {
        tronKit.start()
    }

    func stop() {
        tronKit.stop()
    }

    func refresh() {
        tronKit.refresh()
    }

    var name: String {
        "TRON"
    }

    var coin: String {
        "TRX"
    }

    var lastBlockHeight: Int? {
        tronKit.lastBlockHeight
    }

    var syncState: SyncState {
        tronKit.syncState
    }

    var transactionsSyncState: SyncState {
        tronKit.transactionsSyncState
    }

    var balance: Decimal {
        if let significand = Decimal(string: tronKit.balance.description) {
            return Decimal(sign: .plus, exponent: -decimal, significand: significand)
        }

        return 0
    }

    var receiveAddress: Address {
        tronKit.receiveAddress
    }

    var lastBlockHeightPublisher: AnyPublisher<Void, Never> {
        tronKit.lastBlockHeightPublisher.map { _ in () }.eraseToAnyPublisher()
    }

    var syncStatePublisher: AnyPublisher<Void, Never> {
        tronKit.syncStatePublisher.map { _ in () }.eraseToAnyPublisher()
    }

    var transactionsSyncStatePublisher: AnyPublisher<Void, Never> {
        tronKit.transactionsSyncStatePublisher.map { _ in () }.eraseToAnyPublisher()
    }

    var balancePublisher: AnyPublisher<Void, Never> {
        tronKit.accountStatePublisher.map { _ in () }.eraseToAnyPublisher()
    }

    var transactionsPublisher: AnyPublisher<Void, Never> {
        tronKit.allTransactionsPublisher.map { _ in () }.eraseToAnyPublisher()
    }

    func transactions(from hash: Data?, limit: Int?) -> [TransactionRecord] {
        []
    }

    func transaction(hash: Data, interTransactionIndex: Int) -> TransactionRecord? {
        nil
    }

    func estimatedGasLimit(to address: Address, value: Decimal, gasPrice: Int) async throws -> Int {
        0
    }

    func transaction(hash: Data) async throws -> FullTransaction {
        try await tronKit.fetchTransaction(hash: hash)
    }

    func send(to: Address, amount: Decimal, gasLimit: Int, gasPrice: Int) async throws {
        guard let signer = signer else {
            throw SendError.noSigner
        }
    }

}

extension TrxAdapter {

    enum SendError: Error {
        case noSigner
    }

}
