class ChainParameterManager {
    private let nodeApiProvider: INodeApiProvider
    private let storage: SyncerStorage

    init(nodeApiProvider: INodeApiProvider, storage: SyncerStorage) {
        self.nodeApiProvider = nodeApiProvider
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
        storage.chainParameter(key: "getTransactionFee") ?? 1000
    }

    var energyFee: Int {
        storage.chainParameter(key: "getEnergyFee") ?? 420
    }

    func sync() async throws {
        let parameters = try await nodeApiProvider.fetchChainParameters()
        for parameter in parameters {
            storage.saveChainParameter(key: parameter.key, value: parameter.value)
        }
    }
}
