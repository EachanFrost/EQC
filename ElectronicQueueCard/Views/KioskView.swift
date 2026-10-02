import SwiftUI

/// 全屏路由，统一用一个 fullScreenCover 承载。
enum KioskRoute: Identifiable {
    case login
    case register
    case guest
    case pair(QueueItem)
    case joinGroup(QueueItem)

    var id: String {
        switch self {
        case .login: return "login"
        case .register: return "register"
        case .guest: return "guest"
        case .pair(let item): return "pair-\(item.uid.uuidString)"
        case .joinGroup(let item): return "group-\(item.uid.uuidString)"
        }
    }
}

struct KioskView: View {
    @EnvironmentObject var queueManager: QueueManager
    @State private var route: KioskRoute?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                MachineColumnView(side: .left,
                                  onPair: { route = .pair($0) },
                                  onJoinGroup: { route = .joinGroup($0) })
                MachineColumnView(side: .right,
                                  onPair: { route = .pair($0) },
                                  onJoinGroup: { route = .joinGroup($0) })
            }
            .padding(12)

            BottomBarView(
                loginAction: { route = .login },
                guestAction: { route = .guest },
                registerAction: { route = .register }
            )
        }
        .fullScreenCover(item: $route) { r in
            switch r {
            case .login: LoginView()
            case .register: RegisterView()
            case .guest: GuestJoinView()
            case .pair(let item): IdentifyView(item: item, mode: .pair)
            case .joinGroup(let item): IdentifyView(item: item, mode: .joinGroup)
            }
        }
        .statusBar(hidden: true)
    }
}
