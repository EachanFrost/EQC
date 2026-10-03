import SwiftUI

/// 队列里的一条：单人 / 可拼机 / 双人组，附带上移、下移、拼机、加入、取消动作。
struct QueueRowView: View {
    let index: Int
    let item: QueueItem
    let onPair: () -> Void
    let onJoinGroup: () -> Void

    @EnvironmentObject var queueManager: QueueManager
    @State private var showCancel = false

    var body: some View {
        HStack(spacing: 8) {
            Text("\(index).").font(.footnote.bold()).foregroundColor(.secondary)
                .frame(width: 22, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                Text(queueManager.memberNames(item: item).joined(separator: "、"))
                    .font(.subheadline.bold())
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(queueManager.typeLabel(item.type))
                        .font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(typeColor.opacity(0.15)).foregroundColor(typeColor)
                        .clipShape(Capsule())
                    if item.type == QueueItemType.duoGroup.rawValue && !queueManager.hasSecondMember(item) {
                        Text("等待队友").font(.caption2).foregroundColor(.orange)
                    }
                }
            }
            Spacer()
            HStack(spacing: 0) {
                Button { queueManager.moveQueueItem(item: item, up: true) } label: {
                    Image(systemName: "chevron.up").font(.caption2)
                }
                .buttonStyle(.borderless)

                Button { queueManager.moveQueueItem(item: item, up: false) } label: {
                    Image(systemName: "chevron.down").font(.caption2)
                }
                .buttonStyle(.borderless)
            }
            if item.type == QueueItemType.duoMatch.rawValue {
                Button("拼机", action: onPair).buttonStyle(.bordered).font(.caption2)
            } else if item.type == QueueItemType.duoGroup.rawValue && !queueManager.hasSecondMember(item) {
                Button("加入", action: onJoinGroup).buttonStyle(.bordered).font(.caption2)
            }
            Button(role: .destructive) { showCancel = true } label: {
                Text("取消").font(.caption2)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
        .alert("取消排队？", isPresented: $showCancel) {
            Button("确认取消", role: .destructive) { queueManager.cancelQueue(item: item) }
            Button("再想想", role: .cancel) {}
        } message: {
            Text("将移除 \(queueManager.memberNames(item: item).joined(separator: "、"))，双人组会一起移除。")
        }
    }

    private var typeColor: Color {
        switch item.type {
        case QueueItemType.solo.rawValue: return .blue
        case QueueItemType.duoMatch.rawValue: return .purple
        case QueueItemType.duoGroup.rawValue: return .teal
        default: return .gray
        }
    }
}
