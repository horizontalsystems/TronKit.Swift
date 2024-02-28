import BigInt

public class Trc20TransferEvent: Event {
    public let from: Address
    public let to: Address
    public let value: BigUInt

    public let tokenInfo: TokenInfo?

    init(record: Trc20EventRecord) {
        self.from = record.from
        self.to = record.to
        self.value = record.value
        self.tokenInfo = TokenInfo(tokenName: record.tokenName, tokenSymbol: record.tokenSymbol, tokenDecimal: record.tokenDecimal)

        super.init(transactionHash: record.transactionHash, contractAddress: record.contractAddress)
    }

    public override func tags(userAddress: Address) -> [TransactionTag] {
        var tags = [TransactionTag]()

        if from == userAddress {
            tags.append(TransactionTag(type: .outgoing, protocol: .eip20, contractAddress: contractAddress, addresses: [to.hex]))
        }

        if to == userAddress {
            tags.append(TransactionTag(type: .incoming, protocol: .eip20, contractAddress: contractAddress, addresses: [from.hex]))
        }

        return tags
    }

}
