import GRDB
import BigInt

class Balance: Record {
    let id: String
    var balance: BigUInt

    init(id: String, balance: BigUInt) {
        self.id = id
        self.balance = balance

        super.init()
    }

    override class var databaseTableName: String {
        return "balances"
    }

    enum Columns: String, ColumnExpression {
        case id
        case balance
    }

    required init(row: Row) throws {
        id = row[Columns.id]
        balance = row[Columns.balance]

        try super.init(row: row)
    }

    override func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.balance] = balance
    }

}

extension BigUInt: DatabaseValueConvertible {

    public var databaseValue: DatabaseValue {
        description.databaseValue
    }

    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> BigUInt? {
        if case let DatabaseValue.Storage.string(value) = dbValue.storage {
            return BigUInt(value)
        }

        return nil
    }

}
