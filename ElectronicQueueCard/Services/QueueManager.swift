import Foundation
import CoreData
import Combine
import AVFoundation

/// 核心调度器：两台机完全独立，各自队列、各自叫号、各自游玩状态。
/// 叫号后玩家点击确认（无需扫码），超时过号；叫号中可取消排队。
final class QueueManager: ObservableObject {
    let context: NSManagedObjectContext

    let callTimeout: TimeInterval = 60          // 叫号确认倒计时
    let passedTimeout: TimeInterval = 30 * 60   // 过号栏保留时长

    @Published var voiceEnabled: Bool
    private let synthesizer = AVSpeechSynthesizer()

    private var timer: Timer?
    private var lastCleanup = Date()
    private let cleanupInterval: TimeInterval = 10

    init(context: NSManagedObjectContext) {
        self.context = context
        self.voiceEnabled = UserDefaults.standard.bool(forKey: "voiceEnabled")
        startTimer()
        reconcileMachines()
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - 定时器

    private func startTimer() {
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.onTick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func onTick() {
        checkCallTimeouts()
        if Date().timeIntervalSince(lastCleanup) >= cleanupInterval {
            lastCleanup = Date()
            cleanupExpiredPassedItems()
        }
    }

    private func save() {
        try? context.save()
    }

    // MARK: - 查询

    func machine(side: MachineSide) -> Machine? {
        let req: NSFetchRequest<Machine> = Machine.fetchRequest()
        req.predicate = NSPredicate(format: "uid == %@", side.rawValue)
        return try? context.fetch(req).first
    }

    func machineName(for side: MachineSide) -> String {
        machine(side: side)?.name ?? side.displayName
    }

    func renameMachine(side: MachineSide, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let m = machine(side: side) else { return }
        m.name = trimmed
        log("修改机台名称")
        save()
    }

    func queueItem(uid: UUID) -> QueueItem? {
        let req: NSFetchRequest<QueueItem> = QueueItem.fetchRequest()
        req.predicate = NSPredicate(format: "uid == %@", uid as NSUUID)
        return try? context.fetch(req).first
    }

    func player(uid: UUID) -> Player? {
        let req: NSFetchRequest<Player> = Player.fetchRequest()
        req.predicate = NSPredicate(format: "uid == %@", uid as NSUUID)
        return try? context.fetch(req).first
    }

    func guest(uid: UUID) -> Guest? {
        let req: NSFetchRequest<Guest> = Guest.fetchRequest()
        req.predicate = NSPredicate(format: "uid == %@", uid as NSUUID)
        return try? context.fetch(req).first
    }

    func currentMatch(for machine: Machine) -> Match? {
        guard let uid = machine.currentMatchId else { return nil }
        let req: NSFetchRequest<Match> = Match.fetchRequest()
        req.predicate = NSPredicate(format: "uid == %@", uid as NSUUID)
        return try? context.fetch(req).first
    }

    func waitingItems(for side: MachineSide) -> [QueueItem] {
        let req: NSFetchRequest<QueueItem> = QueueItem.fetchRequest()
        req.predicate = NSPredicate(format: "machineId == %@ AND status == %@",
                                    side.rawValue, QueueItemStatus.waiting.rawValue)
        req.sortDescriptors = [NSSortDescriptor(key: "joinedAt", ascending: true)]
        return (try? context.fetch(req)) ?? []
    }

    /// 队列中第一个等待拼机的双人匹配条目（用于提示合并）。
    func findDuoMatchEntry(side: MachineSide) -> QueueItem? {
        let req: NSFetchRequest<QueueItem> = QueueItem.fetchRequest()
        req.predicate = NSPredicate(format: "machineId == %@ AND type == %@ AND status == %@",
                                    side.rawValue, QueueItemType.duoMatch.rawValue, QueueItemStatus.waiting.rawValue)
        req.sortDescriptors = [NSSortDescriptor(key: "joinedAt", ascending: true)]
        return try? context.fetch(req).first
    }

    /// 队首可叫号条目：跳过未满两人的双人组。
    func findNextCallableItem(side: MachineSide) -> QueueItem? {
        for item in waitingItems(for: side) {
            if item.type == QueueItemType.duoGroup.rawValue && !hasSecondMember(item) {
                continue
            }
            return item
        }
        return nil
    }

    // MARK: - 展示辅助

    func memberNames(item: QueueItem) -> [String] {
        var names: [String] = []
        if let p1 = item.playerId1, let p = player(uid: p1) { names.append(p.nickname) }
        else if let g1 = item.guestId1, let g = guest(uid: g1) { names.append(g.nickname) }
        if let p2 = item.playerId2, let p = player(uid: p2) { names.append(p.nickname) }
        else if let g2 = item.guestId2, let g = guest(uid: g2) { names.append(g.nickname) }
        return names
    }

    func hasSecondMember(_ item: QueueItem) -> Bool {
        return item.playerId2 != nil || item.guestId2 != nil
    }

    func typeLabel(_ raw: String) -> String {
        switch raw {
        case QueueItemType.solo.rawValue: return "单人"
        case QueueItemType.duoMatch.rawValue: return "可拼机"
        case QueueItemType.duoGroup.rawValue: return "双人组"
        default: return raw
        }
    }

    func formatCountdown(_ interval: TimeInterval) -> String {
        let s = max(0, Int(interval))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    func nextGuestNickname() -> String {
        let req: NSFetchRequest<Guest> = Guest.fetchRequest()
        let count = (try? context.count(for: req)) ?? 0
        return "游客#\(count + 1)"
    }

    // MARK: - 入队

    @discardableResult
    func joinQueue(side: MachineSide, type: QueueItemType,
                   player1: Player? = nil, guest1: Guest? = nil) -> String? {
        if let p = player1, hasActiveEntry(playerId: p.uid) {
            return "你已在队列中，请勿重复排队"
        }
        let item = QueueItem(context: context)
        item.uid = UUID()
        item.machineId = side.rawValue
        item.type = type.rawValue
        item.playerId1 = player1?.uid
        item.guestId1 = guest1?.uid
        item.status = QueueItemStatus.waiting.rawValue
        item.joinedAt = Date()
        item.matched = (type == .duoGroup)
        log("加入队列", targetId: item.uid)
        save()
        scheduleIfIdle(side: side)
        return nil
    }

    func hasActiveEntry(playerId: UUID) -> Bool {
        let req: NSFetchRequest<QueueItem> = QueueItem.fetchRequest()
        let activeStatuses = [QueueItemStatus.waiting.rawValue, QueueItemStatus.called.rawValue, QueueItemStatus.playing.rawValue] as NSArray
        req.predicate = NSPredicate(format: "(playerId1 == %@ OR playerId2 == %@) AND status IN %@",
                                    playerId as NSUUID, playerId as NSUUID, activeStatuses)
        return ((try? context.count(for: req)) ?? 0) > 0
    }

    // MARK: - 拼机 / 组队

    func pair(item: QueueItem, player: Player? = nil, guest: Guest? = nil) -> String? {
        guard item.type == QueueItemType.duoMatch.rawValue else { return "该条目已不是可拼机状态" }
        if let p = player {
            if let pid1 = item.playerId1, pid1 == p.uid { return "不能与自己拼机" }
            removeOtherActiveEntries(playerId: p.uid, except: item.uid)
            item.playerId2 = p.uid
        } else if let g = guest {
            item.guestId2 = g.uid
        }
        item.type = QueueItemType.duoGroup.rawValue
        item.matched = true
        log("拼机配对", targetId: item.uid)
        save()
        return nil
    }

    func joinGroup(item: QueueItem, player: Player? = nil, guest: Guest? = nil) -> String? {
        guard item.type == QueueItemType.duoGroup.rawValue else { return "该条目不是双人组" }
        guard !hasSecondMember(item) else { return "该队已满" }
        if let p = player {
            if let pid1 = item.playerId1, pid1 == p.uid { return "不能加入自己的队伍" }
            removeOtherActiveEntries(playerId: p.uid, except: item.uid)
            item.playerId2 = p.uid
        } else if let g = guest {
            item.guestId2 = g.uid
        }
        item.matched = true
        log("加入双人组", targetId: item.uid)
        save()
        if let side = MachineSide(rawValue: item.machineId) {
            scheduleIfIdle(side: side)
        }
        return nil
    }

    private func removeOtherActiveEntries(playerId: UUID, except itemUid: UUID) {
        let req: NSFetchRequest<QueueItem> = QueueItem.fetchRequest()
        let removable = [QueueItemStatus.waiting.rawValue, QueueItemStatus.called.rawValue] as NSArray
        req.predicate = NSPredicate(format: "(playerId1 == %@ OR playerId2 == %@) AND uid != %@ AND status IN %@",
                                    playerId as NSUUID, playerId as NSUUID, itemUid as NSUUID, removable)
        if let items = try? context.fetch(req) {
            for it in items {
                cleanupGuests(for: it)
                context.delete(it)
            }
        }
    }

    func cancelPair(item: QueueItem) {
        guard item.type == QueueItemType.duoGroup.rawValue else { return }
        item.type = QueueItemType.duoMatch.rawValue
        item.playerId2 = nil
        item.guestId2 = nil
        item.matched = false
        log("取消配对", targetId: item.uid)
        save()
    }

    func cancelQueue(item: QueueItem) {
        let uid = item.uid
        cleanupGuests(for: item)
        context.delete(item)
        log("取消排队", targetId: uid)
        save()
    }

    // MARK: - 调度

    func scheduleIfIdle(side: MachineSide) {
        guard let m = machine(side: side), m.status == MachineStatus.idle.rawValue else { return }
        callNext(side: side)
    }

    /// 机台空闲时叫下一位。
    func callNext(side: MachineSide) {
        guard let m = machine(side: side), m.status == MachineStatus.idle.rawValue else { return }
        guard let item = findNextCallableItem(side: side) else { return }
        item.status = QueueItemStatus.called.rawValue
        let match = Match(context: context)
        match.uid = UUID()
        match.machineId = side.rawValue
        match.queueItemId = item.uid
        match.status = MatchStatus.called.rawValue
        match.calledAt = Date()
        m.currentMatchId = match.uid
        m.status = MachineStatus.calling.rawValue
        log("叫号", targetId: item.uid)
        save()
        announceCall(item: item, side: side)
    }

    /// 玩家点击确认上机（无需扫码）。
    func confirmCurrent(side: MachineSide) {
        guard let m = machine(side: side),
              let match = currentMatch(for: m),
              match.status == MatchStatus.called.rawValue,
              let item = queueItem(uid: match.queueItemId) else { return }
        item.status = QueueItemStatus.playing.rawValue
        item.confirmedAt = Date()
        match.status = MatchStatus.playing.rawValue
        match.startedAt = Date()
        m.status = MachineStatus.playing.rawValue
        log("确认上机", targetId: item.uid)
        save()
    }

    /// 叫号中取消：移除该条目并叫下一位。
    func cancelCall(item: QueueItem) {
        guard let side = MachineSide(rawValue: item.machineId) else { return }
        guard let m = machine(side: side) else { return }
        if let match = currentMatch(for: m), match.queueItemId == item.uid {
            match.status = MatchStatus.done.rawValue
            match.endedAt = Date()
        }
        m.currentMatchId = nil
        m.status = MachineStatus.idle.rawValue
        cleanupGuests(for: item)
        context.delete(item)
        log("取消排队", targetId: item.uid)
        save()
        callNext(side: side)
    }

    private func checkCallTimeouts() {
        for side in MachineSide.allCases {
            guard let m = machine(side: side),
                  m.status == MachineStatus.calling.rawValue,
                  let match = currentMatch(for: m),
                  match.status == MatchStatus.called.rawValue else { continue }
            if Date().timeIntervalSince(match.calledAt) >= callTimeout {
                passCurrent(side: side)
            }
        }
    }

    private func passCurrent(side: MachineSide) {
        guard let m = machine(side: side),
              let match = currentMatch(for: m),
              let item = queueItem(uid: match.queueItemId) else { return }
        item.status = QueueItemStatus.passed.rawValue
        let passed = PassedItem(context: context)
        passed.uid = UUID()
        passed.machineId = side.rawValue
        passed.queueItemId = item.uid
        passed.passedAt = Date()
        passed.expiresAt = Date().addingTimeInterval(passedTimeout)
        match.status = MatchStatus.done.rawValue
        match.endedAt = Date()
        m.currentMatchId = nil
        m.status = MachineStatus.idle.rawValue
        log("过号", targetId: item.uid)
        save()
        callNext(side: side)
    }

    func endPlaying(side: MachineSide) {
        guard let m = machine(side: side) else { return }
        let oldMatchId = m.currentMatchId
        if let match = currentMatch(for: m) {
            match.status = MatchStatus.done.rawValue
            match.endedAt = Date()
            if let item = queueItem(uid: match.queueItemId) {
                item.status = QueueItemStatus.done.rawValue
                cleanupGuests(for: item)
            }
        }
        m.currentMatchId = nil
        m.status = MachineStatus.idle.rawValue
        log("结束本局", targetId: oldMatchId)
        save()
        callNext(side: side)
    }

    func returnFromPassed(passed: PassedItem) {
        let itemUid = passed.queueItemId
        let machineRaw = passed.machineId
        guard let side = MachineSide(rawValue: machineRaw) else { return }
        if let item = queueItem(uid: itemUid) {
            let others = waitingItems(for: side).filter { $0.uid != itemUid }
            let earliest = others.map { $0.joinedAt }.min()
            item.status = QueueItemStatus.waiting.rawValue
            item.joinedAt = (earliest ?? Date()).addingTimeInterval(-1)
        }
        context.delete(passed)
        log("回到队列", targetId: itemUid)
        save()
        scheduleIfIdle(side: side)
    }

    /// 玩家在过号栏点「离开」：移除该过号条目及其队列条目。
    func leaveFromPassed(passed: PassedItem) {
        let itemUid = passed.queueItemId
        if let item = queueItem(uid: itemUid) {
            cleanupGuests(for: item)
            context.delete(item)
        }
        context.delete(passed)
        log("离开过号栏", targetId: itemUid)
        save()
    }

    private func cleanupExpiredPassedItems() {
        let req: NSFetchRequest<PassedItem> = PassedItem.fetchRequest()
        req.predicate = NSPredicate(format: "expiresAt <= %@", Date() as CVarArg)
        guard let expired = try? context.fetch(req), !expired.isEmpty else { return }
        for p in expired {
            if let item = queueItem(uid: p.queueItemId), item.status == QueueItemStatus.passed.rawValue {
                cleanupGuests(for: item)
                context.delete(item)
            }
            context.delete(p)
        }
        save()
    }

    func toggleMaintenance(side: MachineSide) {
        guard let m = machine(side: side) else { return }
        switch m.status {
        case MachineStatus.maintenance.rawValue:
            m.status = MachineStatus.idle.rawValue
            scheduleIfIdle(side: side)
        case MachineStatus.idle.rawValue:
            m.status = MachineStatus.maintenance.rawValue
        default:
            break
        }
        save()
    }

    // MARK: - 语音播报

    func toggleVoice() {
        voiceEnabled.toggle()
        UserDefaults.standard.set(voiceEnabled, forKey: "voiceEnabled")
        if !voiceEnabled {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    private func announceCall(item: QueueItem, side: MachineSide) {
        guard voiceEnabled else { return }
        let names = memberNames(item: item).joined(separator: "、")
        let machineName = machine(side: side)?.name ?? side.displayName
        let utterance = AVSpeechUtterance(string: "\(machineName)叫号，请\(names)到机台")
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.5
        synthesizer.speak(utterance)
    }

    func log(_ action: String, targetId: UUID? = nil) {
        let entry = AdminLog(context: context)
        entry.uid = UUID()
        entry.action = action
        entry.targetId = targetId
        entry.timestamp = Date()
    }

    private func cleanupGuests(for item: QueueItem) {
        if let gid = item.guestId1 { deleteGuest(uid: gid) }
        if let gid = item.guestId2 { deleteGuest(uid: gid) }
    }

    private func deleteGuest(uid: UUID) {
        let req: NSFetchRequest<Guest> = Guest.fetchRequest()
        req.predicate = NSPredicate(format: "uid == %@", uid as NSUUID)
        if let g = try? context.fetch(req).first { context.delete(g) }
    }

    /// 启动时校正：若机台停在 CALLING 但对应 Match 已结束，则复位为空闲。
    private func reconcileMachines() {
        for side in MachineSide.allCases {
            guard let m = machine(side: side), m.status == MachineStatus.calling.rawValue else { continue }
            if let match = currentMatch(for: m), match.status == MatchStatus.called.rawValue {
                // 仍在叫号中，交给定时器处理
            } else {
                m.currentMatchId = nil
                m.status = MachineStatus.idle.rawValue
            }
        }
        save()
    }
}
