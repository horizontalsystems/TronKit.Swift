import BigInt

open class UnknownTransactionDecoration: TransactionDecoration {
    private let toAddress: Address?
    public let fromAddress: Address?
    private let value: Int?
    private let tokenValue: Int?
    private let tokenId: Int?

    public let internalTransactions: [InternalTransaction]
    public let events: [Event]

    init(contract: TriggerSmartContract?, internalTransactions: [InternalTransaction], events: [Event]) {
        self.fromAddress = contract?.ownerAddress
        self.toAddress = contract?.contractAddress
        self.value = contract?.callValue
        self.tokenValue = contract?.callTokenValue
        self.tokenId = contract?.tokenId
        self.internalTransactions = internalTransactions
        self.events = events
    }

    public override func tags(userAddress: Address) -> [TransactionTag] {
        Array(Set(tagsFromInternalTransactions(userAddress: userAddress) + tagsFromEventInstances(userAddress: userAddress)))
    }

    private func tagsFromInternalTransactions(userAddress: Address) -> [TransactionTag] {
        let value = value ?? 0
        let incomingInternalTransactions = internalTransactions.filter { $0.to == userAddress }

        var outgoingValue: Int = 0
        if fromAddress == userAddress {
            outgoingValue = value
        }
        var incomingValue: Int = 0
        if toAddress == userAddress {
            incomingValue = value
        }
        incomingInternalTransactions.forEach {
            incomingValue += $0.value
        }

        // if has value or has internalTxs must add Evm tag
        if outgoingValue == 0 && incomingValue == 0 {
            return []
        }

        var tags = [TransactionTag]()

        if incomingValue > outgoingValue {
            tags.append(TransactionTag(type: .incoming, protocol: .native))
        } else if outgoingValue > incomingValue {
            tags.append(TransactionTag(type: .outgoing, protocol: .native))
        }

        return tags
    }

    private func tagsFromEventInstances(userAddress: Address) -> [TransactionTag] {
        var tags = [TransactionTag]()

        for event in events {
            tags.append(contentsOf: event.tags(userAddress: userAddress))
        }

        return tags
    }

}
