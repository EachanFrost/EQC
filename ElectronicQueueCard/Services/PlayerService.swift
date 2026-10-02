import Foundation
import CoreData

/// 注册玩家：昵称 + 头像 + PIN，生成专属二维码。
struct PlayerService {
    let context: NSManagedObjectContext

    static let avatars = ["🐱", "🐶", "🐰", "🦊", "🐼", "🐯", "🦁", "🐸", "🐵", "🐙", "🦄", "🐲", "🐳", "🦉", "🐢", "🦖"]

    func register(nickname: String, pin: String, avatar: String) -> Result<Player, String> {
        let normalized = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return .failure("昵称不能为空") }
        let digits = CharacterSet.decimalDigits
        guard pin.count >= 4, pin.count <= 6,
              pin.rangeOfCharacter(from: digits.inverted) == nil else {
            return .failure("PIN 需为 4-6 位数字")
        }
        guard find(nickname: normalized) == nil else { return .failure("昵称已被占用，请换一个") }

        let player = Player(context: context)
        player.uid = UUID()
        player.nickname = normalized
        player.pinHash = PINHasher.hash(pin)
        player.qrSecret = UUID().uuidString
        player.avatar = avatar
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

    func login(nickname: String, pin: String) -> Result<Player, String> {
        guard let p = find(nickname: nickname) else { return .failure("未找到该昵称") }
        guard verify(pin: pin, for: p) else { return .failure("PIN 错误") }
        p.lastSeenAt = Date()
        try? context.save()
        return .success(p)
    }

    func recoverQR(nickname: String, pin: String) -> Result<Player, String> {
        return login(nickname: nickname, pin: pin)
    }
}
