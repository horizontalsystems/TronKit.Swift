import HsExtensions

class Syncer {
    private var tasks = Set<AnyTask>()

    private let accountInfoManager: AccountInfoManager
    private let transactionManager: TransactionManager
    private let chainParameterManager: ChainParameterManager
    private let syncTimer: SyncTimer
    private let tronGridProvider: TronGridProvider
    private let storage: SyncerStorage
    private let address: Address
    private var syncing: Bool = false

    @DistinctPublished private(set) var state: SyncState = .notSynced(error: Kit.SyncError.notStarted)
    @DistinctPublished private(set) var lastBlockHeight: Int = 0

    init(accountInfoManager: AccountInfoManager, transactionManager: TransactionManager, chainParameterManager: ChainParameterManager,
         syncTimer: SyncTimer, tronGridProvider: TronGridProvider, storage: SyncerStorage, address: Address) {
        self.accountInfoManager = accountInfoManager
        self.transactionManager = transactionManager
        self.chainParameterManager = chainParameterManager
        self.syncTimer = syncTimer
        self.tronGridProvider = tronGridProvider
        self.storage = storage
        self.address = address

        syncTimer.delegate = self
        lastBlockHeight = storage.lastBlockHeight ?? 0
    }

    private func syncChainParameters() {
        Task { [chainParameterManager] in
            try await chainParameterManager.sync()
        }
    }

    private func set(state: SyncState) {
        self.state = state

        if case .syncing = state {} else {
            syncing = false
        }
    }

}

extension Syncer {

    var source: String {
        "RPC \(tronGridProvider.source)"
    }

    func start() {
        syncChainParameters()
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
            set(state: .syncing(progress: nil))
            sync()
        case .notReady(let error):
            tasks = Set()
            set(state: .notSynced(error: error))
        }
    }

    func sync() {
        Task { [weak self, lastBlockHeight, tronGridProvider, address, storage] in
            do {
                guard let syncer = self, !syncer.syncing else {
                    return
                }
                syncer.syncing = true

                let address = address.base58
                let newLastBlockHeight = try await tronGridProvider.fetch(rpc: BlockNumberJsonRpc())

                guard newLastBlockHeight != lastBlockHeight else {
                    self?.set(state: .synced)
                    return
                }
                storage.save(lastBlockHeight: newLastBlockHeight)
                self?.lastBlockHeight = newLastBlockHeight

                let response = try await tronGridProvider.fetchAccountInfo(address: address)
                self?.accountInfoManager.handle(accountInfoResponse: response)

                let lastTrc20TxTimestamp = storage.lastTransactionTimestamp(apiPath: TronGridProvider.ApiPath.transactionsTrc20.rawValue) ?? 0
                var fingerprint: String?
                var completed = false
                repeat {
                    let fetchResult = try await tronGridProvider.fetchTrc20Transactions(
                        address: address,
                        minTimestamp: lastTrc20TxTimestamp + 1000,
                        fingerprint: fingerprint
                    )

                    if let lastTransaction = fetchResult.transactions.last {
                        self?.transactionManager.save(trc20TransferResponses: fetchResult.transactions)
                        storage.save(apiPath: TronGridProvider.ApiPath.transactionsTrc20.rawValue, lastTransactionTimestamp: lastTransaction.blockTimestamp)
                    }
                    fingerprint = fetchResult.fingerprint
                    completed = fetchResult.completed
                } while !completed

                let lastTxTimestamp = storage.lastTransactionTimestamp(apiPath: TronGridProvider.ApiPath.transactions.rawValue) ?? 0
                fingerprint = nil
                completed = false
                repeat {
                    let fetchResult = try await tronGridProvider.fetchTransactions(
                        address: address,
                        minTimestamp: lastTxTimestamp + 1000,
                        fingerprint: fingerprint
                    )

                    if let lastTransaction = fetchResult.transactions.last {
                        self?.transactionManager.save(transactionResponses: fetchResult.transactions)
                        storage.save(apiPath: TronGridProvider.ApiPath.transactions.rawValue, lastTransactionTimestamp: lastTransaction.blockTimestamp)
                    }

                    fingerprint = fetchResult.fingerprint
                    completed = fetchResult.completed
                } while !completed

                self?.transactionManager.process(initial: lastTxTimestamp == 0 || lastTrc20TxTimestamp == 0)
                self?.set(state: .synced)
            } catch {
                if let requestError = error as? TronGridProvider.RequestError,
                   case .failedToFetchAccountInfo = requestError {
                    self?.accountInfoManager.handleInactiveAccount()
                    self?.set(state: .synced)
                } else {
                    self?.set(state: .notSynced(error: error))
                }
            }
        }.store(in: &tasks)
    }

}
