import BigInt
import Foundation

open class UnknownTransactionDecoration: TransactionDecoration {
    public let toAddress: Address?
    public let fromAddress: Address?
    public let data: Data?
    public let value: Int?
    public let tokenValue: Int?
    public let tokenId: Int?

    public let internalTransactions: [InternalTransaction]
    public let events: [Event]

    init(contract: TriggerSmartContract?, internalTransactions: [InternalTransaction], events: [Event]) {
        fromAddress = contract?.ownerAddress
        toAddress = contract?.contractAddress
        data = contract?.data.hs.hexData
        value = contract?.callValue
        tokenValue = contract?.callTokenValue
        tokenId = contract?.tokenId
        self.internalTransactions = internalTransactions
        self.events = events
    }

    override public func tags(userAddress: Address) -> [TransactionTag] {
        Array(Set(tagsFromInternalTransactions(userAddress: userAddress) + tagsFromEventInstances(userAddress: userAddress)))
    }

    private func tagsFromInternalTransactions(userAddress: Address) -> [TransactionTag] {
        let value = value ?? 0
        let incomingInternalTransactions = internalTransactions.filter { $0.to == userAddress }

        var outgoingValue = 0
        if fromAddress == userAddress {
            outgoingValue = value
        }
        var incomingValue = 0
        if toAddress == userAddress {
            incomingValue = value
        }
        incomingInternalTransactions.forEach {
            incomingValue += $0.value
        }

        // if has value or has internalTxs must add Evm tag
        if outgoingValue == 0, incomingValue == 0 {
            return []
        }

        var tags = [TransactionTag]()

        var addresses = [fromAddress, toAddress]
            .compactMap { $0 }
            .filter { $0 != userAddress }
            .map(\.hex)

        if incomingValue > outgoingValue {
            tags.append(TransactionTag(type: .incoming, protocol: .native, addresses: addresses))
        } else if outgoingValue > incomingValue {
            tags.append(TransactionTag(type: .outgoing, protocol: .native, addresses: addresses))
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
