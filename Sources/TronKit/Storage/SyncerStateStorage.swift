import Foundation
import GRDB

class SyncerStateStorage {
    private let dbPool: DatabasePool

    init(databaseDirectoryUrl: URL, databaseFileName: String) {
        let databaseURL = databaseDirectoryUrl.appendingPathComponent("\(databaseFileName).sqlite")

        dbPool = try! DatabasePool(path: databaseURL.path)

        try! migrator.migrate(dbPool)
    }

    var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("createLastBlockHeight") { db in
            try db.create(table: LastBlockHeight.databaseTableName, body: { t in
                t.column(LastBlockHeight.Columns.primaryKey.name, .text).primaryKey(onConflict: .replace)
                t.column(LastBlockHeight.Columns.height.name, .integer).notNull()
            })
        }

        migrator.registerMigration("createTransactionSyncTimestamps") { db in
            try db.create(table: TransactionSyncTimestamp.databaseTableName) { t in
                t.column(TransactionSyncTimestamp.Columns.apiPath.name, .text).primaryKey(onConflict: .replace)
                t.column(TransactionSyncTimestamp.Columns.lastTransactionTimestamp.name, .integer).notNull()
            }
        }

        return migrator
    }

}

extension SyncerStateStorage {

    var lastBlockHeight: Int? {
        try? dbPool.read { db in
            try LastBlockHeight.fetchOne(db)?.height
        }
    }

    func save(lastBlockHeight: Int) {
        _ = try! dbPool.write { db in
            let state = try LastBlockHeight.fetchOne(db) ?? LastBlockHeight()
            state.height = lastBlockHeight
            try state.insert(db)
        }
    }

    func lastTransactionTimestamp(apiPath: String) -> Int? {
        try? dbPool.read { db in
            try TransactionSyncTimestamp.filter(TransactionSyncTimestamp.Columns.apiPath == apiPath).fetchOne(db)?.lastTransactionTimestamp
        }
    }

    func save(apiPath: String, lastTransactionTimestamp timestamp: Int) {
        _ = try! dbPool.write { db in
            let txSyncTimestamp = TransactionSyncTimestamp(apiPath: apiPath, lastTransactionTimestamp: timestamp)
            try txSyncTimestamp.insert(db)
        }
    }

}
