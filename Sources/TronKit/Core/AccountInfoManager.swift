import BigInt
import Combine
import HsExtensions

class AccountInfoManager {
    private let storage: AccountInfoStorage

    init(storage: AccountInfoStorage) {
        self.storage = storage
    }

    private let trxBalanceSubject = PassthroughSubject<BigUInt, Never>()

    var trxBalance: BigUInt {
        storage.trxBalance ?? 0
    }

}

extension AccountInfoManager {

    var trxBalancePublisher: AnyPublisher<BigUInt, Never> {
        trxBalanceSubject.eraseToAnyPublisher()
    }

    func handle(accountInfoResponse: AccountInfoResponse) {
        let trxBalance = BigUInt(accountInfoResponse.balance)
        storage.save(trxBalance: trxBalance)
        trxBalanceSubject.send(trxBalance)
    }

}
