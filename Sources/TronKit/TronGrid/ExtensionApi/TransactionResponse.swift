import Foundation
import BigInt
import ObjectMapper

struct TransactionResponse: ImmutableMappable {
    let balance: BigUInt
    let blockTimestamp: Int

    public init(map: Map) throws {
        balance = try map.value("blockNumber", using: StringBigUIntTransform())
        blockTimestamp = try map.value("block_timestamp")
    }
}
