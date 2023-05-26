import Foundation
import BigInt
import ObjectMapper

struct Trc20TransactionResponse: ImmutableMappable {
    let transactionId: Data
    let tokenInfo: TokenInfo
    let blockTimestamp: Int
    let from: Address
    let to: Address
    let type: String
    let value: BigUInt

    public init(map: Map) throws {
        transactionId = try map.value("transaction_id", using: HexDataTransform())
        tokenInfo = try map.value("token_info")
        blockTimestamp = try map.value("block_timestamp")
        from = try map.value("from", using: StringAddressTransform())
        to = try map.value("to", using: StringAddressTransform())
        type = try map.value("type")
        value = try map.value("value", using: StringBigUIntTransform())
    }
}

extension Trc20TransactionResponse {

    struct TokenInfo: ImmutableMappable {
        let symbol: String
        let address: Address
        let decimals: Int
        let name: String

        public init(map: Map) throws {
            symbol = try map.value("symbol")
            address = try map.value("address", using: StringAddressTransform())
            decimals = try map.value("decimals")
            name = try map.value("name")
        }
    }

}
