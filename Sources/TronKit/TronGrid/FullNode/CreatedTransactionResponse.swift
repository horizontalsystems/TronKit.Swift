import Foundation
import ObjectMapper

struct CreatedTransactionResponse: ImmutableMappable {
    let txID: Data
    let rawData: TransactionResponse.RawData
    let rawDataHex: Data

    public init(map: Map) throws {
        txID = try map.value("txID", using: HexDataTransform())
        rawData = try map.value("raw_data")
        rawDataHex = try map.value("raw_data_hex", using: HexDataTransform())
    }
}
