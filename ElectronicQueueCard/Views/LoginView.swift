import SwiftUI
import CoreData

private enum CredentialMode: String, Identifiable {
    case login
    case recover
    var id: String { rawValue }
}

/// 扫码登录：直接进入前置摄像头扫码，旁边提供「昵称登录 / 找回账号」小按钮。
struct LoginView: View {
    @EnvironmentObject var queueManager: QueueManager
    @Environment(\.dismiss) var dismiss

    @State private var credentialMode: CredentialMode?
    @State private var message: String?
    @State private var showMessage = false
    @State private var loggedPlayer: Player?
    @State private var navigateToJoin = false

    var body: some View {
        NavigationView {
            ZStack {
                CameraScannerView(onScan: handleScan)
                    .ignoresSafeArea()

                VStack {
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                                .shadow(radius: 4)
                        }
                    }
                    Spacer()
                    HStack(spacing: 12) {
                        Button { credentialMode = .login } label: { smallButton("昵称登录") }
                        Button { credentialMode = .recover } label: { smallButton("找回账号") }
                    }
                    .padding(.bottom, 28)
                }
                .padding()
            }
            .navigationBarHidden(true)
            .background(
                NavigationLink(
                    destination: Group {
                        if let p = loggedPlayer { JoinQueueView(player: p) }
                    },
                    isActive: $navigateToJoin,
                    label: { EmptyView() }
                )
            )
            .sheet(item: $credentialMode) { mode in
                CredentialSheet(mode: mode) { player in
                    loggedPlayer = player
                    navigateToJoin = true
                }
            }
            .alert("提示", isPresented: $showMessage) {
                Button("好", role: .cancel) {}
            } message: { Text(message ?? "") }
        }
        .navigationViewStyle(.stack)
    }

    private func smallButton(_ title: String) -> some View {
        Text(title)
            .font(.footnote)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Color.black.opacity(0.6))
            .foregroundColor(.white)
            .clipShape(Capsule())
    }

    private func handleScan(_ payload: String) {
        guard let secret = QRCodeService.secret(fromPayload: payload) else {
            message = "无法识别的二维码"
            showMessage = true
            return
        }
        let service = PlayerService(context: queueManager.context)
        guard let player = service.find(qrSecret: secret) else {
            message = "未找到该账号，请先注册"
            showMessage = true
            return
        }
        loggedPlayer = player
        navigateToJoin = true
    }
}

/// 昵称 + PIN 登录 / 找回二维码的小表单。
private struct CredentialSheet: View {
    let mode: CredentialMode
    var onLoggedIn: ((Player) -> Void)?

    @EnvironmentObject var queueManager: QueueManager
    @Environment(\.dismiss) var dismiss

    @State private var nickname = ""
    @State private var pin = ""
    @State private var message: String?
    @State private var showMessage = false
    @State private var recovered: Player?

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("昵称", text: $nickname)
                    SecureField("PIN", text: $pin).keyboardType(.numberPad)
                }
                Section {
                    Button(mode == .login ? "登录" : "找回我的二维码") { submit() }
                        .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(mode == .login ? "昵称登录" : "找回账号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
            .alert("提示", isPresented: $showMessage) {
                Button("好", role: .cancel) {}
            } message: { Text(message ?? "") }
            .sheet(item: $recovered) { p in
                QRCodeDisplayView(player: p, recovered: true)
            }
        }
        .navigationViewStyle(.stack)
    }

    private func submit() {
        let service = PlayerService(context: queueManager.context)
        switch mode {
        case .login:
            switch service.login(nickname: nickname, pin: pin) {
            case .success(let p):
                onLoggedIn?(p)
                dismiss()
            case .failure(let err):
                message = err.message
                showMessage = true
            }
        case .recover:
            switch service.recoverQR(nickname: nickname, pin: pin) {
            case .success(let p):
                recovered = p
            case .failure(let err):
                message = err.message
                showMessage = true
            }
        }
    }
}
