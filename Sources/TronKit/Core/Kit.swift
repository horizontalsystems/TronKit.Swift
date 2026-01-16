import BigInt
import Combine
import Foundation
import HdWalletKit
import HsCryptoKit
import HsToolKit

public class Kit {
    private let syncer: Syncer
    private let accountInfoManager: AccountInfoManager
    private let allowanceManager: AllowanceManager
    private let transactionManager: TransactionManager
    private let transactionSender: TransactionSender
    private let feeProvider: FeeProvider

    public let address: Address
    public let network: Network
    public let uniqueId: String
    public let logger: Logger

    init(address: Address, network: Network, uniqueId: String, syncer: Syncer, accountInfoManager: AccountInfoManager, allowanceManager: AllowanceManager, transactionManager: TransactionManager, transactionSender: TransactionSender, feeProvider: FeeProvider, logger: Logger) {
        self.address = address
        self.network = network
        self.uniqueId = uniqueId
        self.accountInfoManager = accountInfoManager
        self.allowanceManager = allowanceManager
        self.transactionManager = transactionManager
        self.transactionSender = transactionSender
        self.syncer = syncer
        self.feeProvider = feeProvider
        self.logger = logger
    }
}

// Public API Extension

public extension Kit {
    var lastBlockHeight: Int? {
        syncer.lastBlockHeight
    }

    var syncState: SyncState {
        syncer.state
    }

    var accountActive: Bool {
        accountInfoManager.accountActive
    }

    var trxBalance: BigUInt {
        accountInfoManager.trxBalance
    }

    var receiveAddress: Address {
        address
    }

    var lastBlockHeightPublisher: AnyPublisher<Int, Never> {
        syncer.$lastBlockHeight.eraseToAnyPublisher()
    }

    var syncStatePublisher: AnyPublisher<SyncState, Never> {
        syncer.$state.eraseToAnyPublisher()
    }

    var trxBalancePublisher: AnyPublisher<BigUInt, Never> {
        accountInfoManager.trxBalancePublisher
    }

    var accountActivePublisher: AnyPublisher<Bool, Never> {
        accountInfoManager.accountActivePublisher
    }

    var allTransactionsPublisher: AnyPublisher<([FullTransaction], Bool), Never> {
        transactionManager.fullTransactionsPublisher
    }

    func trc20Balance(contractAddress: Address) -> BigUInt {
        accountInfoManager.trc20Balance(contractAddress: contractAddress)
    }

    func trc20BalancePublisher(contractAddress: Address) -> AnyPublisher<BigUInt, Never> {
        accountInfoManager.trc20BalancePublisher(contractAddress: contractAddress)
    }

    func transactionsPublisher(tagQueries: [TransactionTagQuery]) -> AnyPublisher<[FullTransaction], Never> {
        transactionManager.fullTransactionsPublisher(tagQueries: tagQueries)
    }

    func transactions(tagQueries: [TransactionTagQuery], hash: Data? = nil, descending: Bool, limit: Int? = nil) -> [FullTransaction] {
        transactionManager.fullTransactions(tagQueries: tagQueries, hash: hash, descending: descending, limit: limit)
    }

    func pendingTransactions() -> [FullTransaction] {
        transactionManager.pendingTransaction()
    }

    func estimateFee(contract: Contract) async throws -> [Fee] {
        try await feeProvider.estimateFee(contract: contract)
    }

    func estimateFee(createdTransaction: CreatedTransactionResponse) async throws -> [Fee] {
        guard let contract = try TriggerSmartContract.parse(contract: createdTransaction.rawData.contract) else {
            throw SendError.notSupportedContract
        }

        return try await estimateFee(contract: contract)
    }

    func decorate(contract: Contract) -> TransactionDecoration? {
        transactionManager.decorate(contract: contract)
    }

    func allowance(contractAddress: Address, spenderAddress: Address) async throws -> String {
        try await allowanceManager.allowance(contractAddress: contractAddress, spenderAddress: spenderAddress).description
    }

    func transferContract(toAddress: Address, value: Int) -> TransferContract {
        TransferContract(amount: value, ownerAddress: address, toAddress: toAddress)
    }

    func transferTrc20TriggerSmartContract(contractAddress: Address, toAddress: Address, amount: BigUInt) -> TriggerSmartContract {
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

    func approveTrc20TriggerSmartContract(contractAddress: Address, spender: Address, amount: BigUInt) -> TriggerSmartContract {
        let approveMethod = ApproveMethod(spender: spender, value: amount)
        let data = approveMethod.encodedABI().hs.hex
        let parameter = ContractMethodHelper.encodedABI(methodId: Data(), arguments: approveMethod.arguments).hs.hex

        return TriggerSmartContract(
            data: data,
            ownerAddress: address,
            contractAddress: contractAddress,
            callValue: nil,
            callTokenValue: nil,
            tokenId: nil,
            functionSelector: ApproveMethod.methodSignature,
            parameter: parameter
        )
    }

    func tagTokens() -> [TagToken] {
        transactionManager.tagTokens()
    }

    func send(contract: Contract, signer: Signer, feeLimit: Int? = 0) async throws {
        let newTransaction = try await transactionSender.sendTransaction(contract: contract, signer: signer, feeLimit: feeLimit)
        transactionManager.handle(newTransaction: newTransaction)
    }

    func send(createdTransaction: CreatedTransactionResponse, signer: Signer) async throws {
        try await transactionSender.broadcastTransaction(createdTransaction: createdTransaction, signer: signer)
        transactionManager.handle(newTransaction: createdTransaction)
    }

    func accountActive(address: Address) async throws -> Bool {
        try await feeProvider.isAccountActive(address: address)
    }

    func start() {
        syncer.start()
    }

    func stop() {
        syncer.stop()
    }

    func refresh() {
        syncer.refresh()
    }

    func fetchTransaction(hash _: Data) async throws -> FullTransaction {
        throw SyncError.notStarted
    }
}

public extension Kit {
    static func clear(exceptFor excludedFiles: [String]) throws {
        let fileManager = FileManager.default
        let fileUrls = try fileManager.contentsOfDirectory(at: dataDirectoryUrl(), includingPropertiesForKeys: nil)

        for filename in fileUrls {
            if !excludedFiles.contains(where: { filename.lastPathComponent.contains($0) }) {
                try fileManager.removeItem(at: filename)
            }
        }
    }

    static func instance(address: Address, network: Network, walletId: String, apiKey: String?, minLogLevel: Logger.Level = .error) throws -> Kit {
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
        let allowanceManager = AllowanceManager(tronGridProvider: tronGridProvider, address: address)

        let kit = Kit(
            address: address, network: network, uniqueId: uniqueId,
            syncer: syncer,
            accountInfoManager: accountInfoManager,
            allowanceManager: allowanceManager,
            transactionManager: transactionManager,
            transactionSender: transactionSender,
            feeProvider: feeProvider,
            logger: logger
        )

        decorationManager.add(transactionDecorator: Trc20TransactionDecorator(address: address))

        return kit
    }

    static func call(networkManager: NetworkManager, network: Network, contractAddress: Address, data: Data, apiKey: String?) async throws -> Data {
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

public extension Kit {
    enum SyncError: Error {
        case notStarted
        case noNetworkConnection
    }

    enum SendError: Error {
        case notSupportedContract
        case abnormalSend
        case invalidParameter
    }
}
