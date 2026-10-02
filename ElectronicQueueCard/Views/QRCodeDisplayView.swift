import SwiftUI

/// 展示玩家专属二维码，提示拍照保存。
struct QRCodeDisplayView: View {
    let player: Player
    let recovered: Bool
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(recovered ? "已找回你的账号二维码" : "注册成功")
                    .font(.title2.bold())
                if let img = QRCodeService.generate(from: QRCodeService.payload(for: player.qrSecret)) {
                    Image(uiImage: img)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 300, height: 300)
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(12)
                }
                Text(player.nickname).font(.headline)
                Text("请用手机拍照保存此二维码。下次排队时，出示给屏幕摄像头扫码即可登录。")
                    .font(.footnote).foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Button("完成") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }
}
