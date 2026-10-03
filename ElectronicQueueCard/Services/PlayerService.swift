import Foundation
import CoreData

/// 业务错误，携带可展示的中文信息。
struct ServiceError: Error {
    let message: String
}

/// 注册玩家：昵称 + 头像 + PIN，生成专属二维码。
struct PlayerService {
    let context: NSManagedObjectContext

    func register(nickname: String, pin: String) -> Result<Player, ServiceError> {
        let normalized = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return .failure(ServiceError(message: "昵称不能为空")) }
        let digits = CharacterSet.decimalDigits
        guard pin.count >= 4, pin.count <= 6,
              pin.rangeOfCharacter(from: digits.inverted) == nil else {
            return .failure(ServiceError(message: "PIN 需为 4-6 位数字"))
        }
        guard find(nickname: normalized) == nil else { return .failure(ServiceError(message: "昵称已被占用，请换一个")) }

        let player = Player(context: context)
        player.uid = UUID()
        player.nickname = normalized
        player.pinHash = PINHasher.hash(pin)
        player.qrSecret = UUID().uuidString
        player.avatar = ""
        player.createdAt = Date()
        player.lastSeenAt = Date()
        try? context.save()
        return .success(player)
    }

    func find(nickname: String) -> Player? {
        let req: NSFetchRequest<Player> = Player.fetchRequest()
        req.predicate = NSPredicate(format: "nickname ==[c] %@",
                                    nickname.trimmingCharacters(in: .whitespacesAndNewlines))
        return try? context.fetch(req).first
    }

    func find(qrSecret: String) -> Player? {
        let req: NSFetchRequest<Player> = Player.fetchRequest()
        req.predicate = NSPredicate(format: "qrSecret == %@", qrSecret)
        guard let p = try? context.fetch(req).first else { return nil }
        p.lastSeenAt = Date()
        try? context.save()
        return p
    }

    func verify(pin: String, for player: Player) -> Bool {
        return player.pinHash == PINHasher.hash(pin)
    }

    func login(nickname: String, pin: String) -> Result<Player, ServiceError> {
        guard let p = find(nickname: nickname) else { return .failure(ServiceError(message: "未找到该昵称")) }
        guard verify(pin: pin, for: p) else { return .failure(ServiceError(message: "PIN 错误")) }
        p.lastSeenAt = Date()
        try? context.save()
        return .success(p)
    }

    func recoverQR(nickname: String, pin: String) -> Result<Player, ServiceError> {
        return login(nickname: nickname, pin: pin)
    }

    func delete(_ player: Player) {
        context.delete(player)
        try? context.save()
    }

    func rename(_ player: Player, nickname: String) -> Result<Player, ServiceError> {
        let normalized = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return .failure(ServiceError(message: "昵称不能为空")) }
        if normalized != player.nickname, find(nickname: normalized) != nil {
            return .failure(ServiceError(message: "昵称已被占用"))
        }
        player.nickname = normalized
        try? context.save()
        return .success(player)
    }

    func changePin(_ player: Player, newPin: String) -> Result<Player, ServiceError> {
        let digits = CharacterSet.decimalDigits
        guard newPin.count >= 4, newPin.count <= 6,
              newPin.rangeOfCharacter(from: digits.inverted) == nil else {
            return .failure(ServiceError(message: "PIN 需为 4-6 位数字"))
        }
        player.pinHash = PINHasher.hash(newPin)
        try? context.save()
        return .success(player)
    }
}
