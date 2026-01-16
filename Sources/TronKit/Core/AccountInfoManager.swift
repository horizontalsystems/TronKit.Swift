import BigInt
import Combine
import HsExtensions

class AccountInfoManager {
    private let storage: AccountInfoStorage

    init(storage: AccountInfoStorage) {
        self.storage = storage
    }

    private let trxBalanceSubject = PassthroughSubject<BigUInt, Never>()
    private let trc20BalanceSubject = PassthroughSubject<(Address, BigUInt), Never>()

    private let accountActiveSubject = PassthroughSubject<Bool, Never>()

    var trxBalance: BigUInt {
        storage.trxBalance ?? 0
    }

    var accountActive: Bool = true {
        didSet {
            accountActiveSubject.send(accountActive)
        }
    }
}

extension AccountInfoManager {
    var trxBalancePublisher: AnyPublisher<BigUInt, Never> {
        trxBalanceSubject.eraseToAnyPublisher()
    }

    func trc20Balance(contractAddress: Address) -> BigUInt {
        storage.trc20Balance(address: contractAddress.base58) ?? 0
    }

    func trc20BalancePublisher(contractAddress: Address) -> AnyPublisher<BigUInt, Never> {
        trc20BalanceSubject.filter { $0.0 == contractAddress }.map(\.1).eraseToAnyPublisher()
    }

    var accountActivePublisher: AnyPublisher<Bool, Never> {
        accountActiveSubject.eraseToAnyPublisher()
    }

    func handle(accountInfoResponse: AccountInfoResponse) {
        accountActive = true
        let trxBalance = BigUInt(accountInfoResponse.balance)
        storage.save(trxBalance: trxBalance)
        trxBalanceSubject.send(trxBalance)

        storage.clearTrc20Balances()
        for (address, value) in accountInfoResponse.trc20 {
            storage.save(trc20Balance: value, address: address.base58)
            trc20BalanceSubject.send((address, value))
        }
    }

    func handleInactiveAccount() {
        accountActive = false
        trxBalanceSubject.send(BigUInt.zero)
    }
}
