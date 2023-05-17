import BigInt

public class Trc20ApproveEvent: Event {
    public let owner: Address
    public let spender: Address
    public let value: BigUInt

    public let tokenInfo: TokenInfo?

    init(record: Trc20EventRecord) {
        self.owner = record.from
        self.spender = record.to
        self.value = record.value
        self.tokenInfo = TokenInfo(tokenName: record.tokenName, tokenSymbol: record.tokenSymbol, tokenDecimal: record.tokenDecimal)

        super.init(transactionHash: record.transactionHash, contractAddress: record.contractAddress)
    }

    public override func tags(userAddress: Address) -> [TransactionTag] {
        [TransactionTag(type: .approve, protocol: .eip20, contractAddress: contractAddress)]
    }

}
