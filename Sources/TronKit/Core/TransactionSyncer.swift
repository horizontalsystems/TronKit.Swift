import HsExtensions

class TransactionSyncer {
    private static let maxTransactionCount = 1000

    private var tasks = Set<AnyTask>()

    private let historyProvider: IHistoryProvider
    private let transactionManager: TransactionManager
    private let storage: SyncerStorage
    private let address: Address
    private var syncing = false

    @DistinctPublished private(set) var state: SyncState = .notSynced(error: Kit.SyncError.notStarted)

    init(
        historyProvider: IHistoryProvider,
        transactionManager: TransactionManager,
        storage: SyncerStorage,
        address: Address
    ) {
        self.historyProvider = historyProvider
        self.transactionManager = transactionManager
        self.storage = storage
        self.address = address
    }

    private func set(state: SyncState) {
        self.state = state

        if case .syncing = state {} else {
            syncing = false
        }
    }
}

extension TransactionSyncer {
    func sync() {
        Task { [weak self, historyProvider, address, storage] in
            do {
                guard let syncer = self, !syncer.syncing else { return }
                syncer.syncing = true
                syncer.state = .syncing(progress: nil)

                let addressBase58 = address.base58
                var totalFetched = 0

                // Fetch TRC20 transfers
                let lastTrc20Timestamp = storage.lastTransactionTimestamp(apiPath: "trc20") ?? 0
                var cursor: String? = nil

                repeat {
                    let (transactions, nextCursor) = try await historyProvider.fetchTrc20Transactions(
                        address: addressBase58,
                        minTimestamp: lastTrc20Timestamp + 1,
                        cursor: cursor
                    )

                    if let last = transactions.last {
                        syncer.transactionManager.save(trc20TransferResponses: transactions)
                        storage.save(apiPath: "trc20", lastTransactionTimestamp: last.blockTimestamp)
                    }

                    totalFetched += transactions.count
                    cursor = nextCursor
                } while cursor != nil && totalFetched < Self.maxTransactionCount

                // Fetch regular transactions (separate cap)
                totalFetched = 0
                let lastTxTimestamp = storage.lastTransactionTimestamp(apiPath: "transactions") ?? 0
                cursor = nil
                let isInitial = lastTxTimestamp == 0 || lastTrc20Timestamp == 0

                repeat {
                    let (transactions, nextCursor) = try await historyProvider.fetchTransactions(
                        address: addressBase58,
                        minTimestamp: lastTxTimestamp + 1,
                        cursor: cursor
                    )

                    if let last = transactions.last {
                        syncer.transactionManager.save(transactionResponses: transactions)
                        storage.save(apiPath: "transactions", lastTransactionTimestamp: last.blockTimestamp)
                    }

                    totalFetched += transactions.count
                    cursor = nextCursor
                } while cursor != nil && totalFetched < Self.maxTransactionCount

                syncer.transactionManager.process(initial: isInitial)
                syncer.set(state: .synced)
            } catch {
                self?.set(state: .notSynced(error: error))
            }
        }.store(in: &tasks)
    }

    func stop() {
        tasks = Set()
        set(state: .notSynced(error: Kit.SyncError.notStarted))
    }
}
