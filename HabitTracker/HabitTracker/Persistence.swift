import CoreData

final class PersistenceController: ObservableObject {
    static let shared = PersistenceController()

    let container: NSPersistentContainer
    @Published private(set) var loadErrorMessage: String?

    func dismissLoadError() {
        loadErrorMessage = nil
    }

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "HabitTracker")
        container.persistentStoreDescriptions.forEach { description in
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { [weak self] _, error in
            if let error {
                let message = "Your data store could not be opened. \(error.localizedDescription)"
                DispatchQueue.main.async {
                    self?.loadErrorMessage = message
                }
            } else if !inMemory {
                self?.prepareLegacyRecords()
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    private func prepareLegacyRecords() {
        let context = container.viewContext
        context.perform { [weak self] in
            do {
                let habits = try context.fetch(Habit.fetchRequest())
                for habit in habits {
                    if habit.id == nil { habit.id = UUID() }
                    if habit.createdAt == nil { habit.createdAt = habit.lastDone ?? Date() }
                    if habit.updatedAt == nil { habit.updatedAt = habit.createdAt }
                    if habit.iconName?.isEmpty != false { habit.iconName = "checkmark" }
                    if habit.tintHex?.isEmpty != false { habit.tintHex = "#5B7CFA" }
                    if habit.scheduleType?.isEmpty != false { habit.schedule = .daily }
                    if habit.scheduledWeekdays == 0 { habit.weekdays = .all }
                    if habit.goalType?.isEmpty != false { habit.goal = .checkIn }
                    if habit.targetCount < 1 { habit.targetCount = 1 }
                    if habit.scheduleTarget < 1 { habit.scheduleTarget = 1 }
                    if habit.timeOfDay?.isEmpty != false { habit.preferredTime = .anytime }
                }

                let completions = try context.fetch(Completion.fetchRequest())
                for completion in completions {
                    if completion.id == nil { completion.id = UUID() }
                    if completion.createdAt == nil { completion.createdAt = completion.date ?? Date() }
                    if completion.state?.isEmpty != false { completion.state = "completed" }
                    if completion.value <= 0 { completion.value = 1 }
                }

                if context.hasChanges { try context.save() }
            } catch {
                context.rollback()
                DispatchQueue.main.async {
                    self?.loadErrorMessage = "Your data opened, but legacy records could not be prepared. \(error.localizedDescription)"
                }
            }
        }
    }

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let ctx = result.container.viewContext
        for i in 1...5 {
            let h = Habit(context: ctx)
            h.name = "Sample \(i)"
            h.lastDone = Date()
        }
        do {
            try ctx.save()
        } catch {
            assertionFailure("Preview store failed to save: \(error)")
        }
        return result
    }()
}
