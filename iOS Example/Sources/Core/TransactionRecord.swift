import Foundation
import TronKit

struct TransactionRecord {
    let transactionHash: String
    let transactionHashData: Data
    let timestamp: Int
    let isFailed: Bool

    let blockHeight: Int?

    let decoration: TransactionDecoration
}
