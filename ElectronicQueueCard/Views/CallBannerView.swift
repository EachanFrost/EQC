import SwiftUI
import CoreData

/// 当前叫号横幅：60 秒倒计时，游客点名字确认，注册玩家扫码确认。
struct CallBannerView: View {
    let side: MachineSide
    let item: QueueItem
    let match: Match

    @EnvironmentObject var queueManager: QueueManager
    @State private var showScanner = false
    @State private var message: String?
    @State private var showMessage = false

    private struct Member: Identifiable {
        let key: String
        let name: String
        let isGuest: Bool
        var id: String { key }
    }

    private var members: [Member] {
        var result: [Member] = []
        if let pid = item.playerId1, let p = queueManager.player(uid: pid) {
            result.append(Member(key: "p1", name: p.nickname, isGuest: false))
        } else if let gid = item.guestId1, let g = queueManager.guest(uid: gid) {
            result.append(Member(key: "g1", name: g.nickname, isGuest: true))
        }
        if let pid = item.playerId2, let p = queueManager.player(uid: pid) {
            result.append(Member(key: "p2", name: p.nickname, isGuest: false))
        } else if let gid = item.guestId2, let g = queueManager.guest(uid: gid) {
            result.append(Member(key: "g2", name: g.nickname, isGuest: true))
        }
        return result
    }

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
                ForEach(members) { m in
                    Button {
                        confirm(m)
                    } label: {
                        Text(m.isGuest ? "\(m.name) 确认" : "\(m.name) 扫码确认")
                            .font(.footnote)
                    }
                    .buttonStyle(.bordered)
                }
            }
            Text("60 秒内未确认将过号").font(.caption2).foregroundColor(.secondary)
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.15)).cornerRadius(10)
        .sheet(isPresented: $showScanner) {
            ScannerSheet { payload in
                showScanner = false
                if let err = queueManager.confirmByScan(payload: payload, side: side) {
                    message = err
                    showMessage = true
                }
            }
        }
        .alert("提示", isPresented: $showMessage) {
            Button("好", role: .cancel) {}
        } message: { Text(message ?? "") }
    }

    private func confirm(_ m: Member) {
        if m.isGuest {
            if let err = queueManager.confirmGuest(item: item) {
                message = err
                showMessage = true
            }
        } else {
            showScanner = true
        }
    }
}
