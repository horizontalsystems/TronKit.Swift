import Foundation

open class Event {
    public let transactionHash: Data
    public let contractAddress: Address

    public init(transactionHash: Data, contractAddress: Address) {
        self.transactionHash = transactionHash
        self.contractAddress = contractAddress
    }

    open func tags(userAddress _: Address) -> [TransactionTag] {
        []
    }
}

public struct TokenInfo {
    public let tokenName: String
    public let tokenSymbol: String
    public let tokenDecimal: Int
}
