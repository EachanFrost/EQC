import SwiftUI

/// 注册玩家登录后：选择机台与模式入队。选双人匹配且队列已有可拼机玩家时，提示是否拼机合并。
struct JoinQueueView: View {
    let player: Player
    var onFinished: (() -> Void)?

    @EnvironmentObject var queueManager: QueueManager
    @Environment(\.dismiss) var dismiss

    @State private var side: MachineSide = .left
    @State private var mode: QueueItemType = .solo
    @State private var message: String?
    @State private var showMessage = false
    @State private var pairTarget: QueueItem?
    @State private var showPairPrompt = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading) {
                    Text(player.nickname).font(.headline)
                    Text("选择机台与模式开始排队").font(.footnote).foregroundColor(.secondary)
                }
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
                Button("开始排队") { join() }.frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("排队")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
        }
        .confirmationDialog("与他拼机？", isPresented: $showPairPrompt, titleVisibility: .visible) {
            Button("与他拼机") { doJoin(pairWith: pairTarget) }
            Button("各自排队", role: .cancel) { doJoin(pairWith: nil) }
        } message: {
            Text(pairTargetMessage)
        }
        .alert("提示", isPresented: $showMessage) {
            Button("好", role: .cancel) {}
        } message: { Text(message ?? "") }
    }

    private var pairTargetMessage: String {
        if let t = pairTarget {
            return "队列中有「\(queueManager.memberNames(item: t).joined(separator: "、"))」等待拼机，是否与他拼机？"
        }
        return ""
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
        if mode == .duoMatch, let target = queueManager.findDuoMatchEntry(side: side) {
            pairTarget = target
            showPairPrompt = true
        } else {
            doJoin(pairWith: nil)
        }
    }

    private func doJoin(pairWith target: QueueItem?) {
        let result: String?
        if let target = target {
            result = queueManager.pair(item: target, player: player)
        } else {
            result = queueManager.joinQueue(side: side, type: mode, player1: player)
        }
        if let err = result {
            message = err
            showMessage = true
        } else if let onFinished = onFinished {
            onFinished()
        } else {
            dismiss()
        }
    }
}
