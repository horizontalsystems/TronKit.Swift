import Foundation
import TronKit

private func shortAddress(address: Address) -> String {
    let str = address.base58
    return "\(str.prefix(2))..\(str.suffix(2))"
}

extension NativeTransactionDecoration: CustomStringConvertible {
    public var description: String {
        var d = "NativeTransactionDecoration"

        switch contract {
        case let transfer as TransferContract:
            d = "\(d) \(Decimal(transfer.amount * 1_000_000).description)TRX (\(shortAddress(address: transfer.ownerAddress)) -> \(shortAddress(address: transfer.toAddress)))"

        case let transfer as TransferAssetContract:
            d = "\(d) \(transfer.amount)\(transfer.assetName) (\(shortAddress(address: transfer.ownerAddress)) -> \(shortAddress(address: transfer.toAddress)))"

        default: ()
        }

        return d
    }
}

extension ApproveEip20Decoration: CustomStringConvertible {
    public var description: String {
        "ApproveEip20Decoration \(value.description) -> \(shortAddress(address: spender))"
    }
}

extension OutgoingEip20Decoration: CustomStringConvertible {
    public var description: String {
        guard let significand = Decimal(string: value.description),
              let tokenInfo
        else {
            return ""
        }

        let d = Decimal(sign: .plus, exponent: -tokenInfo.tokenDecimal, significand: significand)

        return "OutgoingEip20Decoration \(d.description)\(tokenInfo.tokenSymbol) -> \(shortAddress(address: to))"
    }
}
