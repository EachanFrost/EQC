import SwiftUI
import CoreData

/// 注册玩家登录：扫码或昵称 + PIN，含找回二维码入口。
struct LoginView: View {
    @EnvironmentObject var queueManager: QueueManager
    @Environment(\.dismiss) var dismiss

    @State private var showScanner = false
    @State private var nickname = ""
    @State private var pin = ""
    @State private var message: String?
    @State private var showMessage = false
    @State private var loggedPlayer: Player?
    @State private var navigateToJoin = false
    @State private var recoveredPlayer: Player?

    var body: some View {
        NavigationView {
            Form {
                Section("扫码登录") {
                    Button { showScanner = true } label: {
                        Label("打开摄像头扫码", systemImage: "qrcode.viewfinder")
                    }
                }
                Section("昵称 + PIN 登录") {
                    TextField("昵称", text: $nickname)
                    SecureField("PIN", text: $pin).keyboardType(.numberPad)
                    Button("登录") { login() }
                }
                Section {
                    Button("找回我的二维码") { recover() }
                } footer: {
                    Text("二维码丢失时，用昵称 + PIN 找回并重新保存。")
                }
            }
            .navigationTitle("扫码登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
            .background(
                NavigationLink(
                    destination: Group {
                        if let p = loggedPlayer { JoinQueueView(player: p) }
                    },
                    isActive: $navigateToJoin,
                    label: { EmptyView() }
                )
            )
            .sheet(isPresented: $showScanner) {
                ScannerSheet { payload in handleScan(payload) }
            }
            .sheet(item: $recoveredPlayer) { p in
                QRCodeDisplayView(player: p, recovered: true)
            }
            .alert("提示", isPresented: $showMessage) {
                Button("好", role: .cancel) {}
            } message: { Text(message ?? "") }
        }
        .navigationViewStyle(.stack)
    }

    private func handleScan(_ payload: String) {
        showScanner = false
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

    private func login() {
        let service = PlayerService(context: queueManager.context)
        switch service.login(nickname: nickname, pin: pin) {
        case .success(let p):
            loggedPlayer = p
            navigateToJoin = true
        case .failure(let err):
            message = err.message
            showMessage = true
        }
    }

    private func recover() {
        let service = PlayerService(context: queueManager.context)
        switch service.recoverQR(nickname: nickname, pin: pin) {
        case .success(let p): recoveredPlayer = p
        case .failure(let err): message = err.message; showMessage = true
        }
    }
}
