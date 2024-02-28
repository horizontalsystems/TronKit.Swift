import BigInt
import Foundation
import GRDB

class AccountInfoStorage {
    private let dbPool: DatabasePool

    init(databaseDirectoryUrl: URL, databaseFileName: String) {
        let databaseURL = databaseDirectoryUrl.appendingPathComponent("\(databaseFileName).sqlite")

        dbPool = try! DatabasePool(path: databaseURL.path)

        try! migrator.migrate(dbPool)
    }

    var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("createBalances") { db in
            try db.create(table: Balance.databaseTableName, body: { t in
                t.column(Balance.Columns.id.name, .text).notNull().primaryKey(onConflict: .replace)
                t.column(Balance.Columns.balance.name, .text).notNull()
            })
        }

        return migrator
    }

    private var trxId = "TRX"
    private func trc10Id(name: String) -> String { "trc10/\(name)" }
    private func trc20Id(contractAddress: String) -> String { "trc20/\(contractAddress)" }
}

extension AccountInfoStorage {
    var trxBalance: BigUInt? {
        try! dbPool.read { db in
            try Balance.filter(Balance.Columns.id == trxId).fetchOne(db)?.balance
        }
    }

    func trc20Balance(address: String) -> BigUInt? {
        try! dbPool.read { db in
            try Balance.filter(Balance.Columns.id == trc20Id(contractAddress: address)).fetchOne(db)?.balance
        }
    }

    func save(trxBalance: BigUInt) {
        _ = try! dbPool.write { db in
            let balance = Balance(id: trxId, balance: trxBalance)
            try balance.insert(db)
        }
    }

    func save(trc20Balance: BigUInt, address: String) {
        _ = try! dbPool.write { db in
            let balance = Balance(id: trc20Id(contractAddress: address), balance: trc20Balance)
            try balance.insert(db)
        }
    }

    func clearTrc20Balances() {
        _ = try! dbPool.write { db in
            try Balance.filter(Balance.Columns.id != trxId).deleteAll(db)
        }
    }
}
