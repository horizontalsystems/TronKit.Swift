import BigInt

public class ApproveEip20Decoration: TransactionDecoration {
    public let contractAddress: Address
    public let spender: Address
    public let value: BigUInt

    init(contractAddress: Address, spender: Address, value: BigUInt) {
        self.contractAddress = contractAddress
        self.spender = spender
        self.value = value

        super.init()
    }

    public override func tags(userAddress: Address) -> [TransactionTag] {
        [
            TransactionTag(type: .approve, protocol: .eip20, contractAddress: contractAddress)
        ]
    }

}
