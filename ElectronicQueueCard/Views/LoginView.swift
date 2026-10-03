import SwiftUI
import CoreData

private enum CredentialMode: String, Identifiable {
    case login
    case recover
    var id: String { rawValue }
}

/// 扫码登录：屏幕中间摄像头小窗口，四周透明。
struct LoginView: View {
    @EnvironmentObject var queueManager: QueueManager
    @Environment(\.dismiss) var dismiss

    @State private var credentialMode: CredentialMode?
    @State private var loggedPlayer: Player?
    @State private var message: String?
    @State private var showMessage = false

    var body: some View {
        ZStack {
            CameraScannerView(onScan: handleScan)
                .frame(width: 480, height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    VStack {
                        HStack {
                            Button { dismiss() } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .shadow(radius: 4)
                                    .frame(width: 48, height: 48)
                                    .contentShape(Rectangle())
                            }
                            Spacer()
                        }
                        Spacer()
                        HStack(spacing: 12) {
                            Button { credentialMode = .login } label: { smallButton("昵称登录") }
                            Button { credentialMode = .recover } label: { smallButton("账号找回") }
                        }
                        .padding(.bottom, 12)
                    }
                    .padding(10)
                }
        }
        .sheet(item: $credentialMode) { mode in
            CredentialSheet(mode: mode) { player in
                credentialMode = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    loggedPlayer = player
                }
            }
        }
        .fullScreenCover(item: $loggedPlayer) { player in
            JoinQueueView(player: player,
                          onFinished: { closeAll() },
                          onCancel: { closeAll() })
        }
        .alert("提示", isPresented: $showMessage) {
            Button("好", role: .cancel) {}
        } message: { Text(message ?? "") }
    }

    private func smallButton(_ title: String) -> some View {
        Text(title)
            .font(.footnote)
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(Color.white.opacity(0.92))
            .foregroundColor(.black)
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
    }

    /// 先关掉排队页（上层 fullScreenCover），再关掉登录页（下层），避免卡在摄像头。
    private func closeAll() {
        loggedPlayer = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }
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
            .navigationTitle(mode == .login ? "昵称登录" : "账号找回")
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
