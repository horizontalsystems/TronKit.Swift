import BigInt
import Combine
import Foundation
import TronKit

class TrxAdapter {
    private let tronKit: Kit
    private let signer: Signer?
    private let decimal = 6

    init(TronKit: Kit, signer: Signer?) {
        tronKit = TronKit
        self.signer = signer
    }

    private func transactionRecord(fullTransaction: FullTransaction) -> TransactionRecord {
        let transaction = fullTransaction.transaction

        return TransactionRecord(
            transactionHash: transaction.hash.hs.hex,
            transactionHashData: transaction.hash,
            timestamp: transaction.timestamp,
            isFailed: transaction.isFailed,
            blockHeight: transaction.blockNumber,
            decoration: fullTransaction.decoration
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
        tronKit.syncState
    }

    var balance: Decimal {
        if let significand = Decimal(string: tronKit.trxBalance.description) {
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
        tronKit.syncStatePublisher.map { _ in () }.eraseToAnyPublisher()
    }

    var balancePublisher: AnyPublisher<Void, Never> {
        tronKit.trxBalancePublisher.map { _ in () }.eraseToAnyPublisher()
    }

    var transactionsPublisher: AnyPublisher<Void, Never> {
        tronKit.allTransactionsPublisher.map { _ in () }.eraseToAnyPublisher()
    }

    func transactions(from hash: Data?, limit: Int?) -> [TransactionRecord] {
        tronKit.transactions(tagQueries: [], fromHash: hash, limit: limit).compactMap { transactionRecord(fullTransaction: $0) }
    }

    func transaction(hash _: Data, interTransactionIndex _: Int) -> TransactionRecord? {
        nil
    }

    func transferContract(toAddress: Address, value: Int) -> TransferContract {
        tronKit.transferContract(toAddress: toAddress, value: value)
    }

    func transferTrc20TriggerSmartContract(contractAddress: Address, toAddress: Address, value: BigUInt) -> TriggerSmartContract {
        tronKit.transferTrc20TriggerSmartContract(contractAddress: contractAddress, toAddress: toAddress, amount: value)
    }

    func estimateFee(contract: Contract) async throws -> [Fee] {
        try await tronKit.estimateFee(contract: contract)
    }

    func transaction(hash: Data) async throws -> FullTransaction {
        try await tronKit.fetchTransaction(hash: hash)
    }

    func send(contract: Contract, feeLimit: Int?) async throws {
        guard let signer else {
            throw SendError.noSigner
        }

        try await tronKit.send(contract: contract, signer: signer, feeLimit: feeLimit)
    }
}

extension TrxAdapter {
    enum SendError: Error {
        case noSigner
    }
}
