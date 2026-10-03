import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "QueueKiosk")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        syncMachines()
    }

    /// 按当前机台数量同步机台（增删到一致）。
    func syncMachines() {
        let context = container.viewContext
        let ids = MachineConfig.ids
        let fetch: NSFetchRequest<Machine> = Machine.fetchRequest()
        let existing = (try? context.fetch(fetch)) ?? []
        let existingIds = Set(existing.map { $0.uid })

        for m in existing where !ids.contains(m.uid) {
            context.delete(m)
        }
        for id in ids where !existingIds.contains(id) {
            let machine = Machine(context: context)
            machine.uid = id
            machine.name = MachineConfig.defaultName(for: id)
            machine.capacity = 2
            machine.status = MachineStatus.idle.rawValue
        }
        try? context.save()
    }
}
