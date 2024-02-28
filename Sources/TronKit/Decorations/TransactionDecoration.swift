open class TransactionDecoration {
    public init() {}

    open func tags(userAddress _: Address) -> [TransactionTag] {
        []
    }
}
