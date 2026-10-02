import Foundation

/// 左右两台机台，完全独立。
enum MachineSide: String, CaseIterable, Identifiable {
    case left = "LEFT"
    case right = "RIGHT"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .left: return "左机"
        case .right: return "右机"
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

enum QueueItemType: String, CaseIterable {
    case solo = "SOLO"
    case duoMatch = "DUO_MATCH"
    case duoGroup = "DUO_GROUP"
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
