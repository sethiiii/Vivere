import CoreData
import Foundation

extension JournalEntry {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<JournalEntry> {
        NSFetchRequest<JournalEntry>(entityName: "JournalEntry")
    }

    @NSManaged public var body: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var date: Date?
    @NSManaged public var gratitude: String?
    @NSManaged public var id: UUID?
    @NSManaged public var intention: String?
    @NSManaged public var mood: Int16
    @NSManaged public var photoData: Data?
    @NSManaged public var prompt: String?
    @NSManaged public var quoteID: String?
    @NSManaged public var title: String?
    @NSManaged public var updatedAt: Date?
}

extension JournalEntry: Identifiable {
    var displayTitle: String {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? (date?.formatted(date: .long, time: .omitted) ?? "Journal Entry") : trimmed
    }

    var previewText: String {
        let candidates = [gratitude, body, intention]
        return candidates.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? "A quiet space for your thoughts."
    }
}
