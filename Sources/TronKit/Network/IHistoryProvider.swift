protocol IHistoryProvider {
    func fetchAccountInfo(address: String) async throws -> AccountInfoResponse
    func fetchTransactions(address: String, minTimestamp: Int, cursor: String?) async throws -> ([ITransactionResponse], nextCursor: String?)
    func fetchTrc20Transactions(address: String, minTimestamp: Int, cursor: String?) async throws -> ([Trc20TransactionResponse], nextCursor: String?)
}
