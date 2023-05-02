import Foundation
import Combine
import HdWalletKit
import BigInt
import HsCryptoKit
import HsToolKit

public class Kit {
    private let syncer: Syncer
    private let accountInfoManager: AccountInfoManager
    private let transactionManager: TransactionManager

    public let address: Address
    public let network: Network
    public let uniqueId: String
    public let logger: Logger


    init(address: Address, network: Network, uniqueId: String, syncer: Syncer, accountInfoManager: AccountInfoManager, transactionManager: TransactionManager, logger: Logger) {
        self.address = address
        self.network = network
        self.uniqueId = uniqueId
        self.accountInfoManager = accountInfoManager
        self.transactionManager = transactionManager
        self.syncer = syncer
        self.logger = logger
    }

}

// Public API Extension

extension Kit {

    public var lastBlockHeight: Int? {
        syncer.lastBlockHeight
    }

    public var syncState: SyncState {
        syncer.state
    }

    public var trxBalance: BigUInt {
        accountInfoManager.trxBalance
    }

    public var receiveAddress: Address {
        address
    }

    public var lastBlockHeightPublisher: AnyPublisher<Int, Never> {
        syncer.$lastBlockHeight.eraseToAnyPublisher()
    }

    public var syncStatePublisher: AnyPublisher<SyncState, Never> {
        syncer.$state.eraseToAnyPublisher()
    }

    public var trxBalancePublisher: AnyPublisher<BigUInt, Never> {
        accountInfoManager.trxBalancePublisher
    }

    public var allTransactionsPublisher: AnyPublisher<([FullTransaction], Bool), Never> {
        Just(([], true)).eraseToAnyPublisher()
    }

    public func start() {
        syncer.start()
    }

    public func stop() {
        syncer.stop()
    }

    public func refresh() {
        syncer.refresh()
    }

    public func fetchTransaction(hash: Data) async throws -> FullTransaction {
        throw SyncError.notStarted
    }

}

extension Kit {

    public static func clear(exceptFor excludedFiles: [String]) throws {
        let fileManager = FileManager.default
        let fileUrls = try fileManager.contentsOfDirectory(at: dataDirectoryUrl(), includingPropertiesForKeys: nil)

        for filename in fileUrls {
            if !excludedFiles.contains(where: { filename.lastPathComponent.contains($0) }) {
                try fileManager.removeItem(at: filename)
            }
        }
    }

    public static func instance(address: Address, network: Network, walletId: String, minLogLevel: Logger.Level = .error) throws -> Kit {
        let logger = Logger(minLogLevel: minLogLevel)
        let uniqueId = "\(walletId)-\(network.id)"

        let networkManager = NetworkManager(logger: logger)
        let reachabilityManager = ReachabilityManager()
        let databaseDirectoryUrl = try dataDirectoryUrl()
        let syncerStateStorage = SyncerStateStorage(databaseDirectoryUrl: databaseDirectoryUrl, databaseFileName: "syncer-state-storage")
        let accountInfoStorage = AccountInfoStorage(databaseDirectoryUrl: databaseDirectoryUrl, databaseFileName: "account-info-storage")

        let accountInfoManager = AccountInfoManager(storage: accountInfoStorage)
        let transactionManager = TransactionManager()

        let tronGridProvider = TronGridProvider(networkManager: networkManager, baseUrl: "https://api.trongrid.io/", auth: nil)
        let syncTimer = SyncTimer(reachabilityManager: reachabilityManager, syncInterval: 15)
        let syncer = Syncer(accountInfoManager: accountInfoManager, transactionManager: transactionManager, syncTimer: syncTimer, tronGridProvider: tronGridProvider, storage: syncerStateStorage, address: address)

        let kit = Kit(
            address: address, network: network, uniqueId: uniqueId,
            syncer: syncer,
            accountInfoManager: accountInfoManager,
            transactionManager: transactionManager,
            logger: logger
        )

        return kit
    }

    private static func dataDirectoryUrl() throws -> URL {
        let fileManager = FileManager.default

        let url = try fileManager
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("tron-kit", isDirectory: true)

        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)

        return url
    }

}

extension Kit {

    public enum SyncError: Error {
        case notStarted
        case noNetworkConnection
    }

}
