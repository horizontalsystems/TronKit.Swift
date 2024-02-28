public class NativeTransactionDecoration: TransactionDecoration {
    public let contract: Contract

    init(contract: Contract) {
        self.contract = contract
    }

    override public func tags(userAddress: Address) -> [TransactionTag] {
        var tags = [TransactionTag]()

        switch contract {
        case let contract as TransferContract:
            if contract.ownerAddress == userAddress {
                tags.append(TransactionTag(type: .outgoing, protocol: .native, addresses: [contract.toAddress.hex]))
            }
            if contract.toAddress == userAddress {
                tags.append(TransactionTag(type: .incoming, protocol: .native, addresses: [contract.ownerAddress.hex]))
            }

        case let contract as TransferAssetContract:
            if contract.ownerAddress == userAddress {
                tags.append(TransactionTag(type: .outgoing, protocol: .trc10, addresses: [contract.toAddress.hex]))
            }
            if contract.toAddress == userAddress {
                tags.append(TransactionTag(type: .incoming, protocol: .trc10, addresses: [contract.ownerAddress.hex]))
            }

        default: ()
        }

        return tags
    }
}
