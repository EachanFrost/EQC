import SwiftUI

/// 过号栏里的一条：显示昵称、模式、30 分钟倒计时，玩家点“我回来了”自主恢复。
struct PassedRowView: View {
    let passed: PassedItem
    @EnvironmentObject var queueManager: QueueManager

    var body: some View {
        HStack(spacing: 8) {
            if let item = queueManager.queueItem(uid: passed.queueItemId) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(queueManager.memberNames(item: item).joined(separator: "、"))
                        .font(.subheadline.bold()).lineLimit(1)
                    HStack(spacing: 4) {
                        Text(queueManager.typeLabel(item.type))
                        Text("·")
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(queueManager.formatCountdown(passed.expiresAt.timeIntervalSince(context.date)))
                        }
                    }
                    .font(.caption2).foregroundColor(.secondary)
                }
            } else {
                Text("已清除").font(.caption2).foregroundColor(.secondary)
            }
            Spacer()
            Button("我回来了") {
                queueManager.returnFromPassed(passed: passed)
            }
            .buttonStyle(.bordered).font(.caption2)
        }
        .padding(.vertical, 4)
    }
}
