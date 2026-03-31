import BigInt
import Foundation
import SwiftProtobuf

class FeeProvider {
    private let rpcApiProvider: IRpcApiProvider
    private let nodeApiProvider: INodeApiProvider
    private let chainParameterManager: ChainParameterManager

    init(rpcApiProvider: IRpcApiProvider, nodeApiProvider: INodeApiProvider, chainParameterManager: ChainParameterManager) {
        self.rpcApiProvider = rpcApiProvider
        self.nodeApiProvider = nodeApiProvider
        self.chainParameterManager = chainParameterManager
    }

    private func feesForAccountActivation() -> [Fee] {
        [
            .bandwidth(points: chainParameterManager.сreateAccountFee / chainParameterManager.transactionFee, price: chainParameterManager.transactionFee),
            .accountActivation(amount: chainParameterManager.сreateNewAccountFeeInSystemContract),
        ]
    }

    func isAccountActive(address: Address) async throws -> Bool {
        return try await nodeApiProvider.fetchAccount(address: address.base58) != nil
    }
}

extension FeeProvider {
    func estimateFee(contract: Contract) async throws -> [Fee] {
        var fees = [Fee]()
        var feeLimit: Int64 = 0

        switch contract {
        case let contract as TransferContract:
            if try await !isAccountActive(address: contract.toAddress) {
                return feesForAccountActivation()
            }

        case let contract as TransferAssetContract:
            if try await !isAccountActive(address: contract.toAddress) {
                return feesForAccountActivation()
            }

        case let contract as TriggerSmartContract:
            let energyPrice = chainParameterManager.energyFee
            let energyRequired = try await rpcApiProvider.fetch(
                rpc: EstimateGasJsonRpc(
                    from: contract.ownerAddress,
                    to: contract.contractAddress,
                    amount: contract.callValue.flatMap { BigUInt($0) },
                    gasPrice: 1,
                    data: contract.data.hs.hexData!
                )
            )

            feeLimit = Int64(energyRequired * energyPrice)
            fees.append(.energy(required: energyRequired, price: energyPrice))

        default: throw FeeProvider.FeeError.notSupportedContract
        }

        guard let supportedContract = contract as? SupportedContract else {
            throw FeeProvider.FeeError.notSupportedContract
        }

        var contractMessage = Protocol_Transaction.Contract()
        contractMessage.parameter = try Google_Protobuf_Any(message: supportedContract.protoMessage)
        contractMessage.type = supportedContract.protoContractType

        let currentTime = Int64(Date().timeIntervalSince1970 * 1000)
        var rawData = Protocol_Transaction.raw()
        rawData.contract = [contractMessage]
        rawData.refBlockBytes = Data(repeating: 0, count: 2)
        rawData.refBlockHash = Data(repeating: 0, count: 8)
        rawData.expiration = currentTime
        rawData.timestamp = currentTime
        rawData.feeLimit = feeLimit

        var transaction = Protocol_Transaction()
        transaction.rawData = rawData
        transaction.signature = [Data(repeating: 0, count: 65)]

        let bandwidthPoints = try transaction.serializedData().count + 64
        let bandwidthPointPrice = chainParameterManager.transactionFee
        fees.append(.bandwidth(points: bandwidthPoints, price: bandwidthPointPrice))

        return fees
    }
}

extension FeeProvider {
    enum FeeError: Error {
        case notSupportedContract
    }
}

public enum Fee {
    case bandwidth(points: Int, price: Int)
    case energy(required: Int, price: Int)
    case accountActivation(amount: Int)
}
