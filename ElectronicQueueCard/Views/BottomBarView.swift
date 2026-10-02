import SwiftUI

struct BottomBarView: View {
    let loginAction: () -> Void
    let guestAction: () -> Void
    let registerAction: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: loginAction) { item("扫码登录", systemImage: "qrcode.viewfinder") }
            Button(action: guestAction) { item("游客排队", systemImage: "person.crop.circle.badge.plus") }
            Button(action: registerAction) { item("账号注册", systemImage: "person.badge.plus") }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
    }

    private func item(_ title: String, systemImage: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage).font(.title2)
            Text(title).font(.subheadline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
}
