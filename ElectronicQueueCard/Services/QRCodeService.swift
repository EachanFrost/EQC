import UIKit
import CoreImage.CIFilterBuiltins

/// 离线生成 / 解析玩家二维码。二维码内容格式：`paiqi:<qrSecret>`。
enum QRCodeService {
    static let payloadPrefix = "paiqi:"

    static func payload(for secret: String) -> String {
        return payloadPrefix + secret
    }

    static func secret(fromPayload payload: String) -> String? {
        guard payload.hasPrefix(payloadPrefix) else { return nil }
        let secret = String(payload.dropFirst(payloadPrefix.count))
        return secret.isEmpty ? nil : secret
    }

    static func generate(from string: String, scale: CGFloat = 12) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
