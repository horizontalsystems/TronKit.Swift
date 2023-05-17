import Foundation
import GRDB

class TransactionStorage {
    private let dbPool: DatabasePool

    init(databaseDirectoryUrl: URL, databaseFileName: String) {
        let databaseURL = databaseDirectoryUrl.appendingPathComponent("\(databaseFileName).sqlite")

        dbPool = try! DatabasePool(path: databaseURL.path)

        try! migrator.migrate(dbPool)
    }

    var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("Create Transaction") { db in
            try db.create(table: Transaction.databaseTableName) { t in
                t.column(Transaction.Columns.hash.name, .text).notNull().primaryKey(onConflict: .replace)
                t.column(Transaction.Columns.timestamp.name, .integer).notNull()
                t.column(Transaction.Columns.isFailed.name, .boolean).notNull()
                t.column(Transaction.Columns.blockNumber.name, .integer)
                t.column(Transaction.Columns.processed.name, .boolean).notNull()
                t.column(Transaction.Columns.fee.name, .integer)
                t.column(Transaction.Columns.netUsage.name, .integer)
                t.column(Transaction.Columns.netFee.name, .integer)
                t.column(Transaction.Columns.energyUsage.name, .integer)
                t.column(Transaction.Columns.energyFee.name, .integer)
                t.column(Transaction.Columns.energyUsageTotal.name, .integer)
                t.column(Transaction.Columns.contractsRaw.name, .text)
            }
        }

        migrator.registerMigration("create InternalTransaction") { db in
            try db.create(table: InternalTransaction.databaseTableName) { t in
                t.column(InternalTransaction.Columns.internalTxId.name, .text).notNull().primaryKey(onConflict: .replace)
                t.column(InternalTransaction.Columns.transactionHash.name, .text).notNull().indexed()
                t.column(InternalTransaction.Columns.timestamp.name, .integer).notNull()
                t.column(InternalTransaction.Columns.from.name, .text).notNull()
                t.column(InternalTransaction.Columns.to.name, .text).notNull()
                t.column(InternalTransaction.Columns.value.name, .integer).notNull()

                t.foreignKey([InternalTransaction.Columns.transactionHash.name], references: Transaction.databaseTableName, columns: [Transaction.Columns.hash.name], onDelete: .cascade, onUpdate: .cascade, deferred: true)
            }
        }

        migrator.registerMigration("create Trc20TransferRecord") { db in
            try db.create(table: Trc20EventRecord.databaseTableName) { t in
                t.column(Trc20EventRecord.Columns.transactionHash.name, .text).notNull().indexed()
                t.column(Trc20EventRecord.Columns.type.name, .text).notNull()
                t.column(Trc20EventRecord.Columns.blockNumber.name, .integer).notNull()
                t.column(Trc20EventRecord.Columns.contractAddress.name, .text).notNull()
                t.column(Trc20EventRecord.Columns.from.name, .text).notNull()
                t.column(Trc20EventRecord.Columns.to.name, .text).notNull()
                t.column(Trc20EventRecord.Columns.value.name, .text).notNull()
                t.column(Trc20EventRecord.Columns.tokenName.name, .text).notNull()
                t.column(Trc20EventRecord.Columns.tokenSymbol.name, .text).notNull()
                t.column(Trc20EventRecord.Columns.tokenDecimal.name, .integer).notNull()

                t.foreignKey([Trc20EventRecord.Columns.transactionHash.name], references: Transaction.databaseTableName, columns: [Transaction.Columns.hash.name], onDelete: .cascade, onUpdate: .cascade, deferred: true)
            }
        }

        migrator.registerMigration("create TransactionTagRecord") { db in
            try db.create(table: TransactionTagRecord.databaseTableName) { t in
                t.column(TransactionTagRecord.Columns.transactionHash.name, .blob).notNull().indexed()
                t.column(TransactionTagRecord.Columns.type.name, .text).notNull()
                t.column(TransactionTagRecord.Columns.protocol.name, .text)
                t.column(TransactionTagRecord.Columns.contractAddress.name, .blob)

                t.foreignKey([TransactionTagRecord.Columns.transactionHash.name], references: Transaction.databaseTableName, columns: [Transaction.Columns.hash.name], onDelete: .cascade, onUpdate: .cascade, deferred: true)
            }
        }

        return migrator
    }

}

extension TransactionStorage {

