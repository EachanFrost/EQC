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
        seedMachinesIfNeeded()
    }

    private func seedMachinesIfNeeded() {
        let context = container.viewContext
        let fetch: NSFetchRequest<Machine> = Machine.fetchRequest()
        let count = (try? context.count(for: fetch)) ?? 0
        if count == 0 {
            for side in MachineSide.allCases {
                let machine = Machine(context: context)
                machine.uid = side.rawValue
                machine.name = side.displayName
                machine.capacity = 2
                machine.status = MachineStatus.idle.rawValue
            }
            try? context.save()
        }
    }
}
