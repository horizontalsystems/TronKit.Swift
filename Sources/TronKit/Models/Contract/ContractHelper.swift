import Foundation
import ObjectMapper

struct ContractHelper {

    static func contractsFrom(data: Data) throws -> [Contract] {
        guard let contractsMap = try? JSONSerialization.jsonObject(with: data) else {
            return []
        }

        return try contractsFrom(jsonMap: contractsMap)
    }

    static func contractsFrom(jsonMap: Any?) throws -> [Contract] {
        guard let array = jsonMap as? [[String: Any]] else {
            return []
        }

        return try array.map { rawMap in
            guard let type = rawMap["type"] as? String,
                  let parameter = rawMap["parameter"] as? [String: Any],
                  let valueMap = parameter["value"] as? [String: Any] else {
                return try UnknownContract(object: rawMap)
            }

            let contract: Contract

            do {
                switch type {
                    case AccountCreateContract.type: contract = try AccountCreateContract(JSON: valueMap)
                    case TransferContract.type: contract = try TransferContract(JSON: valueMap)
                    case TransferAssetContract.type: contract = try TransferAssetContract(JSON: valueMap)
                    case VoteWitnessContract.type: contract = try VoteWitnessContract(JSON: valueMap)
                    case WitnessCreateContract.type: contract = try WitnessCreateContract(JSON: valueMap)
                    case AssetIssueContract.type: contract = try AssetIssueContract(JSON: valueMap)
                    case WitnessUpdateContract.type: contract = try WitnessUpdateContract(JSON: valueMap)
                    case ParticipateAssetIssueContract.type: contract = try ParticipateAssetIssueContract(JSON: valueMap)
                    case AccountUpdateContract.type: contract = try AccountUpdateContract(JSON: valueMap)
                    case FreezeBalanceContract.type: contract = try FreezeBalanceContract(JSON: valueMap)
                    case UnfreezeBalanceContract.type: contract = try UnfreezeBalanceContract(JSON: valueMap)
                    case WithdrawBalanceContract.type: contract = try WithdrawBalanceContract(JSON: valueMap)
                    case UnfreezeAssetContract.type: contract = try UnfreezeAssetContract(JSON: valueMap)
                    case UpdateAssetContract.type: contract = try UpdateAssetContract(JSON: valueMap)
                    case ProposalCreateContract.type: contract = try ProposalCreateContract(JSON: valueMap)
                    case ProposalApproveContract.type: contract = try ProposalApproveContract(JSON: valueMap)
                    case ProposalDeleteContract.type: contract = try ProposalDeleteContract(JSON: valueMap)
                    case SetAccountIdContract.type: contract = try SetAccountIdContract(JSON: valueMap)
                    case CreateSmartContract.type: contract = try CreateSmartContract(JSON: valueMap)
                    case TriggerSmartContract.type: contract = try TriggerSmartContract(JSON: valueMap)
                    case UpdateSettingContract.type: contract = try UpdateSettingContract(JSON: valueMap)
                    case ExchangeCreateContract.type: contract = try ExchangeCreateContract(JSON: valueMap)
                    case ExchangeInjectContract.type: contract = try ExchangeInjectContract(JSON: valueMap)
                    case ExchangeWithdrawContract.type: contract = try ExchangeWithdrawContract(JSON: valueMap)
                    case ExchangeTransactionContract.type: contract = try ExchangeTransactionContract(JSON: valueMap)
                    case ClearABIContract.type: contract = try ClearABIContract(JSON: valueMap)
                    case UpdateBrokerageContract.type: contract = try UpdateBrokerageContract(JSON: valueMap)
                    case UpdateEnergyLimitContract.type: contract = try UpdateEnergyLimitContract(JSON: valueMap)
                    case FreezeBalanceV2Contract.type: contract = try FreezeBalanceV2Contract(JSON: valueMap)
                    case UnfreezeBalanceV2Contract.type: contract = try UnfreezeBalanceV2Contract(JSON: valueMap)
                    case WithdrawExpireUnfreezeContract.type: contract = try WithdrawExpireUnfreezeContract(JSON: valueMap)
                    case DelegateResourceContract.type: contract = try DelegateResourceContract(JSON: valueMap)
                    case UnDelegateResourceContract.type: contract = try UnDelegateResourceContract(JSON: valueMap)
                    default: contract = try UnknownContract(object: rawMap)
                }
            } catch {
                contract = try UnknownContract(object: rawMap)
            }

            return contract
        }
    }

}
