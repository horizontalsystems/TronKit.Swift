import Foundation
import Combine
import HdWalletKit
import BigInt
import HsCryptoKit
import HsToolKit

public class Kit {
    private var cancellables = Set<AnyCancellable>()
    private let lastBlockHeightSubject = PassthroughSubject<Int, Never>()
    private let syncStateSubject = PassthroughSubject<SyncState, Never>()
    private let accountStateSubject = PassthroughSubject<BigUInt, Never>()

    public let address: Address
    public let network: Network
    public let uniqueId: String
    public let logger: Logger


    init(address: Address, network: Network, uniqueId: String, logger: Logger) {
        self.address = address
        self.network = network
        self.uniqueId = uniqueId
        self.logger = logger
    }

}

// Public API Extension

extension Kit {

    public var lastBlockHeight: Int? {
        0
    }

    public var balance: BigUInt {
        BigUInt.zero
    }

    public var syncState: SyncState {
        .synced
    }

    public var transactionsSyncState: SyncState {
        .synced
    }

    public var receiveAddress: Address {
        address
    }

    public var lastBlockHeightPublisher: AnyPublisher<Int, Never> {
        lastBlockHeightSubject.eraseToAnyPublisher()
    }

    public var syncStatePublisher: AnyPublisher<SyncState, Never> {
        syncStateSubject.eraseToAnyPublisher()
    }

    public var transactionsSyncStatePublisher: AnyPublisher<SyncState, Never> {
        Just(.synced).eraseToAnyPublisher()
    }

    public var accountStatePublisher: AnyPublisher<BigUInt, Never> {
        accountStateSubject.eraseToAnyPublisher()
    }

    public var allTransactionsPublisher: AnyPublisher<([FullTransaction], Bool), Never> {
        Just(([], true)).eraseToAnyPublisher()
    }

    public func start() {
    }

    public func stop() {
    }

    public func refresh() {
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

        let kit = Kit(
            address: address, network: network, uniqueId: uniqueId, logger: logger
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
