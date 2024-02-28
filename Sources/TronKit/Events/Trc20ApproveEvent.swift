import BigInt

public class Trc20ApproveEvent: Event {
    public let owner: Address
    public let spender: Address
    public let value: BigUInt

    public let tokenInfo: TokenInfo?

    init(record: Trc20EventRecord) {
        owner = record.from
        spender = record.to
        value = record.value
        tokenInfo = TokenInfo(tokenName: record.tokenName, tokenSymbol: record.tokenSymbol, tokenDecimal: record.tokenDecimal)

        super.init(transactionHash: record.transactionHash, contractAddress: record.contractAddress)
    }

    override public func tags(userAddress _: Address) -> [TransactionTag] {
        [TransactionTag(type: .approve, protocol: .eip20, contractAddress: contractAddress)]
    }
}
