import Foundation
import ObjectMapper

public struct CreatedTransactionResponse: ImmutableMappable {
    let visible: Bool?
    let txID: Data
    let rawData: TransactionResponse.RawData
    let rawDataHex: Data

    public init(map: Map) throws {
        visible = (try? map.value("visible")) ?? false
        txID = try map.value("txID", using: HexDataTransform())
        rawData = try map.value("raw_data")
        rawDataHex = try map.value("raw_data_hex", using: HexDataTransform())
    }
}
