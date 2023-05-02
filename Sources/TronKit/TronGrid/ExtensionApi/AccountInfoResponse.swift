import Foundation
import BigInt
import ObjectMapper

struct AccountInfoResponse: ImmutableMappable {
    let balance: Int

    public init(map: Map) throws {
        balance = try map.value("balance")
    }
}
