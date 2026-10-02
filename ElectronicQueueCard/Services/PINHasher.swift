import Foundation
import CryptoKit

/// PIN 只存哈希，不存明文。
enum PINHasher {
    static func hash(_ pin: String) -> String {
        let salted = "paiqi-pin::\(pin)::v1"
        let digest = SHA256.hash(data: Data(salted.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
