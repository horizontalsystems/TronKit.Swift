import Foundation
import GRDB
import BigInt

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
            try db.create(table: Balances.databaseTableName, body: { t in
                t.column(Balances.Columns.id.name, .text).notNull().primaryKey(onConflict: .replace)
                t.column(Balances.Columns.balance.name, .text).notNull()
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
            try Balances.filter(Balances.Columns.id == trxId).fetchOne(db)?.balance
        }
    }

    func save(trxBalance: BigUInt) {
        _ = try! dbPool.write { db in
            let balance = Balances(id: trxId, balance: trxBalance)
            try balance.insert(db)
        }
    }

}
