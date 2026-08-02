import AppIntents
import CoreData
import Foundation

struct HabitShortcutEntity: AppEntity, Identifiable, Hashable, Sendable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Habit")
    static let defaultQuery = HabitShortcutQuery()

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct HabitShortcutQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [HabitShortcutEntity] {
        try await HabitShortcutStore.entities(ids: Set(identifiers))
    }

    func entities(matching string: String) async throws -> [HabitShortcutEntity] {
        try await HabitShortcutStore.entities(matching: string)
    }

    func suggestedEntities() async throws -> [HabitShortcutEntity] {
        try await HabitShortcutStore.entities()
    }
}

struct CompleteHabitIntent: AppIntent {
    static let title: LocalizedStringResource = "Complete Habit"
    static let description = IntentDescription("Mark one of your habits complete for today.")
    static let openAppWhenRun = false

    @Parameter(title: "Habit")
    var habit: HabitShortcutEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let name = try await HabitShortcutStore.complete(id: habit.id)
        return .result(dialog: "Completed \(name) for today.")
    }
}

struct HabitTrackerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CompleteHabitIntent(),
            phrases: [
                "Complete a habit in \(.applicationName)",
                "Check off a habit in \(.applicationName)"
            ],
            shortTitle: "Complete Habit",
            systemImageName: "checkmark.circle"
        )
    }
}

private enum HabitShortcutError: LocalizedError {
    case habitNotFound

    var errorDescription: String? {
        "That habit is no longer available. Open Vivere to choose another one."
    }
}

private enum HabitShortcutStore {
    static func entities(ids: Set<UUID>? = nil, matching search: String? = nil) async throws -> [HabitShortcutEntity] {
        let context = PersistenceController.shared.container.newBackgroundContext()
        return try await context.perform {
            let request: NSFetchRequest<Habit> = Habit.fetchRequest()
            var predicates = [NSPredicate(format: "isArchived == NO")]
            if let ids { predicates.append(NSPredicate(format: "id IN %@", Array(ids))) }
            if let search, !search.isEmpty {
                predicates.append(NSPredicate(format: "name CONTAINS[cd] %@", search))
            }
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))]
            request.fetchLimit = 100
            return try context.fetch(request).compactMap { habit in
                guard let id = habit.id else { return nil }
                return HabitShortcutEntity(id: id, name: habit.displayName)
            }
        }
    }

    static func complete(id: UUID, date: Date = Date(), calendar: Calendar = .current) async throws -> String {
        let context = PersistenceController.shared.container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        return try await context.perform {
            let habitRequest: NSFetchRequest<Habit> = Habit.fetchRequest()
            habitRequest.predicate = NSPredicate(format: "id == %@ AND isArchived == NO", id as CVarArg)
            habitRequest.fetchLimit = 1
            guard let habit = try context.fetch(habitRequest).first else {
                throw HabitShortcutError.habitNotFound
            }

            let start = calendar.startOfDay(for: date)
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
                throw CocoaError(.validationMissingMandatoryProperty)
            }
            let completionRequest: NSFetchRequest<Completion> = Completion.fetchRequest()
            completionRequest.predicate = NSPredicate(
                format: "habit == %@ AND date >= %@ AND date < %@",
                habit,
                start as NSDate,
                end as NSDate
            )
            let matches = try context.fetch(completionRequest)
            let completion = matches.first ?? Completion(context: context)
            matches.dropFirst().forEach(context.delete)
            if completion.id == nil { completion.id = UUID() }
            if completion.createdAt == nil { completion.createdAt = date }
            completion.date = start
            completion.habit = habit
            completion.state = "completed"
            completion.value = habit.goal == .count || habit.goal == .duration
                ? Double(max(1, habit.targetCount))
                : 1
            habit.lastDone = max(habit.lastDone ?? start, start)
            habit.updatedAt = date
            if context.hasChanges { try context.save() }
            return habit.displayName
        }
    }
}
