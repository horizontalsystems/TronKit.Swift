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
    private let transactionSender: TransactionSender
    private let feeProvider: FeeProvider

    public let address: Address
    public let network: Network
    public let uniqueId: String
    public let logger: Logger


    init(address: Address, network: Network, uniqueId: String, syncer: Syncer, accountInfoManager: AccountInfoManager, transactionManager: TransactionManager, transactionSender: TransactionSender, feeProvider: FeeProvider, logger: Logger) {
        self.address = address
        self.network = network
        self.uniqueId = uniqueId
        self.accountInfoManager = accountInfoManager
        self.transactionManager = transactionManager
        self.transactionSender = transactionSender
        self.syncer = syncer
        self.feeProvider = feeProvider
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

    public var accountActive: Bool {
        accountInfoManager.accountActive
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
        transactionManager.fullTransactionsPublisher
    }

    public func trc20Balance(contractAddress: Address) -> BigUInt {
        accountInfoManager.trc20Balance(contractAddress: contractAddress)
    }

    public func trc20BalancePublisher(contractAddress: Address) -> AnyPublisher<BigUInt, Never> {
        accountInfoManager.trc20BalancePublisher(contractAddress: contractAddress)
    }

    public func transactionsPublisher(tagQueries: [TransactionTagQuery]) -> AnyPublisher<[FullTransaction], Never> {
        transactionManager.fullTransactionsPublisher(tagQueries: tagQueries)
    }

    public func transactions(tagQueries: [TransactionTagQuery], fromHash: Data? = nil, limit: Int? = nil) -> [FullTransaction] {
        transactionManager.fullTransactions(tagQueries: tagQueries, fromHash: fromHash, limit: limit)
    }

    public func estimateFee(contract: Contract) async throws -> [Fee] {
        try await feeProvider.estimateFee(contract: contract)
    }

    public func decorate(contract: Contract) -> TransactionDecoration? {
        transactionManager.decorate(contract: contract)
    }

    public func transferContract(toAddress: Address, value: Int) -> TransferContract {
        TransferContract(amount: value, ownerAddress: address, toAddress: toAddress)
    }

    public func transferTrc20TriggerSmartContract(contractAddress: Address, toAddress: Address, amount: BigUInt) -> TriggerSmartContract {
        let transferMethod = TransferMethod(to: toAddress, value: amount)
        let data = transferMethod.encodedABI().hs.hex
        let parameter = ContractMethodHelper.encodedABI(methodId: Data(), arguments: transferMethod.arguments).hs.hex

        return TriggerSmartContract(
            data: data,
            ownerAddress: address,
            contractAddress: contractAddress,
            callValue: nil,
            callTokenValue: nil,
            tokenId: nil,
            functionSelector: TransferMethod.methodSignature,
            parameter: parameter
        )
    }

    public func send(contract: Contract, signer: Signer, feeLimit: Int? = 0) async throws  {
        let newTransaction = try await transactionSender.sendTransaction(contract: contract, signer: signer, feeLimit: feeLimit)
        transactionManager.handle(newTransaction: newTransaction)
    }

    public func accountActive(address: Address) async throws -> Bool {
        try await feeProvider.isAccountActive(address: address)
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

    public static func instance(address: Address, network: Network, walletId: String, apiKey: String?, minLogLevel: Logger.Level = .error) throws -> Kit {
        let logger = Logger(minLogLevel: minLogLevel)
        let uniqueId = "\(walletId)-\(network.rawValue)"

        let networkManager = NetworkManager(logger: logger)
        let reachabilityManager = ReachabilityManager()
        let databaseDirectoryUrl = try dataDirectoryUrl()
        let syncerStorage = SyncerStorage(databaseDirectoryUrl: databaseDirectoryUrl, databaseFileName: "syncer-state-storage-\(uniqueId)")
        let accountInfoStorage = AccountInfoStorage(databaseDirectoryUrl: databaseDirectoryUrl, databaseFileName: "account-info-storage-\(uniqueId)")
        let transactionStorage = TransactionStorage(databaseDirectoryUrl: databaseDirectoryUrl, databaseFileName: "transactions-storage-\(uniqueId)")

        let accountInfoManager = AccountInfoManager(storage: accountInfoStorage)
        let decorationManager = DecorationManager(userAddress: address, storage: transactionStorage)
        let transactionManager = TransactionManager(userAddress: address, storage: transactionStorage, decorationManager: decorationManager)

        let tronGridProvider = TronGridProvider(networkManager: networkManager, baseUrl: providerUrl(network: network), apiKey: apiKey)
        let chainParameterManager = ChainParameterManager(tronGridProvider: tronGridProvider, storage: syncerStorage)
        let feeProvider = FeeProvider(tronGridProvider: tronGridProvider, chainParameterManager: chainParameterManager)

        let syncTimer = SyncTimer(reachabilityManager: reachabilityManager, syncInterval: 30)
        let syncer = Syncer(accountInfoManager: accountInfoManager, transactionManager: transactionManager, chainParameterManager: chainParameterManager, syncTimer: syncTimer, tronGridProvider: tronGridProvider, storage: syncerStorage, address: address)
        let transactionSender = TransactionSender(tronGridProvider: tronGridProvider)

        let kit = Kit(
            address: address, network: network, uniqueId: uniqueId,
            syncer: syncer,
            accountInfoManager: accountInfoManager,
            transactionManager: transactionManager,
            transactionSender: transactionSender,
            feeProvider: feeProvider,
            logger: logger
        )

        decorationManager.add(transactionDecorator: Trc20TransactionDecorator(address: address))

        return kit
    }

    public static func call(networkManager: NetworkManager, network: Network, contractAddress: Address, data: Data, apiKey: String?) async throws -> Data {
        let tronGridProvider = TronGridProvider(networkManager: networkManager, baseUrl: providerUrl(network: network), apiKey: apiKey)
        let rpc = CallJsonRpc(contractAddress: contractAddress, data: data)

        return try await tronGridProvider.fetch(rpc: rpc)
    }

    private static func dataDirectoryUrl() throws -> URL {
        let fileManager = FileManager.default

        let url = try fileManager
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("tron-kit", isDirectory: true)

        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)

        return url
    }

    private static func providerUrl(network: Network) -> String {
        switch network {
            case .mainNet: return "https://api.trongrid.io/"
            case .nileTestnet: return "https://nile.trongrid.io/"
            case .shastaTestnet: return "https://api.shasta.trongrid.io/"
        }
    }

}

extension Kit {

    public enum SyncError: Error {
        case notStarted
        case noNetworkConnection
    }

    public enum SendError: Error {
        case notSupportedContract
        case abnormalSend
        case invalidParameter
    }

}
