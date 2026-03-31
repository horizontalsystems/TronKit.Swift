import Foundation
import ObjectMapper

struct ChainParameterResponse: ImmutableMappable {
    let key: String
    let value: Int?

    init(map: Map) throws {
        key = try map.value("key")
        value = try map.value("value")
    }
}
