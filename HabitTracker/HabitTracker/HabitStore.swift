import CoreData
import Foundation

enum HabitStoreError: LocalizedError {
    case emptyName

    var errorDescription: String? {
        switch self {
        case .emptyName:
            "A habit needs a name."
        }
    }
}

struct HabitDraft {
    var name = ""
    var iconName = "checkmark"
    var tintHex = "#5B7CFA"
    var schedule: HabitScheduleType = .daily
    var weekdays: HabitWeekdays = .all
    var scheduleTarget: Int16 = 1
    var goal: HabitGoalType = .checkIn
    var targetCount: Int32 = 1
    var unitName = ""
    var preferredTime: HabitTimeOfDay = .anytime
    var reminderEnabled = false
    var reminderTime = Date()
    var notes = ""
}

@MainActor
enum HabitStore {
    @discardableResult
    static func createHabit(named rawName: String, in context: NSManagedObjectContext) throws -> Habit {
        var draft = HabitDraft()
        draft.name = rawName
        return try save(draft, in: context)
    }

    @discardableResult
    static func save(
        _ draft: HabitDraft,
        editing existingHabit: Habit? = nil,
        in context: NSManagedObjectContext
    ) throws -> Habit {
        let habit = existingHabit ?? Habit(context: context)
        try configure(habit, with: draft)
        try save(context)
        return habit
    }

    @discardableResult
    static func createProgram(
        drafts: [HabitDraft],
        programTitle: String,
        durationDays: Int,
        in context: NSManagedObjectContext,
        calendar: Calendar = .current
    ) throws -> [Habit] {
        guard !drafts.isEmpty else { return [] }
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: max(1, durationDays) - 1, to: start)
        var created: [Habit] = []
        do {
            for draft in drafts {
                let habit = Habit(context: context)
                try configure(habit, with: draft)
                habit.startDate = start
                habit.endDate = end
                let detail = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
                habit.notes = detail.isEmpty ? "Part of \(programTitle)." : "\(detail)\n\nPart of \(programTitle)."
                created.append(habit)
            }
            try save(context)
            return created
        } catch {
            created.forEach { if !$0.isDeleted { context.delete($0) } }
            context.rollback()
            throw error
        }
    }

    @discardableResult
    static func toggleCompletion(
        for habit: Habit,
        on date: Date = Date(),
        calendar: Calendar = .current,
        in context: NSManagedObjectContext
    ) throws -> Bool {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return false }

        let request: NSFetchRequest<Completion> = Completion.fetchRequest()
        request.predicate = NSPredicate(
            format: "habit == %@ AND date >= %@ AND date < %@",
            habit,
            start as NSDate,
            end as NSDate
        )

        let matches = try context.fetch(request)
        let isNowComplete: Bool
        if matches.isEmpty {
            let completion = Completion(context: context)
            completion.id = UUID()
            completion.createdAt = Date()
            completion.date = start
            completion.habit = habit
            completion.state = "completed"
            completion.value = 1
            isNowComplete = true
        } else {
            matches.forEach(context.delete)
            isNowComplete = false
        }

        updateLastDone(for: habit, excludingDeletedObjectsIn: context)
        habit.updatedAt = Date()
        try save(context)
        return isNowComplete
    }

    @discardableResult
    static func recordCompletion(
        for habit: Habit,
        on date: Date = Date(),
        value: Double,
        note: String,
        calendar: Calendar = .current,
        in context: NSManagedObjectContext
    ) throws -> Completion {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            throw CocoaError(.validationMissingMandatoryProperty)
        }

        let request: NSFetchRequest<Completion> = Completion.fetchRequest()
        request.predicate = NSPredicate(
            format: "habit == %@ AND date >= %@ AND date < %@",
            habit,
            start as NSDate,
            end as NSDate
        )
        let matches = try context.fetch(request)
        let completion = matches.first ?? Completion(context: context)
        matches.dropFirst().forEach(context.delete)
        if completion.id == nil { completion.id = UUID() }
        if completion.createdAt == nil { completion.createdAt = Date() }
        completion.date = start
        completion.habit = habit
        completion.state = "completed"
        completion.value = max(0, value)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        completion.note = trimmedNote.isEmpty ? nil : trimmedNote
        habit.updatedAt = Date()
        updateLastDone(for: habit, excludingDeletedObjectsIn: context)
        habit.lastDone = max(habit.lastDone ?? start, start)
        try save(context)
        return completion
    }

    static func delete(_ completion: Completion, in context: NSManagedObjectContext) throws {
        let habit = completion.habit
        context.delete(completion)
        if let habit {
            updateLastDone(for: habit, excludingDeletedObjectsIn: context)
        }
        try save(context)
    }

    static func delete(_ habit: Habit, in context: NSManagedObjectContext) throws {
        try delete([habit], in: context)
    }

    static func delete(_ habits: [Habit], in context: NSManagedObjectContext) throws {
        habits.forEach(context.delete)
        try save(context)
    }

    static func save(_ context: NSManagedObjectContext) throws {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func configure(_ habit: Habit, with draft: HabitDraft) throws {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw HabitStoreError.emptyName }
        let now = Date()
        habit.name = name
        if habit.id == nil { habit.id = UUID() }
        if habit.createdAt == nil { habit.createdAt = now }
        habit.updatedAt = now
        habit.iconName = draft.iconName
        habit.tintHex = draft.tintHex
        habit.schedule = draft.schedule
        habit.weekdays = draft.schedule == .daily ? .all : draft.weekdays
        habit.scheduleTarget = max(1, min(7, draft.scheduleTarget))
        habit.goal = draft.goal
        habit.targetCount = max(1, draft.targetCount)
        habit.unitName = draft.unitName.trimmingCharacters(in: .whitespacesAndNewlines)
        habit.preferredTime = draft.preferredTime
        habit.reminderEnabled = draft.reminderEnabled
        habit.reminderTime = draft.reminderEnabled ? draft.reminderTime : nil
        habit.notes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if habit.startDate == nil { habit.startDate = Calendar.current.startOfDay(for: now) }
    }

    private static func updateLastDone(
        for habit: Habit,
        excludingDeletedObjectsIn context: NSManagedObjectContext
    ) {
        habit.lastDone = habit.validCompletions
            .filter { !$0.isDeleted && $0.managedObjectContext === context }
            .compactMap(\.date)
            .max()
    }
}

extension Habit {
    var displayName: String {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Untitled Habit" : trimmed
    }

    var validCompletions: [Completion] {
        (completions as? Set<Completion> ?? []).filter { $0.date != nil }
    }

    var completionDates: [Date] {
        validCompletions.compactMap(\.date)
    }

    var achievedCompletionDates: [Date] {
        validCompletions.compactMap { completion in
            guard let date = completion.date else { return nil }
            switch goal {
            case .count, .duration:
                return completion.value >= Double(max(1, targetCount)) ? date : nil
            case .checkIn, .avoidance:
                return completion.state == "missed" ? nil : date
            }
        }
    }

    func completion(on date: Date, calendar: Calendar = .current) -> Completion? {
        validCompletions.first { completion in
            guard let completionDate = completion.date else { return false }
            return calendar.isDate(completionDate, inSameDayAs: date)
        }
    }

    func isComplete(on date: Date, calendar: Calendar = .current) -> Bool {
        guard let completion = completion(on: date, calendar: calendar) else { return false }
        switch goal {
        case .count, .duration:
            return completion.value >= Double(max(1, targetCount))
        case .checkIn, .avoidance:
            return completion.state != "missed"
        }
    }
}
