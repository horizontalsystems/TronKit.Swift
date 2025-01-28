import Foundation
import ObjectMapper

public struct CreatedTransactionResponse: ImmutableMappable {
    public let txID: Data
    public let rawData: TransactionResponse.RawData
    public let rawDataHex: Data

    public init(map: Map) throws {
        txID = try map.value("txID", using: HexDataTransform())
        rawData = try map.value("raw_data")
        rawDataHex = try map.value("raw_data_hex", using: HexDataTransform())
    }
}
