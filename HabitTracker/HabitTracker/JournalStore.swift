import CoreData
import Foundation

struct JournalDraft {
    var date = Date()
    var title = ""
    var body = ""
    var gratitude = ""
    var intention = ""
    var mood: Int16 = 3
    var prompt = ""
    var quoteID: String?
    var photoData: Data?
}

enum JournalStoreError: LocalizedError {
    case dateAlreadyHasEntry

    var errorDescription: String? {
        "There is already a journal entry for that date."
    }
}

@MainActor
enum JournalStore {
    static func entry(on date: Date, in context: NSManagedObjectContext) throws -> JournalEntry? {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        let request: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", start as NSDate, end as NSDate)
        return try context.fetch(request).first
    }

    @discardableResult
    static func save(_ draft: JournalDraft, editing existing: JournalEntry? = nil, in context: NSManagedObjectContext) throws -> JournalEntry {
        let matchingEntry = try entry(on: draft.date, in: context)
        if let existing, let matchingEntry, existing.objectID != matchingEntry.objectID {
            throw JournalStoreError.dateAlreadyHasEntry
        }
        let entry = existing ?? matchingEntry ?? JournalEntry(context: context)
        let now = Date()
        if entry.id == nil { entry.id = UUID() }
        if entry.createdAt == nil { entry.createdAt = now }
        entry.updatedAt = now
        entry.date = Calendar.current.startOfDay(for: draft.date)
        entry.title = cleaned(draft.title)
        entry.body = cleaned(draft.body)
        entry.gratitude = cleaned(draft.gratitude)
        entry.intention = cleaned(draft.intention)
        entry.mood = max(1, min(5, draft.mood))
        entry.prompt = cleaned(draft.prompt)
        entry.quoteID = draft.quoteID
        entry.photoData = draft.photoData
        try HabitStore.save(context)
        return entry
    }

    static func delete(_ entry: JournalEntry, in context: NSManagedObjectContext) throws {
        context.delete(entry)
        try HabitStore.save(context)
    }

    private static func cleaned(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
