import Foundation
import GRDB
@testable import TronKit
import XCTest

final class TransactionMergeTests: XCTestCase {
    // MARK: - TransactionStorage.merge(existing:incoming:)

    func testMergeUpgradesConfirmedKeepsContractProcessedFalse() {
        let contract = Data([0x01, 0x02, 0x03])
        let pending = tx(hash: h(0xAA), timestamp: 100, confirmed: false, contract: contract)
        let incoming = tx(hash: h(0xAA), timestamp: 200, blockNumber: 555, confirmed: true, fee: 42, contract: nil)

        let merged = TransactionStorage.merge(existing: pending, incoming: incoming)

        XCTAssertTrue(merged.confirmed)
        XCTAssertEqual(merged.contractsRaw, contract) // injected decoration kept
        XCTAssertEqual(merged.timestamp, 200) // incoming block time wins
        XCTAssertEqual(merged.blockNumber, 555)
        XCTAssertEqual(merged.fee, 42)
        XCTAssertFalse(merged.processed) // must re-emit
    }

    func testMergeIsFailedChainTruthWins() {
        let ok = tx(hash: h(0xAA), timestamp: 1, confirmed: false, contract: nil)
        let failed = tx(hash: h(0xAA), timestamp: 2, isFailed: true, confirmed: true, contract: nil)
        XCTAssertTrue(TransactionStorage.merge(existing: ok, incoming: failed).isFailed)
        // a locally-guessed failure (deadline-fail) is overridden when the chain-synced row says it succeeded
        let confirmedOk = tx(hash: h(0xAA), timestamp: 2, confirmed: true, contract: nil)
        let locallyFailed = tx(hash: h(0xAA), timestamp: 1, isFailed: true, confirmed: false, contract: nil)
        XCTAssertFalse(TransactionStorage.merge(existing: locallyFailed, incoming: confirmedOk).isFailed)
    }

    // MARK: - save(transactions:replaceOnConflict: false) predicate

    func testFalseBranchMergesWhenIncomingConfirmsPending() throws {
        let storage = makeStorage()
        let hash = h(0xA1)
        let contract = Data([0x09])
        storage.save(transactions: [tx(hash: hash, timestamp: 100, confirmed: false, contract: contract)], replaceOnConflict: true)

        storage.save(transactions: [stub(hash: hash, timestamp: 200)], replaceOnConflict: false)

        let row = try XCTUnwrap(storage.unprocessedTransactions().first { $0.hash == hash })
        XCTAssertTrue(row.confirmed)
        XCTAssertEqual(row.contractsRaw, contract)
        XCTAssertEqual(row.timestamp, 200)
        XCTAssertFalse(row.processed)
    }

    func testFalseBranchKeepsExistingWhenAlreadyConfirmed() throws {
        let storage = makeStorage()
        let hash = h(0xB2)
        let contract = Data([0x09])
        storage.save(transactions: [tx(hash: hash, timestamp: 100, blockNumber: 1, confirmed: true, contract: contract)], replaceOnConflict: true)

        storage.save(transactions: [stub(hash: hash, timestamp: 999)], replaceOnConflict: false)

        let row = try XCTUnwrap(storage.unprocessedTransactions().first { $0.hash == hash })
        XCTAssertEqual(row.timestamp, 100) // untouched
        XCTAssertEqual(row.contractsRaw, contract) // not clobbered to nil
    }

    func testFalseBranchInsertsWhenAbsent() throws {
        let storage = makeStorage()
        let hash = h(0xC3)
        storage.save(transactions: [stub(hash: hash, timestamp: 100)], replaceOnConflict: false)
        XCTAssertNotNil(storage.unprocessedTransactions().first { $0.hash == hash })
    }

    // MARK: - helpers

    private func makeStorage() -> TransactionStorage {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return TransactionStorage(databaseDirectoryUrl: dir, databaseFileName: "test")
    }

    private func h(_ byte: UInt8) -> Data { Data([byte]) }

    private func tx(hash: Data, timestamp: Int, isFailed: Bool = false, blockNumber: Int? = nil, confirmed: Bool, fee: Int? = nil, contract: Data?) -> Transaction {
        Transaction(
            hash: hash, timestamp: timestamp, isFailed: isFailed, blockNumber: blockNumber, confirmed: confirmed,
            fee: fee, netUsage: nil, netFee: nil, energyUsage: nil, energyFee: nil, energyUsageTotal: nil,
            contractsRaw: contract
        )
    }

    private func stub(hash: Data, timestamp: Int) -> Transaction {
        Transaction(hash: hash, timestamp: timestamp, isFailed: false, confirmed: true)
    }
}
