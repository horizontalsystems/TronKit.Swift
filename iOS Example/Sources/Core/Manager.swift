import Foundation
import HdWalletKit
import TronKit

class Manager {
    static let shared = Manager()

    private let keyWords = "mnemonic_words"
    private let keyAddress = "address"

    var tronKit: Kit!
    var signer: Signer!
    var adapter: TrxAdapter!

    init() {
        if let words = savedWords {
            try? initKit(words: words)
        } else if let address = savedAddress {
            try? initKit(address: address)
        }
    }

    private func initKit(address: Address, configuration: Configuration, signer: Signer?) throws {
        let TronKit = try Kit.instance(
            address: address,
            network: configuration.network,
            walletId: "walletId",
            apiKey: nil,
            minLogLevel: configuration.minLogLevel
        )

        adapter = TrxAdapter(TronKit: TronKit, signer: signer)

        tronKit = TronKit
        self.signer = signer

        TronKit.start()
    }

    private func initKit(words: [String]) throws {
        let configuration = Configuration.shared

        guard let seed = Mnemonic.seed(mnemonic: words) else {
            throw LoginError.seedGenerationFailed
        }

        let signer = try Signer.instance(seed: seed)

        try initKit(
            address: Signer.address(seed: seed),
            configuration: configuration,
            signer: signer
        )
    }

    private func initKit(address: Address) throws {
        let configuration = Configuration.shared

        try initKit(address: address, configuration: configuration, signer: nil)
    }

    private var savedWords: [String]? {
        guard let wordsString = UserDefaults.standard.value(forKey: keyWords) as? String else {
            return nil
        }

        return wordsString.split(separator: " ").map(String.init)
    }

    private var savedAddress: Address? {
        guard let addressString = UserDefaults.standard.value(forKey: keyAddress) as? String else {
            return nil
        }

        return try? Address(address: addressString)
    }

    private func save(words: [String]) {
        UserDefaults.standard.set(words.joined(separator: " "), forKey: keyWords)
        UserDefaults.standard.synchronize()
    }

    private func save(address: String) {
        UserDefaults.standard.set(address, forKey: keyAddress)
        UserDefaults.standard.synchronize()
    }

    private func clearStorage() {
        UserDefaults.standard.removeObject(forKey: keyWords)
        UserDefaults.standard.removeObject(forKey: keyAddress)
        UserDefaults.standard.synchronize()
    }
}

extension Manager {
    func login(words: [String]) throws {
        try Kit.clear(exceptFor: ["walletId"])

        save(words: words)
        try initKit(words: words)
    }

    func watch(address: Address) throws {
        try Kit.clear(exceptFor: ["walletId"])

        save(address: address.base58)
        try initKit(address: address)
    }

    func logout() {
        clearStorage()

        signer = nil
        tronKit = nil
        adapter = nil
    }
}

extension Manager {
    enum LoginError: Error {
        case seedGenerationFailed
    }
}
