import BigInt
import HsExtensions

class Syncer {
    private var tasks = Set<AnyTask>()

    private let accountInfoManager: AccountInfoManager
    private let chainParameterManager: ChainParameterManager
    private let syncTimer: SyncTimer
    private let rpcApiProvider: IRpcApiProvider
    private let nodeApiProvider: INodeApiProvider
    private let historyProvider: IHistoryProvider?
    private let storage: SyncerStorage
    private let address: Address
    private var syncing = false

    @DistinctPublished private(set) var state: SyncState = .notSynced(error: Kit.SyncError.notStarted)
    @DistinctPublished private(set) var lastBlockHeight: Int = 0

    init(
        accountInfoManager: AccountInfoManager,
        chainParameterManager: ChainParameterManager,
        syncTimer: SyncTimer,
        rpcApiProvider: IRpcApiProvider,
        nodeApiProvider: INodeApiProvider,
        historyProvider: IHistoryProvider?,
        storage: SyncerStorage,
        address: Address
    ) {
        self.accountInfoManager = accountInfoManager
        self.chainParameterManager = chainParameterManager
        self.syncTimer = syncTimer
        self.rpcApiProvider = rpcApiProvider
        self.nodeApiProvider = nodeApiProvider
        self.historyProvider = historyProvider
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
    func start() {
        syncChainParameters()
        syncTimer.start()
    }

    func stop() {
        syncTimer.stop()
    }

    func refresh() {
        switch syncTimer.state {
        case .ready: sync()
        case .notReady: syncTimer.start()
        }
    }
}

extension Syncer: ISyncTimerDelegate {
    func didUpdate(state: SyncTimer.State) {
        switch state {
        case .ready:
            set(state: .syncing(progress: nil))
            sync()
        case let .notReady(error):
            tasks = Set()
            set(state: .notSynced(error: error))
        }
    }

    func sync() {
        Task { [weak self, lastBlockHeight, rpcApiProvider, nodeApiProvider, historyProvider, address, storage] in
            do {
                guard let syncer = self, !syncer.syncing else { return }
                syncer.syncing = true

                let newLastBlockHeight = try await rpcApiProvider.fetch(rpc: BlockNumberJsonRpc())

                guard newLastBlockHeight != lastBlockHeight else {
                    self?.set(state: .synced)
                    return
                }

                storage.save(lastBlockHeight: newLastBlockHeight)
                self?.lastBlockHeight = newLastBlockHeight

                if let historyProvider {
                    try await syncer.syncAccountViaHistory(address: address.base58, historyProvider: historyProvider)
                } else {
                    try await syncer.syncAccountViaRpc(address: address.base58, rpcApiProvider: rpcApiProvider, nodeApiProvider: nodeApiProvider)
                }
            } catch {
                self?.set(state: .notSynced(error: error))
            }
        }.store(in: &tasks)
    }

    // Fetch TRX + all TRC20 balances via history provider (single call).
    // Also ensures watched tokens with zero balance are explicitly stored.
    private func syncAccountViaHistory(address: String, historyProvider: IHistoryProvider) async throws {
        do {
            let response = try await historyProvider.fetchAccountInfo(address: address)
            accountInfoManager.handle(accountInfoResponse: response)

            // fetchAccountInfo only returns non-zero balances. For watched tokens absent
            // from the response, explicitly store 0 so they appear in the UI.
            for contractAddress in accountInfoManager.trc20AddressesToSync() {
                if response.trc20[contractAddress] == nil {
                    accountInfoManager.handle(trc20Balance: .zero, contractAddress: contractAddress)
                }
            }
        } catch TronGridProvider.RequestError.failedToFetchAccountInfo {
            accountInfoManager.handleInactiveAccount()
        }
        set(state: .synced)
    }

    // Fetch TRX balance via node API + TRC20 balances via balanceOf RPC calls.
    // Covers both previously seen tokens and manually watched tokens.
    private func syncAccountViaRpc(address: String, rpcApiProvider: IRpcApiProvider, nodeApiProvider: INodeApiProvider) async throws {
        guard let account = try await nodeApiProvider.fetchAccount(address: address) else {
            accountInfoManager.handleInactiveAccount()
            set(state: .synced)
            return
        }

        accountInfoManager.handle(trxBalance: account.balance)

        for contractAddress in accountInfoManager.trc20AddressesToSync() {
            let methodData = BalanceOfMethod(owner: self.address).encodedABI()
            let callRpc = CallJsonRpc(contractAddress: contractAddress, data: methodData)

            if let response = try? await rpcApiProvider.fetch(rpc: callRpc), response.count >= 32 {
                accountInfoManager.handle(trc20Balance: BigUInt(response[0 ... 31]), contractAddress: contractAddress)
            }
        }

        set(state: .synced)
    }
}
