import SwiftUI
import CoreData

enum IdentifyMode {
    case pair      // 与他拼机
    case joinGroup // 加入双人组
}

/// 第二位玩家身份确认：扫码 / 昵称+PIN / 游客加入。
struct IdentifyView: View {
    let item: QueueItem
    let mode: IdentifyMode

    @EnvironmentObject var queueManager: QueueManager
    @Environment(\.dismiss) var dismiss

    @State private var showScanner = false
    @State private var nickname = ""
    @State private var pin = ""
    @State private var guestName = ""
    @State private var message: String?
    @State private var showMessage = false

    var body: some View {
        NavigationView {
            Form {
                Section("目标") {
                    Text(queueManager.memberNames(item: item).joined(separator: "、"))
                        .font(.footnote).foregroundColor(.secondary)
                }
                Section("扫码确认") {
                    Button { showScanner = true } label: {
                        Label("打开摄像头扫码", systemImage: "qrcode.viewfinder")
                    }
                }
                Section("昵称 + PIN") {
                    TextField("昵称", text: $nickname)
                    SecureField("PIN", text: $pin).keyboardType(.numberPad)
                    Button("登录并确认") { loginAndAct() }
                }
                Section("游客") {
                    TextField("临时昵称（留空自动生成）", text: $guestName)
                    Button("游客加入") { guestAct() }
                }
            }
            .navigationTitle(mode == .pair ? "与他拼机" : "加入双人组")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
            .fullScreenCover(isPresented: $showScanner) {
                ScannerSheet { payload in handleScan(payload) }
                    .background(ClearBackgroundView())
            }
            .alert("提示", isPresented: $showMessage) {
                Button("好", role: .cancel) {}
            } message: { Text(message ?? "") }
        }
        .navigationViewStyle(.stack)
    }

    private func handleScan(_ payload: String) {
        showScanner = false
        guard let secret = QRCodeService.secret(fromPayload: payload),
              let player = PlayerService(context: queueManager.context).find(qrSecret: secret) else {
            message = "无法识别的二维码"
            showMessage = true
            return
        }
        act(player: player)
    }

    private func loginAndAct() {
        let service = PlayerService(context: queueManager.context)
        switch service.login(nickname: nickname, pin: pin) {
        case .success(let p): act(player: p)
        case .failure(let err): message = err.message; showMessage = true
        }
    }

    private func act(player: Player) {
        let result: String?
        switch mode {
        case .pair: result = queueManager.pair(item: item, player: player)
        case .joinGroup: result = queueManager.joinGroup(item: item, player: player)
        }
        if let err = result {
            message = err
            showMessage = true
        } else {
            dismiss()
        }
    }

    private func guestAct() {
        let name = guestName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = name.isEmpty ? queueManager.nextGuestNickname() : name
        let guest = Guest(context: queueManager.context)
        guest.uid = UUID()
        guest.nickname = finalName
        guest.sessionId = UUID()
        guest.createdAt = Date()

        let result: String?
        switch mode {
        case .pair: result = queueManager.pair(item: item, guest: guest)
        case .joinGroup: result = queueManager.joinGroup(item: item, guest: guest)
        }
        if let err = result {
            queueManager.context.delete(guest)
            message = err
            showMessage = true
        } else {
            dismiss()
        }
    }
}