    func transactionsBefore(tagQueries: [TransactionTagQuery], hash: Data?, limit: Int?) -> [Transaction] {
        try! dbPool.read { db in
            var arguments = [DatabaseValueConvertible]()
            var whereConditions: [String] = ["\(Transaction.Columns.processed) = 1"]
            let queries = tagQueries.filter { !$0.isEmpty }
            var joinClause = ""

            if !queries.isEmpty {
                let tagConditions = queries
                    .map { (tagQuery: TransactionTagQuery) -> String in
                        var statements = [String]()

                        if let type = tagQuery.type {
                            statements.append("\(TransactionTagRecord.databaseTableName).'\(TransactionTagRecord.Columns.type.name)' = ?")
                            arguments.append(type)
                        }
                        if let `protocol` = tagQuery.protocol {
                            statements.append("\(TransactionTagRecord.databaseTableName).'\(TransactionTagRecord.Columns.protocol.name)' = ?")
                            arguments.append(`protocol`)
                        }
                        if let contractAddress = tagQuery.contractAddress {
                            statements.append("\(TransactionTagRecord.databaseTableName).'\(TransactionTagRecord.Columns.contractAddress.name)' = ?")
                            arguments.append(contractAddress)
                        }

                        return "(\(statements.joined(separator: " AND ")))"
                    }
                    .joined(separator: " OR ")

                whereConditions.append(tagConditions)
                joinClause = "INNER JOIN \(TransactionTagRecord.databaseTableName) ON \(Transaction.databaseTableName).\(Transaction.Columns.hash.name) = \(TransactionTagRecord.databaseTableName).\(TransactionTagRecord.Columns.transactionHash.name)"
            }

            if let fromHash = hash,
               let fromTransaction = try Transaction.filter(Transaction.Columns.hash == fromHash).fetchOne(db) {
                let fromCondition = """
                                    (
                                     \(Transaction.Columns.timestamp.name) < ? OR
                                         (
                                             \(Transaction.databaseTableName).\(Transaction.Columns.timestamp.name) = ? AND
                                             \(Transaction.databaseTableName).\(Transaction.Columns.hash.name) < ?
                                         )
                                    )
                                    """

                arguments.append(fromTransaction.timestamp)
                arguments.append(fromTransaction.timestamp)
                arguments.append(fromTransaction.hash)

                whereConditions.append(fromCondition)
            }

            var limitClause = ""
            if let limit = limit {
                limitClause += "LIMIT \(limit)"
            }

            let orderClause = """
                              ORDER BY \(Transaction.databaseTableName).\(Transaction.Columns.timestamp.name) DESC,
                              \(Transaction.databaseTableName).\(Transaction.Columns.hash.name) DESC
                              """

            let whereClause = whereConditions.count > 0 ? "WHERE \(whereConditions.joined(separator: " AND "))" : ""

            let sql = """
                      SELECT DISTINCT \(Transaction.databaseTableName).*
                      FROM \(Transaction.databaseTableName)
                      \(joinClause)
                      \(whereClause)
                      \(orderClause)
                      \(limitClause)
                      """

            let rows = try Row.fetchAll(db.makeStatement(sql: sql), arguments: StatementArguments(arguments))
            return rows.map { row -> Transaction in
                Transaction(row: row)
            }
        }
    }

    func unprocessedTransactions() -> [Transaction] {
        try! dbPool.read { db in
            try Transaction.filter(Transaction.Columns.processed == false).fetchAll(db)
        }
    }

    func lastInternalTransaction() -> InternalTransaction? {
        try! dbPool.read { db in
            try InternalTransaction
                .order(Transaction.Columns.blockNumber.desc)
                .fetchOne(db)
        }
    }

    func internalTransactions() -> [InternalTransaction] {
        try! dbPool.read { db in
            try InternalTransaction.fetchAll(db)
        }
    }

    func internalTransactions(hashes: [Data]) -> [InternalTransaction] {
        try! dbPool.read { db in
            try InternalTransaction
                .filter(hashes.contains(InternalTransaction.Columns.transactionHash))
                .fetchAll(db)
        }
    }

    func trc20Events() -> [Trc20EventRecord] {
        try! dbPool.read { db in
            try Trc20EventRecord.fetchAll(db)
        }
    }

    func trc20Events(hashes: [Data]) -> [Trc20EventRecord] {
        try! dbPool.read { db in
            try Trc20EventRecord
                .filter(hashes.contains(Trc20EventRecord.Columns.transactionHash))
                .fetchAll(db)
        }
    }

    func save(transactions: [Transaction], replaceOnConflict: Bool) {
        try! dbPool.write { db in
            for transaction in transactions {
                if !replaceOnConflict, try transaction.exists(db) {
                    continue
                }

                try transaction.save(db)
            }
        }
    }

    func save(internalTransactions: [InternalTransaction]) {
        try! dbPool.write { db in
            for internalTransaction in internalTransactions {
                try internalTransaction.save(db)
            }
        }
    }

    func save(trc20Transfers: [Trc20EventRecord]) {
        try! dbPool.write { db in
            for transfer in trc20Transfers {
                try transfer.save(db)
            }
        }
    }

    func save(tags: [TransactionTagRecord]) {
        try! dbPool.write { db in
            for tag in tags {
                try tag.save(db)
            }
        }
    }

    func markProcessed() {
        try! dbPool.write { db in
            _ = try Transaction.updateAll(db, [Transaction.Columns.processed.set(to: true)])
        }
    }
}
