import GRDB

class ChainParameter: Record {
    let key: String
    let value: Int?

    init(key: String, value: Int?) {
        self.key = key
        self.value = value

        super.init()
    }

    public override class var databaseTableName: String {
        "chain_parameters"
    }

    enum Columns: String, ColumnExpression, CaseIterable {
        case key
        case value
    }

    required init(row: Row) {
        key = row[Columns.key]
        value = row[Columns.value]

        super.init(row: row)
    }

    public override func encode(to container: inout PersistenceContainer) {
        container[Columns.key] = key
        container[Columns.value] = value
    }

}
