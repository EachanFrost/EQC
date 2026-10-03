import SwiftUI
import CoreData

/// 单台机的完整栏目：机台状态、当前叫号/游玩、队列、过号栏（默认隐藏）。
struct MachineColumnView: View {
    let side: MachineSide
    let onPair: (QueueItem) -> Void
    let onJoinGroup: (QueueItem) -> Void

    @EnvironmentObject var queueManager: QueueManager

    @FetchRequest private var machines: FetchedResults<Machine>
    @FetchRequest private var items: FetchedResults<QueueItem>
    @FetchRequest private var passed: FetchedResults<PassedItem>

    init(side: MachineSide, onPair: @escaping (QueueItem) -> Void, onJoinGroup: @escaping (QueueItem) -> Void) {
        self.side = side
        self.onPair = onPair
        self.onJoinGroup = onJoinGroup

        let active = [QueueItemStatus.waiting.rawValue, QueueItemStatus.called.rawValue, QueueItemStatus.playing.rawValue] as NSArray
        _machines = FetchRequest<Machine>(
            sortDescriptors: [NSSortDescriptor(key: "uid", ascending: true)],
            predicate: NSPredicate(format: "uid == %@", side.rawValue)
        )
        _items = FetchRequest<QueueItem>(
            sortDescriptors: [NSSortDescriptor(key: "joinedAt", ascending: true)],
            predicate: NSPredicate(format: "machineId == %@ AND status IN %@", side.rawValue, active)
        )
        _passed = FetchRequest<PassedItem>(
            sortDescriptors: [NSSortDescriptor(key: "passedAt", ascending: true)],
            predicate: NSPredicate(format: "machineId == %@", side.rawValue)
        )
    }

    private var machine: Machine? { machines.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            statusArea
            queueList
            passedList
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(side.displayName).font(.title2.bold())
            if let m = machine {
                Text(statusText(m.status))
                    .font(.subheadline)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(statusColor(m.status).opacity(0.18))
                    .foregroundColor(statusColor(m.status))
                    .clipShape(Capsule())
            }
            Spacer()
            Image(systemName: "wrench.and.screwdriver")
                .font(.footnote).foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .onLongPressGesture { queueManager.toggleMaintenance(side: side) }
    }

    @ViewBuilder
    private var statusArea: some View {
        if let m = machine {
            if m.status == MachineStatus.calling.rawValue {
                if let item = items.first(where: { $0.status == QueueItemStatus.called.rawValue }),
                   let match = queueManager.currentMatch(for: m) {
                    CallBannerView(side: side, item: item, match: match)
                }
            } else if m.status == MachineStatus.playing.rawValue {
                playingBanner(item: items.first(where: { $0.status == QueueItemStatus.playing.rawValue }))
            } else if m.status == MachineStatus.maintenance.rawValue {
                Text("维护中，暂停叫号")
                    .font(.footnote).foregroundColor(.orange)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(Color.orange.opacity(0.12)).cornerRadius(10)
            }
        }
    }

    private func playingBanner(item: QueueItem?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("游玩中").font(.caption).foregroundColor(.secondary)
            Text(item.map { queueManager.memberNames(item: $0).joined(separator: "、") } ?? "—")
                .font(.title2.bold())
            Button {
                queueManager.endPlaying(side: side)
            } label: {
                Text("结束本局（员工）").font(.footnote)
            }
            .buttonStyle(.bordered)
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.15)).cornerRadius(10)
    }

    private var queueList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("队列").font(.headline)
            let waiting = items.filter { $0.status == QueueItemStatus.waiting.rawValue }
            if waiting.isEmpty {
                Text("暂无排队").font(.footnote).foregroundColor(.secondary).padding(.vertical, 4)
            } else {
                ForEach(Array(waiting.enumerated()), id: \.element.objectID) { idx, item in
                    QueueRowView(index: idx + 1, item: item,
                                 onPair: { onPair(item) },
                                 onJoinGroup: { onJoinGroup(item) })
                }
            }
        }
    }

    /// 过号栏：默认不显示，有玩家过号才显示。
    @ViewBuilder
    private var passedList: some View {
        if !passed.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("过号栏").font(.headline)
                ForEach(passed, id: \.objectID) { p in
                    PassedRowView(passed: p)
                }
            }
        }
    }

    private func statusText(_ raw: String) -> String {
        MachineStatus(rawValue: raw)?.displayName ?? raw
    }

    private func statusColor(_ raw: String) -> Color {
        switch MachineStatus(rawValue: raw) {
        case .idle: return .secondary
        case .calling: return .orange
        case .playing: return .green
        case .maintenance: return .red
        case .none: return .secondary
        }
    }
}
