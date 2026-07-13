import Foundation
import GRDB
@testable import TronKit
import XCTest

final class TransactionManagerPendingTests: XCTestCase {
    // MARK: - handle(pendingHash:) inject-once guard

    func testInjectPending_insertsPendingRow() throws {
        let (manager, storage) = makeManager()
        let hash = Data([0xA1])
        manager.handle(pendingHash: hash, timestamp: 100, contractsMap: [[String: Any]]())
        let row = try XCTUnwrap(storage.transaction(hash: hash))
        XCTAssertFalse(row.confirmed)
        XCTAssertEqual(row.timestamp, 100)
    }

    func testInjectPending_secondInjectDoesNotOverwrite() throws {
        let (manager, storage) = makeManager()
        let hash = Data([0xA2])
        manager.handle(pendingHash: hash, timestamp: 100, contractsMap: [[String: Any]]())
        manager.handle(pendingHash: hash, timestamp: 999, contractsMap: [[String: Any]]())
        let row = try XCTUnwrap(storage.transaction(hash: hash))
        XCTAssertEqual(row.timestamp, 100) // guard: existing row not overwritten
    }

    func testInjectPending_doesNotDowngradeConfirmed() throws {
        let (manager, storage) = makeManager()
        let hash = Data([0xA3])
        storage.save(transactions: [confirmed(hash: hash)], replaceOnConflict: true)
        manager.handle(pendingHash: hash, timestamp: 999, contractsMap: [[String: Any]]())
        let row = try XCTUnwrap(storage.transaction(hash: hash))
        XCTAssertTrue(row.confirmed) // guard: confirmed row never downgraded to pending
    }

    // MARK: - markFailed (fail-flip)

    func testMarkFailed_flipsPendingToFailed() throws {
        let (manager, storage) = makeManager()
        let hash = Data([0xB1])
        storage.save(transactions: [pending(hash: hash)], replaceOnConflict: true)
        manager.markFailed(hash: hash)
        let row = try XCTUnwrap(storage.transaction(hash: hash))
        XCTAssertTrue(row.isFailed)
        XCTAssertFalse(row.confirmed)
    }

    func testMarkFailed_noOpOnConfirmed() throws {
        let (manager, storage) = makeManager()
        let hash = Data([0xB2])
        storage.save(transactions: [confirmed(hash: hash)], replaceOnConflict: true)
        manager.markFailed(hash: hash)
        let row = try XCTUnwrap(storage.transaction(hash: hash))
        XCTAssertFalse(row.isFailed) // never override a real confirm
    }

    // MARK: - helpers

    private func makeManager() -> (TransactionManager, TransactionStorage) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let storage = TransactionStorage(databaseDirectoryUrl: dir, databaseFileName: "test")
        let address = try! Address(address: "TC54MPJhefAw3De5KLHzox4rNwvTNHfAvP")
        let decorationManager = DecorationManager(userAddress: address, storage: storage)
        let manager = TransactionManager(userAddress: address, storage: storage, decorationManager: decorationManager)
        return (manager, storage)
    }

    private func pending(hash: Data) -> Transaction {
        Transaction(
            hash: hash, timestamp: 100, isFailed: false, blockNumber: nil, confirmed: false,
            fee: nil, netUsage: nil, netFee: nil, energyUsage: nil, energyFee: nil, energyUsageTotal: nil,
            contractsRaw: nil
        )
    }

    private func confirmed(hash: Data) -> Transaction {
        Transaction(hash: hash, timestamp: 100, isFailed: false, confirmed: true)
    }
}
