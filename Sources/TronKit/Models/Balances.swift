import GRDB
import BigInt

class Balances: Record {
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

    required init(row: Row) {
        id = row[Columns.id]
        balance = row[Columns.balance]

        super.init(row: row)
    }

    override func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.balance] = balance
    }

}
