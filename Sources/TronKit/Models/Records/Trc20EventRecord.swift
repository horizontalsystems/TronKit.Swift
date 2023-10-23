import Foundation
import GRDB
import BigInt

public class Trc20EventRecord: Record {
    public let transactionHash: Data
    public let type: String
    public let blockTimestamp: Int
    public let contractAddress: Address
    public let from: Address
    public let to: Address
    public let value: BigUInt
    public let tokenName: String
    public let tokenSymbol: String
    public let tokenDecimal: Int

    public init(transactionHash: Data, type: String, blockTimestamp: Int, contractAddress: Address, from: Address, to: Address, value: BigUInt, tokenName: String, tokenSymbol: String, tokenDecimal: Int) {
        self.transactionHash = transactionHash
        self.type = type
        self.blockTimestamp = blockTimestamp
        self.contractAddress = contractAddress
        self.from = from
        self.to = to
        self.value = value
        self.tokenName = tokenName
        self.tokenSymbol = tokenSymbol
        self.tokenDecimal = tokenDecimal

        super.init()
    }

    override public class var databaseTableName: String {
        "events"
    }

    enum Columns: String, ColumnExpression {
        case transactionHash
        case type
        case blockNumber
        case contractAddress
        case from
        case to
        case value
        case tokenName
        case tokenSymbol
        case tokenDecimal
    }

    required public init(row: Row) throws {
        transactionHash = row[Columns.transactionHash]
        type = row[Columns.type]
        blockTimestamp = row[Columns.blockNumber]
        contractAddress = row[Columns.contractAddress]
        from = row[Columns.from]
        to = row[Columns.to]
        value = row[Columns.value]
        tokenName = row[Columns.tokenName]
        tokenSymbol = row[Columns.tokenSymbol]
        tokenDecimal = row[Columns.tokenDecimal]

        try super.init(row: row)
    }

    override public func encode(to container: inout PersistenceContainer) {
        container[Columns.transactionHash] = transactionHash
        container[Columns.type] = type
        container[Columns.blockNumber] = blockTimestamp
        container[Columns.contractAddress] = contractAddress
        container[Columns.from] = from
        container[Columns.to] = to
        container[Columns.value] = value
        container[Columns.tokenName] = tokenName
        container[Columns.tokenSymbol] = tokenSymbol
        container[Columns.tokenDecimal] = tokenDecimal
    }

}
