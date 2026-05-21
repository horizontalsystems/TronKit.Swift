import Foundation
import ObjectMapper

public struct CreatedTransactionResponse: ImmutableMappable {
    let rawData: TransactionResponse.RawData
    public let visible: Bool?
    public let txID: Data
    public let rawDataMap: [String: Any]
    public let rawDataHex: Data

    public init(map: Map) throws {
        visible = (try? map.value("visible")) ?? false
        txID = try map.value("txID", using: HexDataTransform())
        rawData = try map.value("raw_data")
        rawDataMap = try map.value("raw_data")
        rawDataHex = try map.value("raw_data_hex", using: HexDataTransform())
    }
}
