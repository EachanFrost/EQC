import SwiftUI
import CoreData

/// 新玩家注册：昵称、头像、PIN，成功后展示二维码。
struct RegisterView: View {
    @EnvironmentObject var queueManager: QueueManager
    @Environment(\.dismiss) var dismiss

    @State private var nickname = ""
    @State private var avatar = PlayerService.avatars[0]
    @State private var pin = ""
    @State private var pinConfirm = ""
    @State private var message: String?
    @State private var showMessage = false
    @State private var newPlayer: Player?

    private let columns = Array(repeating: GridItem(.flexible()), count: 6)

    var body: some View {
        NavigationView {
            Form {
                Section("昵称") {
                    TextField("输入昵称", text: $nickname)
                }
                Section("选择头像") {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(PlayerService.avatars, id: \.self) { a in
                            Text(a)
                                .font(.largeTitle)
                                .padding(4)
                                .background(avatar == a ? Color.blue.opacity(0.3) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onTapGesture { avatar = a }
                        }
                    }
                }
                Section("设置 PIN（4-6 位数字）") {
                    SecureField("PIN", text: $pin).keyboardType(.numberPad)
                    SecureField("再次输入 PIN", text: $pinConfirm).keyboardType(.numberPad)
                }
                Section {
                    Button("注册") { register() }.frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("账号注册")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
            .alert("提示", isPresented: $showMessage) {
                Button("好", role: .cancel) {}
            } message: { Text(message ?? "") }
            .sheet(item: $newPlayer) { p in
                QRCodeDisplayView(player: p, recovered: false)
            }
        }
        .navigationViewStyle(.stack)
    }

    private func register() {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            message = "昵称不能为空"; showMessage = true; return
        }
        guard pin == pinConfirm else {
            message = "两次 PIN 不一致"; showMessage = true; return
        }
        let service = PlayerService(context: queueManager.context)
        switch service.register(nickname: trimmed, pin: pin, avatar: avatar) {
        case .success(let player): newPlayer = player
        case .failure(let err): message = err; showMessage = true
        }
    }
}
