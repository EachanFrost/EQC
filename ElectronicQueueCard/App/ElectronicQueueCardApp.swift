import SwiftUI

@main
struct ElectronicQueueCardApp: App {
    @StateObject private var queueManager: QueueManager

    init() {
        let context = PersistenceController.shared.container.viewContext
        _queueManager = StateObject(wrappedValue: QueueManager(context: context))
    }

    var body: some Scene {
        WindowGroup {
            KioskView()
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                .environmentObject(queueManager)
        }
    }
}
