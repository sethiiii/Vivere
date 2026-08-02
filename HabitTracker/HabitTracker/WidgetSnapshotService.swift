import CoreData
import Foundation
import WidgetKit

struct HabitWidgetSnapshot: Codable, Equatable {
    let generatedAt: Date
    let completedCount: Int
    let totalCount: Int
    let habits: [HabitWidgetItem]
}

struct HabitWidgetItem: Codable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let iconName: String
    let tintHex: String
    let isComplete: Bool
}

@MainActor
enum WidgetSnapshotService {
    static let appGroupIdentifier = "group.com.sethi.HabitTracker"
    static let snapshotKey = "widget.today.snapshot.v1"

    static func refresh(from context: NSManagedObjectContext, now: Date = .now) {
        let request: NSFetchRequest<Habit> = Habit.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Habit.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \Habit.name, ascending: true)
        ]
        request.predicate = NSPredicate(format: "isArchived == NO AND isPaused == NO")

        guard let fetched = try? context.fetch(request) else { return }
        let scheduled = fetched.filter { $0.isScheduled(on: now) }
        let items = scheduled.map { habit in
            HabitWidgetItem(
                id: habit.id ?? UUID(),
                name: habit.displayName,
                iconName: habit.displayIcon,
                tintHex: habit.tintHex ?? "5B5BD6",
                isComplete: habit.isComplete(on: now)
            )
        }
        let snapshot = HabitWidgetSnapshot(
            generatedAt: now,
            completedCount: items.lazy.filter(\.isComplete).count,
            totalCount: items.count,
            habits: Array(items.prefix(4))
        )

        guard
            let defaults = UserDefaults(suiteName: appGroupIdentifier),
            let data = try? JSONEncoder().encode(snapshot)
        else { return }

        defaults.set(data, forKey: snapshotKey)
        WidgetCenter.shared.reloadTimelines(ofKind: "HabitTrackerWidget")
    }
}
