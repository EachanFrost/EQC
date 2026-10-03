import SwiftUI

/// 全屏路由，统一用一个 fullScreenCover 承载。
enum KioskRoute: Identifiable {
    case register
    case guest
    case pair(QueueItem)
    case joinGroup(QueueItem)

    var id: String {
        switch self {
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
    @State private var showLogin = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    queueManager.toggleVoice()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: queueManager.voiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        Text(queueManager.voiceEnabled ? "语音开" : "语音关")
                    }
                    .font(.footnote)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(Capsule())
                }
                Spacer()
            }
            .padding(.horizontal, 12).padding(.top, 8)

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
                loginAction: { showLogin = true },
                guestAction: { route = .guest },
                registerAction: { route = .register }
            )
        }
        .fullScreenCover(item: $route) { r in
            switch r {
            case .register: RegisterView()
            case .guest: GuestJoinView()
            case .pair(let item): IdentifyView(item: item, mode: .pair)
            case .joinGroup(let item): IdentifyView(item: item, mode: .joinGroup)
            }
        }
        .fullScreenCover(isPresented: $showLogin) { LoginView().background(ClearBackgroundView()) }
        .statusBar(hidden: true)
    }
}
