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
    @State private var showUserManagement = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
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

                Menu {
                    ForEach(1...MachineConfig.maxCount, id: \.self) { n in
                        Button("\(n) 台机台") { queueManager.setMachineCount(n) }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.grid.2x2")
                        Text("机台数 \(queueManager.machineCount)")
                    }
                    .font(.footnote)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(Capsule())
                }

                Button {
                    showUserManagement = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2")
                        Text("用户管理")
                    }
                    .font(.footnote)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(Capsule())
                }

                Spacer()
            }
            .padding(.horizontal, 12).padding(.top, 8)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 380), spacing: 12)], spacing: 12) {
                    ForEach(queueManager.machineIds, id: \.self) { side in
                        MachineColumnView(side: side,
                                          onPair: { route = .pair($0) },
                                          onJoinGroup: { route = .joinGroup($0) })
                            .frame(minHeight: 460)
                    }
                }
                .padding(12)
            }

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
        .sheet(isPresented: $showUserManagement) { UserManagementView() }
        .statusBar(hidden: true)
    }
}
