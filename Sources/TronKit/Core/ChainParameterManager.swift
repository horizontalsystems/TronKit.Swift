class ChainParameterManager {
    private let tronGridProvider: TronGridProvider
    private let storage: SyncerStorage

    init(tronGridProvider: TronGridProvider, storage: SyncerStorage) {
        self.tronGridProvider = tronGridProvider
        self.storage = storage
    }

}

extension ChainParameterManager {

    var сreateNewAccountFeeInSystemContract: Int {
        storage.chainParameter(key: "getCreateNewAccountFeeInSystemContract") ?? 1_000_000
    }

    var сreateAccountFee: Int {
        storage.chainParameter(key: "getCreateAccountFee") ?? 100_000
    }

    var transactionFee: Int {
        storage.chainParameter(key: "getTransactionFee") ?? 1_000
    }

    var energyFee: Int {
        storage.chainParameter(key: "getEnergyFee") ?? 420
    }

    func sync() async throws {
        let parameters = try await tronGridProvider.fetchChainParameters()
        for parameter in parameters {
            storage.saveChainParameter(key: parameter.key, value: parameter.value)
        }
    }

}
