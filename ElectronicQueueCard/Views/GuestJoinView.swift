import SwiftUI
import CoreData

/// 游客排队：临时昵称（可自动生成）+ 机台 + 模式。
struct GuestJoinView: View {
    @EnvironmentObject var queueManager: QueueManager
    @Environment(\.dismiss) var dismiss

    @State private var nickname = ""
    @State private var side: MachineSide = .left
    @State private var mode: QueueItemType = .solo
    @State private var message: String?
    @State private var showMessage = false

    var body: some View {
        NavigationView {
            Form {
                Section("游客昵称") {
                    TextField("输入昵称（留空自动生成）", text: $nickname)
                }
                Section("机台") {
                    Picker("机台", selection: $side) {
                        ForEach(MachineSide.allCases) { s in Text(s.displayName).tag(s) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("模式") {
                    Picker("模式", selection: $mode) {
                        ForEach(QueueItemType.allCases) { m in Text(modeLabel(m)).tag(m) }
                    }
                    .pickerStyle(.segmented)
                    Text(modeHint(mode)).font(.footnote).foregroundColor(.secondary)
                }
                Section {
                    Button("游客排队") { join() }.frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("游客排队")
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

    private func modeLabel(_ m: QueueItemType) -> String {
        switch m {
        case .solo: return "单人游玩"
        case .duoMatch: return "双人匹配"
        case .duoGroup: return "双人游玩"
        }
    }

    private func modeHint(_ m: QueueItemType) -> String {
        switch m {
        case .solo: return "独占一台双人机。"
        case .duoMatch: return "标记可拼机，可被他人配对；叫号时无人拼则自动转单人。"
        case .duoGroup: return "两人组队，未满两人不叫号；第二人稍后扫码加入。"
        }
    }

    private func join() {
        let name = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = name.isEmpty ? queueManager.nextGuestNickname() : name
        let guest = Guest(context: queueManager.context)
        guest.uid = UUID()
        guest.nickname = finalName
        guest.sessionId = UUID()
        guest.createdAt = Date()

        let result = queueManager.joinQueue(side: side, type: mode, guest1: guest)
        if let err = result {
            queueManager.context.delete(guest)
            message = err
            showMessage = true
        } else {
            dismiss()
        }
    }
}
