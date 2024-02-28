import GRDB

class TransactionSyncTimestamp: Record {
    let apiPath: String
    let lastTransactionTimestamp: Int

    init(apiPath: String, lastTransactionTimestamp: Int) {
        self.apiPath = apiPath
        self.lastTransactionTimestamp = lastTransactionTimestamp

        super.init()
    }

    override public class var databaseTableName: String {
        "transaction_sync_timestamps"
    }

    enum Columns: String, ColumnExpression, CaseIterable {
        case apiPath
        case lastTransactionTimestamp
    }

    required init(row: Row) throws {
        apiPath = row[Columns.apiPath]
        lastTransactionTimestamp = row[Columns.lastTransactionTimestamp]

        try super.init(row: row)
    }

    override public func encode(to container: inout PersistenceContainer) {
        container[Columns.apiPath] = apiPath
        container[Columns.lastTransactionTimestamp] = lastTransactionTimestamp
    }
}
