open class TransactionDecoration {

    public init() {
    }

    open func tags(userAddress: Address) -> [TransactionTag] {
        []
    }

}
