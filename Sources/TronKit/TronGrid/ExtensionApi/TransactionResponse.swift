import Foundation
import ObjectMapper

protocol ITransactionResponse {
    var blockTimestamp: Int { get }
}

struct TransactionResponse: ImmutableMappable, ITransactionResponse {
    let ret: [Ret]
    let signature: [String]
    let txId: Data
    let netUsage: Int
    let netFee: Int
    let energyUsage: Int
    let blockNumber: Int
    let blockTimestamp: Int
    let energyFee: Int
    let energyUsageTotal: Int
    let rawData: RawData

    public init(map: Map) throws {
        ret = try map.value("ret")
        signature = try map.value("signature")
        txId = try map.value("txID")
        netUsage = try map.value("net_usage")
        netFee = try map.value("net_fee")
        energyUsage = try map.value("energy_usage")
        blockNumber = try map.value("blockNumber")
        blockTimestamp = try map.value("block_timestamp")
        energyFee = try map.value("energy_fee")
        energyUsageTotal = try map.value("energy_usage_total")
        rawData = try map.value("raw_data")
    }

    struct Ret: ImmutableMappable {
        let contractRet: String
        let fee: Int

        public init(map: Map) throws {
            contractRet = try map.value("contractRet")
            fee = try map.value("fee")
        }
    }

    struct RawData: ImmutableMappable {
        let contract: Any?
        let refBlockBytes: String
        let refBlockHash: String
        let expiration: Int
        let feeLimit: Int?
        let timestamp: Int

        public init(map: Map) throws {
            contract = map["contract"].currentValue
            refBlockBytes = try map.value("ref_block_bytes")
            refBlockHash = try map.value("ref_block_hash")
            expiration = try map.value("expiration")
            feeLimit = try map.value("fee_limit")
            timestamp = try map.value("timestamp")
        }
    }

}

struct InternalTransactionResponse: ImmutableMappable, ITransactionResponse {
    let internalTxId: String
    let txId: Data
    let data: InternalTxData
    let blockTimestamp: Int
    let toAddress: Address
    let fromAddress: Address

    init(map: ObjectMapper.Map) throws {
        internalTxId = try map.value("internal_tx_id")
        txId = try map.value("tx_id")
        data = try map.value("data")
        blockTimestamp = try map.value("block_timestamp")
        toAddress = try map.value("to_address", using: HexAddressTransform())
        fromAddress = try map.value("from_address", using: HexAddressTransform())
    }

    struct InternalTxData: ImmutableMappable {
        let note: String
        let rejected: Bool
        let value: Int

        init(map: ObjectMapper.Map) throws {
            note = try map.value("note")
            rejected = try map.value("rejected")
            value = try map.value("call_value._")
        }
    }
}
