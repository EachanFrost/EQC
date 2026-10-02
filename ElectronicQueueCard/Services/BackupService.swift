import Foundation
import CoreData

/// 全量导出为 JSON，写入 App 的 Documents/Backups 目录（配合 UIFileSharingEnabled 可从文件 App 取走）。
struct BackupService {
    let context: NSManagedObjectContext

    struct Payload: Codable {
        var exportedAt: Date
        var machines: [MachineDTO]
        var players: [PlayerDTO]
        var guests: [GuestDTO]
        var queueItems: [QueueItemDTO]
        var passedItems: [PassedItemDTO]
        var matches: [MatchDTO]
        var adminLogs: [AdminLogDTO]
    }

    struct MachineDTO: Codable {
        var id: String; var name: String; var capacity: Int16; var status: String; var currentMatchId: UUID?
    }
    struct PlayerDTO: Codable {
        var id: UUID; var nickname: String; var pinHash: String; var qrSecret: String; var avatar: String; var createdAt: Date; var lastSeenAt: Date
    }
    struct GuestDTO: Codable {
        var id: UUID; var nickname: String; var sessionId: UUID; var createdAt: Date
    }
    struct QueueItemDTO: Codable {
        var id: UUID; var machineId: String; var type: String; var playerId1: UUID?; var guestId1: UUID?; var playerId2: UUID?; var guestId2: UUID?; var status: String; var joinedAt: Date; var confirmedAt: Date?; var matched: Bool
    }
    struct PassedItemDTO: Codable {
        var id: UUID; var machineId: String; var queueItemId: UUID; var passedAt: Date; var expiresAt: Date
    }
    struct MatchDTO: Codable {
        var id: UUID; var machineId: String; var queueItemId: UUID; var status: String; var calledAt: Date; var startedAt: Date?; var endedAt: Date?
    }
    struct AdminLogDTO: Codable {
        var id: UUID; var action: String; var targetId: UUID?; var timestamp: Date
    }

    func exportJSON() throws -> URL {
        let machines: [Machine] = fetchAll(Machine.fetchRequest())
        let players: [Player] = fetchAll(Player.fetchRequest())
        let guests: [Guest] = fetchAll(Guest.fetchRequest())
        let queueItems: [QueueItem] = fetchAll(QueueItem.fetchRequest())
        let passedItems: [PassedItem] = fetchAll(PassedItem.fetchRequest())
        let matches: [Match] = fetchAll(Match.fetchRequest())
        let adminLogs: [AdminLog] = fetchAll(AdminLog.fetchRequest())

        let payload = Payload(
            exportedAt: Date(),
            machines: machines.map {
                MachineDTO(id: $0.uid, name: $0.name, capacity: $0.capacity, status: $0.status, currentMatchId: $0.currentMatchId)
            },
            players: players.map {
                PlayerDTO(id: $0.uid, nickname: $0.nickname, pinHash: $0.pinHash, qrSecret: $0.qrSecret, avatar: $0.avatar, createdAt: $0.createdAt, lastSeenAt: $0.lastSeenAt)
            },
            guests: guests.map {
                GuestDTO(id: $0.uid, nickname: $0.nickname, sessionId: $0.sessionId, createdAt: $0.createdAt)
            },
            queueItems: queueItems.map {
                QueueItemDTO(id: $0.uid, machineId: $0.machineId, type: $0.type, playerId1: $0.playerId1, guestId1: $0.guestId1, playerId2: $0.playerId2, guestId2: $0.guestId2, status: $0.status, joinedAt: $0.joinedAt, confirmedAt: $0.confirmedAt, matched: $0.matched)
            },
            passedItems: passedItems.map {
                PassedItemDTO(id: $0.uid, machineId: $0.machineId, queueItemId: $0.queueItemId, passedAt: $0.passedAt, expiresAt: $0.expiresAt)
            },
            matches: matches.map {
                MatchDTO(id: $0.uid, machineId: $0.machineId, queueItemId: $0.queueItemId, status: $0.status, calledAt: $0.calledAt, startedAt: $0.startedAt, endedAt: $0.endedAt)
            },
            adminLogs: adminLogs.map {
                AdminLogDTO(id: $0.uid, action: $0.action, targetId: $0.targetId, timestamp: $0.timestamp)
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)

        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Backups", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let url = dir.appendingPathComponent("queue-backup-\(formatter.string(from: Date())).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    private func fetchAll<T: NSManagedObject>(_ request: NSFetchRequest<T>) -> [T] {
        (try? context.fetch(request)) ?? []
    }
}
