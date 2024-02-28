import BigInt
import Foundation
import ObjectMapper

struct AccountInfoResponse: ImmutableMappable {
    let balance: Int
    let trc20: [Address: BigUInt]

    public init(map: Map) throws {
        balance = (try? map.value("balance")) ?? 0

        var trc20 = [Address: BigUInt]()
        if let trc20Balances = map["trc20"].currentValue as? [[String: String]] {
            for balance in trc20Balances {
                if let key = balance.keys.first, let value = balance.values.first,
                   let address = try? Address(address: key),
                   let bigUintValue = BigUInt(value, radix: 10)
                {
                    trc20[address] = bigUintValue
                }
            }
        }

        self.trc20 = trc20
    }
}
