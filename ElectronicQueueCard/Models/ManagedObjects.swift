import Foundation
import CoreData

// 手动代码生成（codeGenerationType="none"）。
// 对象类型属性（String/Date/UUID）在自动代码生成下永远是可选类型，
// 这里手写为非可选，与业务代码保持一致（必填字段在保存前均已赋值）。

@objc(Machine)
public class Machine: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Machine> {
        NSFetchRequest<Machine>(entityName: "Machine")
    }
    @NSManaged public var uid: String
    @NSManaged public var name: String
    @NSManaged public var capacity: Int16
    @NSManaged public var status: String
    @NSManaged public var currentMatchId: UUID?
}

@objc(Player)
public class Player: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Player> {
        NSFetchRequest<Player>(entityName: "Player")
    }
    @NSManaged public var uid: UUID
    @NSManaged public var nickname: String
    @NSManaged public var pinHash: String
    @NSManaged public var qrSecret: String
    @NSManaged public var avatar: String
    @NSManaged public var createdAt: Date
    @NSManaged public var lastSeenAt: Date
}

@objc(Guest)
public class Guest: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Guest> {
        NSFetchRequest<Guest>(entityName: "Guest")
    }
    @NSManaged public var uid: UUID
    @NSManaged public var nickname: String
    @NSManaged public var sessionId: UUID
    @NSManaged public var createdAt: Date
}

@objc(QueueItem)
public class QueueItem: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<QueueItem> {
        NSFetchRequest<QueueItem>(entityName: "QueueItem")
    }
    @NSManaged public var uid: UUID
    @NSManaged public var machineId: String
    @NSManaged public var type: String
    @NSManaged public var playerId1: UUID?
    @NSManaged public var guestId1: UUID?
    @NSManaged public var playerId2: UUID?
    @NSManaged public var guestId2: UUID?
    @NSManaged public var status: String
    @NSManaged public var joinedAt: Date
    @NSManaged public var confirmedAt: Date?
    @NSManaged public var matched: Bool
}

@objc(PassedItem)
public class PassedItem: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PassedItem> {
        NSFetchRequest<PassedItem>(entityName: "PassedItem")
    }
    @NSManaged public var uid: UUID
    @NSManaged public var machineId: String
    @NSManaged public var queueItemId: UUID
    @NSManaged public var passedAt: Date
    @NSManaged public var expiresAt: Date
}

@objc(Match)
public class Match: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Match> {
        NSFetchRequest<Match>(entityName: "Match")
    }
    @NSManaged public var uid: UUID
    @NSManaged public var machineId: String
    @NSManaged public var queueItemId: UUID
    @NSManaged public var status: String
    @NSManaged public var calledAt: Date
    @NSManaged public var startedAt: Date?
    @NSManaged public var endedAt: Date?
}

@objc(AdminLog)
public class AdminLog: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<AdminLog> {
        NSFetchRequest<AdminLog>(entityName: "AdminLog")
    }
    @NSManaged public var uid: UUID
    @NSManaged public var action: String
    @NSManaged public var targetId: UUID?
    @NSManaged public var timestamp: Date
}
