import HsExtensions

class Syncer {
    private var tasks = Set<AnyTask>()

    private let accountInfoManager: AccountInfoManager
    private let transactionManager: TransactionManager
    private let syncTimer: SyncTimer
    private let tronGridProvider: TronGridProvider
    private let storage: SyncerStateStorage
    private let address: Address

    @DistinctPublished private(set) var state: SyncState = .notSynced(error: Kit.SyncError.notStarted)
    @DistinctPublished private(set) var lastBlockHeight: Int = 0

    init(accountInfoManager: AccountInfoManager, transactionManager: TransactionManager, syncTimer: SyncTimer, tronGridProvider: TronGridProvider, storage: SyncerStateStorage, address: Address) {
        self.accountInfoManager = accountInfoManager
        self.transactionManager = transactionManager
        self.syncTimer = syncTimer
        self.tronGridProvider = tronGridProvider
        self.storage = storage
        self.address = address

        syncTimer.delegate = self
        lastBlockHeight = storage.lastBlockHeight ?? 0
    }

}

extension Syncer {

    var source: String {
        "RPC \(tronGridProvider.source)"
    }

    func start() {
        state = .syncing(progress: nil)
        syncTimer.start()
    }

    func stop() {
        syncTimer.stop()
    }

    func refresh() {
        switch syncTimer.state {
        case .ready:
            sync()
        case .notReady:
            syncTimer.start()
        }
    }

}

extension Syncer: ISyncTimerDelegate {

    func didUpdate(state: SyncTimer.State) {
        switch state {
        case .ready:
            self.state = .syncing(progress: nil)
            sync()
        case .notReady(let error):
            tasks = Set()
            self.state = .notSynced(error: error)
        }
    }

    func sync() {
        Task { [weak self, lastBlockHeight, tronGridProvider, address, storage] in
            do {
                let address = address.base58
                let newLastBlockHeight = try await tronGridProvider.fetch(rpc: BlockNumberJsonRpc())

                guard newLastBlockHeight != lastBlockHeight else {
                    return
                }

                storage.save(lastBlockHeight: newLastBlockHeight)
                self?.lastBlockHeight = newLastBlockHeight

                let response = try await tronGridProvider.fetchAccountInfo(address: address)
                self?.accountInfoManager.handle(accountInfoResponse: response)
//
//                let transactions = try await tronGridProvider.fetchTransactions(address: address, lastTimestamp: storage.lastTransactionTimestamp(apiPath: TronGridProvider.ApiPath.transactions.rawValue) ?? 0)
//                let trc20Transactions = try await tronGridProvider.fetchTrc20Transactions(address: address, lastTimestamp: storage.lastTransactionTimestamp(apiPath: TronGridProvider.ApiPath.transactionsTrc20.rawValue) ?? 0)
//
//                self?.transactionManager.handle(transactions: transactions, trc20Transactions: trc20Transactions)
//
//                if let lastTransaction = transactions.first {
//                    storage.save(apiPath: TronGridProvider.ApiPath.transactions.rawValue, lastTransactionTimestamp: lastTransaction.blockTimestamp)
//                }
//
//                if let lastTransaction = trc20Transactions.first {
//                    storage.save(apiPath: TronGridProvider.ApiPath.transactionsTrc20.rawValue, lastTransactionTimestamp: lastTransaction.blockTimestamp)
//                }

                self?.state = .synced
            } catch {
                self?.state = .notSynced(error: error)
            }
        }.store(in: &tasks)
    }

}
