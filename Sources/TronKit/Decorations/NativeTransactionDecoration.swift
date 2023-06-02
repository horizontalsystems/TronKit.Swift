public class NativeTransactionDecoration: TransactionDecoration {
    public let contract: Contract

    init(contract: Contract) {
        self.contract = contract
    }

    public override func tags(userAddress: Address) -> [TransactionTag] {
        var tags = [TransactionTag]()

        switch contract {
            case let contract as TransferContract:
                if contract.ownerAddress == userAddress {
                    tags.append(TransactionTag(type: .outgoing, protocol: .native))
                }
                if contract.toAddress == userAddress {
                    tags.append(TransactionTag(type: .incoming, protocol: .native))
                }

            case let contract as TransferAssetContract:
                if contract.ownerAddress == userAddress {
                    tags.append(TransactionTag(type: .outgoing, protocol: .trc10))
                }
                if contract.toAddress == userAddress {
                    tags.append(TransactionTag(type: .incoming, protocol: .trc10))
                }

            default: ()

        }

        return tags
    }

}
