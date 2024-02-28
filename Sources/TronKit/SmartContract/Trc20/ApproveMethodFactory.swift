import BigInt
import Foundation

class ApproveMethodFactory: IContractMethodFactory {
    let methodId: Data = ContractMethodHelper.methodId(signature: ApproveMethod.methodSignature)

    func createMethod(inputArguments: Data) throws -> ContractMethod {
        let spender = try Address(raw: inputArguments[12 ..< 32])
        let value = BigUInt(inputArguments[32 ..< 64])

        return ApproveMethod(spender: spender, value: value)
    }
}
