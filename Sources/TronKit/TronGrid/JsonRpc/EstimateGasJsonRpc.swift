import BigInt
import Foundation

class EstimateGasJsonRpc: IntJsonRpc {
    init(from: Address, to: Address?, amount: BigUInt?, gasPrice: Int, data: Data?) {
        var params: [String: Any] = [
            "from": from.raw.hs.hexString,
        ]

        if let to {
            params["to"] = to.raw.hs.hexString
        }
        if let amount {
            params["value"] = "0x" + (amount == 0 ? "0" : amount.serialize().hs.hex.hs.removeLeadingZeros())
        }
        params["gasPrice"] = "0x" + String(gasPrice, radix: 16).hs.removeLeadingZeros()
        if let data {
            params["data"] = data.hs.hexString
        }

        super.init(
            method: "eth_estimateGas",
            params: [params]
        )
    }
}
