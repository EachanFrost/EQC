import Foundation

/// 机台用字符串 ID 表示（"1"、"2"、"3"...），数量可配置。
typealias MachineSide = String

enum MachineConfig {
    static let maxCount = 6
    static let countKey = "machineCount"

    static var count: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: countKey)
            return (v >= 1 && v <= maxCount) ? v : 2
        }
        set {
            UserDefaults.standard.set(min(max(newValue, 1), maxCount), forKey: countKey)
        }
    }

    static var ids: [MachineSide] {
        (1...count).map { "\($0)" }
    }

    static func defaultName(for side: MachineSide) -> String {
        switch side {
        case "1": return "左机"
        case "2": return "右机"
        default: return "机台\(side)"
        }
    }
}

enum MachineStatus: String, CaseIterable {
    case idle = "IDLE"
    case calling = "CALLING"
    case playing = "PLAYING"
    case maintenance = "MAINTENANCE"

    var displayName: String {
        switch self {
        case .idle: return "空闲"
        case .calling: return "叫号中"
        case .playing: return "游玩中"
        case .maintenance: return "维护中"
        }
    }
}

enum QueueItemType: String, CaseIterable, Identifiable {
    case solo = "SOLO"
    case duoMatch = "DUO_MATCH"
    case duoGroup = "DUO_GROUP"

    var id: String { rawValue }
}

enum QueueItemStatus: String {
    case waiting = "WAITING"
    case called = "CALLED"
    case playing = "PLAYING"
    case done = "DONE"
    case passed = "PASSED"
}

enum MatchStatus: String {
    case called = "CALLED"
    case playing = "PLAYING"
    case done = "DONE"
}
