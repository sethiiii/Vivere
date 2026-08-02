import CoreData
import SwiftUI
import UniformTypeIdentifiers

struct HabitBackup: Codable {
    let formatVersion: Int
    let exportedAt: Date
    let habits: [HabitRecord]
    let journalEntries: [JournalRecord]?

    struct HabitRecord: Codable {
        let id: UUID
        let name: String
        let lastDone: Date?
        let createdAt: Date?
        let updatedAt: Date?
        let iconName: String?
        let tintHex: String?
        let isArchived: Bool
        let isPaused: Bool
        let sortOrder: Int64
        let scheduleType: String?
        let scheduleTarget: Int16
        let scheduledWeekdays: Int16
        let goalType: String?
        let targetCount: Int32
        let unitName: String?
        let reminderEnabled: Bool
        let reminderTime: Date?
        let notes: String?
        let startDate: Date?
        let endDate: Date?
        let timeOfDay: String?
        let completions: [CompletionRecord]
    }

    struct CompletionRecord: Codable {
        let id: UUID
        let date: Date
        let createdAt: Date?
        let note: String?
        let state: String?
        let value: Double
    }

    struct JournalRecord: Codable {
        let id: UUID
        let date: Date
        let createdAt: Date?
        let updatedAt: Date?
        let title: String?
        let body: String?
        let gratitude: String?
        let intention: String?
        let mood: Int16
        let prompt: String?
        let quoteID: String?
        let photoData: Data?
    }
}

struct HabitBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let backup: HabitBackup

    init(backup: HabitBackup) {
        self.backup = backup
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        backup = try HabitBackupCodec.decoder.decode(HabitBackup.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try HabitBackupCodec.encoder.encode(backup))
    }
}

enum HabitBackupCodec {
    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

@MainActor
enum HabitBackupService {
    static func makeBackup(from context: NSManagedObjectContext) throws -> HabitBackup {
        let request: NSFetchRequest<Habit> = Habit.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Habit.sortOrder, ascending: true)]
        let records = try context.fetch(request).map { habit in
            HabitBackup.HabitRecord(
                id: habit.id ?? UUID(),
                name: habit.displayName,
                lastDone: habit.lastDone,
                createdAt: habit.createdAt,
                updatedAt: habit.updatedAt,
                iconName: habit.iconName,
                tintHex: habit.tintHex,
                isArchived: habit.isArchived,
                isPaused: habit.isPaused,
                sortOrder: habit.sortOrder,
                scheduleType: habit.scheduleType,
                scheduleTarget: habit.scheduleTarget,
                scheduledWeekdays: habit.scheduledWeekdays,
                goalType: habit.goalType,
                targetCount: habit.targetCount,
                unitName: habit.unitName,
                reminderEnabled: habit.reminderEnabled,
                reminderTime: habit.reminderTime,
                notes: habit.notes,
                startDate: habit.startDate,
                endDate: habit.endDate,
                timeOfDay: habit.timeOfDay,
                completions: habit.validCompletions.compactMap { completion in
                    guard let date = completion.date else { return nil }
                    return HabitBackup.CompletionRecord(
                        id: completion.id ?? UUID(),
                        date: date,
                        createdAt: completion.createdAt,
                        note: completion.note,
                        state: completion.state,
                        value: completion.value
                    )
                }
            )
        }
        let journals = try context.fetch(JournalEntry.fetchRequest()).compactMap { entry -> HabitBackup.JournalRecord? in
            guard let date = entry.date else { return nil }
            return HabitBackup.JournalRecord(
                id: entry.id ?? UUID(),
                date: date,
                createdAt: entry.createdAt,
                updatedAt: entry.updatedAt,
                title: entry.title,
                body: entry.body,
                gratitude: entry.gratitude,
                intention: entry.intention,
                mood: entry.mood,
                prompt: entry.prompt,
                quoteID: entry.quoteID,
                photoData: entry.photoData
            )
        }
        return HabitBackup(formatVersion: 1, exportedAt: Date(), habits: records, journalEntries: journals)
    }

    static func restore(_ backup: HabitBackup, into context: NSManagedObjectContext) throws -> Int {
        guard backup.formatVersion == 1 else { throw HabitBackupError.unsupportedVersion }
        let existingHabits = try context.fetch(Habit.fetchRequest())
        var habitsByID: [UUID: Habit] = [:]
        existingHabits.forEach { habit in
            if let id = habit.id { habitsByID[id] = habit }
        }
        let existingCompletions = try context.fetch(Completion.fetchRequest())
        var completionsByID: [UUID: Completion] = [:]
        existingCompletions.forEach { completion in
            if let id = completion.id { completionsByID[id] = completion }
        }

        for record in backup.habits {
            let habit = habitsByID[record.id] ?? Habit(context: context)
            habit.id = record.id
            habit.name = record.name
            habit.lastDone = record.lastDone
            habit.createdAt = record.createdAt
            habit.updatedAt = record.updatedAt
            habit.iconName = record.iconName
            habit.tintHex = record.tintHex
            habit.isArchived = record.isArchived
            habit.isPaused = record.isPaused
            habit.sortOrder = record.sortOrder
            habit.scheduleType = record.scheduleType
            habit.scheduleTarget = record.scheduleTarget
            habit.scheduledWeekdays = record.scheduledWeekdays
            habit.goalType = record.goalType
            habit.targetCount = record.targetCount
            habit.unitName = record.unitName
            habit.reminderEnabled = record.reminderEnabled
            habit.reminderTime = record.reminderTime
            habit.notes = record.notes
            habit.startDate = record.startDate
            habit.endDate = record.endDate
            habit.timeOfDay = record.timeOfDay
            habitsByID[record.id] = habit

            for completionRecord in record.completions {
                let completion = completionsByID[completionRecord.id] ?? Completion(context: context)
                completion.id = completionRecord.id
                completion.date = completionRecord.date
                completion.createdAt = completionRecord.createdAt
                completion.note = completionRecord.note
                completion.state = completionRecord.state
                completion.value = completionRecord.value
                completion.habit = habit
                completionsByID[completionRecord.id] = completion
            }
        }
        let existingJournals = try context.fetch(JournalEntry.fetchRequest())
        var journalsByID: [UUID: JournalEntry] = [:]
        existingJournals.forEach { entry in
            if let id = entry.id { journalsByID[id] = entry }
        }
        for record in backup.journalEntries ?? [] {
            let entry = journalsByID[record.id] ?? JournalEntry(context: context)
            entry.id = record.id
            entry.date = record.date
            entry.createdAt = record.createdAt
            entry.updatedAt = record.updatedAt
            entry.title = record.title
            entry.body = record.body
            entry.gratitude = record.gratitude
            entry.intention = record.intention
            entry.mood = record.mood
            entry.prompt = record.prompt
            entry.quoteID = record.quoteID
            entry.photoData = record.photoData
            journalsByID[record.id] = entry
        }
        try HabitStore.save(context)
        return backup.habits.count
    }
}

enum HabitBackupError: LocalizedError {
    case unsupportedVersion

    var errorDescription: String? {
        "This backup was created by an unsupported version of Vivere."
    }
}
