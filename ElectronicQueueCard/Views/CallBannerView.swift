import SwiftUI
import CoreData

/// 当前叫号横幅：60 秒倒计时，点名字确认（无需扫码），并提供「取消」按钮。
struct CallBannerView: View {
    let side: MachineSide
    let item: QueueItem
    let match: Match

    @EnvironmentObject var queueManager: QueueManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("当前叫号").font(.caption).foregroundColor(.secondary)
                Spacer()
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = Int(queueManager.callTimeout) - Int(context.date.timeIntervalSince(match.calledAt))
                    Text("\(max(0, remaining)) 秒")
                        .font(.headline.monospacedDigit())
                        .foregroundColor(remaining <= 10 ? .red : .primary)
                }
            }
            Text(queueManager.memberNames(item: item).joined(separator: "、"))
                .font(.title2.bold())
            HStack {
                ForEach(queueManager.memberNames(item: item), id: \.self) { name in
                    Button {
                        queueManager.confirmCurrent(side: side)
                    } label: {
                        Text("\(name) 确认").font(.footnote)
                    }
                    .buttonStyle(.bordered)
                }
                Button(role: .destructive) {
                    queueManager.cancelCall(item: item)
                } label: {
                    Text("取消").font(.footnote)
                }
                .buttonStyle(.bordered)
            }
            Text("60 秒内未确认将过号").font(.caption2).foregroundColor(.secondary)
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.15)).cornerRadius(10)
    }
}
