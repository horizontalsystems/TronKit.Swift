import HsCryptoKit
import BigInt
import Foundation
import HsExtensions

public class ContractMethodHelper {

    public struct DynamicStructParameter {
        let arguments: [Any]

        public init(_ arguments: [Any]) {
            self.arguments = arguments
        }
    }

    public struct StaticStructParameter {
        let arguments: [Any]

        public init(_ arguments: [Any]) {
            self.arguments = arguments
        }
    }

    public static func encodedABI(methodId: Data, arguments: [Any]) -> Data {
        var data = methodId
        var arraysData = Data()

        for argument in arguments {
            switch argument {
                case let argument as BigUInt:
                    data += pad(data: argument.serialize())
                case let argument as String:
                    data += pad(data: argument.hs.hexData ?? Data())
                case let argument as Address:
                    data += pad(data: argument.raw.suffix(from: 1))
                case let argument as [Address]:
                    data += pad(data: BigUInt(arguments.count * 32 + arraysData.count).serialize())
                    arraysData += encode(array: argument.map { $0.raw })
                case let argument as Data:
                    data += pad(data: BigUInt(arguments.count * 32 + arraysData.count).serialize())
                    arraysData += pad(data: BigUInt(argument.count).serialize()) + argument
                default:
                    ()
            }
        }

        return data + arraysData
    }

    public class func decodeABI(inputArguments: Data, argumentTypes: [Any]) throws -> [Any] {
        var position = 0
        var parsedArguments = [Any]()

        for type in argumentTypes {
            switch type {
                case is BigUInt.Type:
                    let data = Data(inputArguments[position..<position + 32])
                    parsedArguments.append(BigUInt(data))
                    position += 32

                case is [BigUInt].Type:
                    let arrayPosition = parseInt(data: inputArguments[position..<position + 32])
                    let array: [BigUInt] = parseBigUInt(startPosition: arrayPosition, inputArguments: inputArguments)
                    parsedArguments.append(array)
                    position += 32

                case is Address.Type:
                    let data = Data(inputArguments[position..<position + 32])
                    parsedArguments.append(try Address(raw: data))
                    position += 32

                case is [Address].Type:
                    let arrayPosition = parseInt(data: inputArguments[position..<position + 32])
                    let array: [Address] = try parseAddresses(startPosition: arrayPosition, inputArguments: inputArguments)
                    parsedArguments.append(array)
                    position += 32

                case is Data.Type:
                    let dataPosition = parseInt(data: inputArguments[position..<position + 32])
                    let data: Data = parseData(startPosition: dataPosition, inputArguments: inputArguments)
                    parsedArguments.append(data)
                    position += 32

                case is [Data].Type:
                    let dataPosition = parseInt(data: inputArguments[position..<position + 32])
                    let data: [Data] = parseDataArray(startPosition: dataPosition, inputArguments: inputArguments)
                    parsedArguments.append(data)
                    position += 32

                case let object as DynamicStructParameter:
                    let argumentsPosition = parseInt(data: inputArguments[position..<position + 32])
                    let data: [Any] = try decodeABI(inputArguments: Data(inputArguments[argumentsPosition..<inputArguments.count]), argumentTypes: object.arguments)
                    parsedArguments.append(data)
                    position += 32

                case let object as StaticStructParameter:
                    let data: [Any] = try decodeABI(inputArguments: Data(inputArguments[position..<inputArguments.count]), argumentTypes: object.arguments)
                    parsedArguments.append(data)
                    position += 32 * object.arguments.count

                default: ()
            }
        }

        return parsedArguments
    }

    public static func methodId(signature: String) -> Data {
        Crypto.sha3(signature.data(using: .ascii)!)[0...3]
    }

    private class func parseInt(data: Data) -> Int {
        Data(data.reversed()).hs.to(type: Int.self)
    }

    private class func parseAddresses(startPosition: Int, inputArguments: Data) throws -> [Address] {
        let arrayStartPosition = startPosition + 32
        let size = parseInt(data: inputArguments[startPosition..<arrayStartPosition])
        var addresses = [Address]()

        for i in 0..<size {
            let addressData = Data(inputArguments[(arrayStartPosition + 32 * i)..<(arrayStartPosition + 32 * (i + 1))])
            addresses.append(try Address(raw: addressData))
        }

        return addresses
    }

    private class func parseBigUInt(startPosition: Int, inputArguments: Data) -> [BigUInt] {
        let arrayStartPosition = startPosition + 32
        let size = parseInt(data: inputArguments[startPosition..<arrayStartPosition])
        var bigUInts = [BigUInt]()

        for i in 0..<size {
            let bigUIntData = Data(inputArguments[(arrayStartPosition + 32 * i)..<(arrayStartPosition + 32 * (i + 1))])
            bigUInts.append(BigUInt(bigUIntData))
        }

        return bigUInts
    }

    private class func parseData(startPosition: Int, inputArguments: Data) -> Data {
        let dataStartPosition = startPosition + 32
        let size = parseInt(data: inputArguments[startPosition..<dataStartPosition])
        return Data(inputArguments[dataStartPosition..<(dataStartPosition + size)])
    }

    private class func parseDataArray(startPosition: Int, inputArguments: Data) -> [Data] {
        let arrayStartPosition = startPosition + 32
        let size = parseInt(data: inputArguments[startPosition..<arrayStartPosition])
        var dataArray = [Data]()

        for i in 0..<size {
            dataArray.append(Data(inputArguments[(arrayStartPosition + 32 * i)..<(arrayStartPosition + 32 * (i + 1))]))
        }

        return dataArray
    }

    private static func encode(array: [Data]) -> Data {
        var data = pad(data: BigUInt(array.count).serialize())

        for item in array {
            data += pad(data: item)
        }

        return data
    }

    private static func pad(data: Data) -> Data {
        Data(repeating: 0, count: (max(0, 32 - data.count))) + data
    }

}
