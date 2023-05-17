import Foundation
import GRDB

public class InternalTransaction: Record {
    public let transactionHash: Data
    public let timestamp: Int
    public let from: Address
    public let to: Address
    public let value: Int
    public let internalTxId: String

    init(transactionHash: Data, timestamp: Int, from: Address, to: Address, value: Int, internalTxId: String) {
        self.transactionHash = transactionHash
        self.timestamp = timestamp
        self.from = from
        self.to = to
        self.value = value
        self.internalTxId = internalTxId

        super.init()
    }

    override public class var databaseTableName: String {
        "internal_transactions"
    }

    enum Columns: String, ColumnExpression, CaseIterable {
        case transactionHash
        case timestamp
        case from
        case to
        case value
        case internalTxId
    }

    required init(row: Row) {
        transactionHash = row[Columns.transactionHash]
        timestamp = row[Columns.timestamp]
        from = row[Columns.from]
        to = row[Columns.to]
        value = row[Columns.value]
        internalTxId = row[Columns.internalTxId]

        super.init(row: row)
    }

    override public func encode(to container: inout PersistenceContainer) {
        container[Columns.transactionHash] = transactionHash
        container[Columns.timestamp] = timestamp
        container[Columns.from] = from
        container[Columns.to] = to
        container[Columns.value] = value
        container[Columns.internalTxId] = internalTxId
    }

}
