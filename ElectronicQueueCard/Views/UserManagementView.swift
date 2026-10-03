import SwiftUI
import CoreData

/// 注册用户管理：管理员密码验证后进入用户列表，支持删除、改名、改 PIN、显示二维码。
struct UserManagementView: View {
    @EnvironmentObject var queueManager: QueueManager
    @Environment(\.dismiss) var dismiss

    @State private var authenticated = false
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var edit: UserEdit?
    @State private var playerToDelete: Player?
    @State private var showDeleteConfirm = false
    @State private var showChangePassword = false

    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)])
    private var players: FetchedResults<Player>

    private enum UserEdit: Identifiable {
        case qr(Player)
        case rename(Player)
        case pin(Player)

        var id: String {
            switch self {
            case .qr: return "qr"
            case .rename: return "rename"
            case .pin: return "pin"
            }
        }
    }

    var body: some View {
        NavigationView {
            Group {
                if authenticated {
                    playerList
                } else {
                    passwordForm
                }
            }
            .navigationTitle(authenticated ? "注册用户" : "管理员验证")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    if authenticated {
                        Button("改密码") { showChangePassword = true }
                    }
                }
            }
        }
        .sheet(isPresented: $showChangePassword) { ChangeAdminPasswordSheet() }
        .navigationViewStyle(.stack)
    }

    private var passwordForm: some View {
        Form {
            Section("请输入管理员密码") {
                SecureField("管理员密码", text: $password).keyboardType(.numberPad)
            }
            if let msg = errorMessage {
                Section {
                    Text(msg).font(.footnote).foregroundColor(.red)
                }
            }
            Section {
                Button("确定") { verify() }.frame(maxWidth: .infinity)
            }
        }
    }

    private var playerList: some View {
        List {
            ForEach(players, id: \.objectID) { player in
                HStack(spacing: 8) {
                    Text(player.nickname).font(.headline).lineLimit(1)
                    Spacer()
                    Button { edit = .qr(player) } label: { Text("二维码").font(.footnote) }
                        .buttonStyle(.bordered)
                    Button { edit = .rename(player) } label: { Text("改名").font(.footnote) }
                        .buttonStyle(.bordered)
                    Button { edit = .pin(player) } label: { Text("改PIN").font(.footnote) }
                        .buttonStyle(.bordered)
                    Button(role: .destructive) {
                        playerToDelete = player
                        showDeleteConfirm = true
                    } label: { Text("删除").font(.footnote) }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 4)
            }
        }
        .sheet(item: $edit) { e in
            switch e {
            case .qr(let p): QRCodeDisplayView(player: p, recovered: true)
            case .rename(let p): RenamePlayerSheet(player: p)
            case .pin(let p): ChangePinSheet(player: p)
            }
        }
        .confirmationDialog("删除用户？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                if let p = playerToDelete {
                    PlayerService(context: queueManager.context).delete(p)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(playerToDelete.map { "确定删除「\($0.nickname)」吗？" } ?? "")
        }
    }

    private func verify() {
        if password == AdminConfig.password {
            authenticated = true
            password = ""
            errorMessage = nil
        } else {
            errorMessage = "密码错误"
        }
    }
}

/// 改名小表单。
private struct RenamePlayerSheet: View {
    let player: Player
    @State private var nickname: String

    @EnvironmentObject var queueManager: QueueManager
    @Environment(\.dismiss) var dismiss
    @State private var message: String?
    @State private var showMessage = false

    init(player: Player) {
        self.player = player
        _nickname = State(initialValue: player.nickname)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("昵称") {
                    TextField("昵称", text: $nickname)
                }
                Section {
                    Button("保存") { save() }.frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("改名")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
            .alert("提示", isPresented: $showMessage) {
                Button("好", role: .cancel) {}
            } message: { Text(message ?? "") }
        }
        .navigationViewStyle(.stack)
    }

    private func save() {
        let service = PlayerService(context: queueManager.context)
        switch service.rename(player, nickname: nickname) {
        case .success: dismiss()
        case .failure(let err): message = err.message; showMessage = true
        }
    }
}

/// 修改 PIN 小表单。
private struct ChangePinSheet: View {
    let player: Player
    @State private var pin = ""
    @State private var pinConfirm = ""

    @EnvironmentObject var queueManager: QueueManager
    @Environment(\.dismiss) var dismiss
    @State private var message: String?
    @State private var showMessage = false

    var body: some View {
        NavigationView {
            Form {
                Section("新 PIN（4-6 位数字）") {
                    SecureField("PIN", text: $pin).keyboardType(.numberPad)
                    SecureField("再次输入", text: $pinConfirm).keyboardType(.numberPad)
                }
                Section {
                    Button("保存") { save() }.frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("修改 PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
            .alert("提示", isPresented: $showMessage) {
                Button("好", role: .cancel) {}
            } message: { Text(message ?? "") }
        }
        .navigationViewStyle(.stack)
    }

    private func save() {
        guard pin == pinConfirm else {
            message = "两次 PIN 不一致"
            showMessage = true
            return
        }
        let service = PlayerService(context: queueManager.context)
        switch service.changePin(player, newPin: pin) {
        case .success: dismiss()
        case .failure(let err): message = err.message; showMessage = true
        }
    }
}

/// 修改管理员密码小表单。
private struct ChangeAdminPasswordSheet: View {
    @State private var current = ""
    @State private var newPin = ""
    @State private var confirm = ""

    @Environment(\.dismiss) var dismiss
    @State private var message: String?
    @State private var showMessage = false

    var body: some View {
        NavigationView {
            Form {
                Section("当前密码") {
                    SecureField("当前密码", text: $current).keyboardType(.numberPad)
                }
                Section("新密码（4-6 位数字）") {
                    SecureField("新密码", text: $newPin).keyboardType(.numberPad)
                    SecureField("再次输入", text: $confirm).keyboardType(.numberPad)
                }
                Section {
                    Button("保存") { save() }.frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("修改管理员密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
            .alert("提示", isPresented: $showMessage) {
                Button("好", role: .cancel) {}
            } message: { Text(message ?? "") }
        }
        .navigationViewStyle(.stack)
    }

    private func save() {
        guard current == AdminConfig.password else {
            message = "当前密码错误"
            showMessage = true
            return
        }
        guard newPin == confirm else {
            message = "两次输入不一致"
            showMessage = true
            return
        }
        let digits = CharacterSet.decimalDigits
        guard newPin.count >= 4, newPin.count <= 6,
              newPin.rangeOfCharacter(from: digits.inverted) == nil else {
            message = "密码需为 4-6 位数字"
            showMessage = true
            return
        }
        AdminConfig.password = newPin
        dismiss()
    }
}
