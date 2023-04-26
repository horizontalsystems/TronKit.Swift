import TronKit
import HsToolKit

class Configuration {
    static let shared = Configuration()

    let network: Network = .shastaTestnet
    let minLogLevel: Logger.Level = .error

    let defaultsWords = "hollow mechanic fortune usual gallery bird test spoil system scissors public trim"
    let defaultsWatchAddress = "TNeQ7jLVzXUB9kXVurzN9ZQibLaykov5v2"
}
