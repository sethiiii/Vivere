@preconcurrency import CoreData
import Foundation
import Testing
@testable import HabitTracker

struct HabitStatisticsTests {
    @Test func versionOneStoreMigratesToCurrentModelWithoutLosingHistory() async throws {
        let bundle = Bundle(for: Habit.self)
        let modelDirectory = try #require(bundle.url(forResource: "HabitTracker", withExtension: "momd"))
        let versionOneURL = modelDirectory.appendingPathComponent("HabitTracker.mom")
        let currentURL = modelDirectory.appendingPathComponent("HabitTracker 3.mom")
        let versionOneModel = try #require(NSManagedObjectModel(contentsOf: versionOneURL))
        let currentModel = try #require(NSManagedObjectModel(contentsOf: currentURL))

        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HabitTrackerMigration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        let storeURL = temporaryDirectory.appendingPathComponent("Legacy.sqlite")

        let legacyCoordinator = NSPersistentStoreCoordinator(managedObjectModel: versionOneModel)
        let legacyStore = try legacyCoordinator.addPersistentStore(type: .sqlite, at: storeURL)
        let legacyContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        legacyContext.persistentStoreCoordinator = legacyCoordinator
        let completionDate = Date(timeIntervalSince1970: 1_700_000_000)
        try legacyContext.performAndWait {
            let habit = NSEntityDescription.insertNewObject(forEntityName: "Habit", into: legacyContext)
            habit.setValue("Preserved Habit", forKey: "name")
            habit.setValue(completionDate, forKey: "lastDone")
            let completion = NSEntityDescription.insertNewObject(forEntityName: "Completion", into: legacyContext)
            completion.setValue(completionDate, forKey: "date")
            completion.setValue(habit, forKey: "habit")
            try legacyContext.save()
        }
        try legacyCoordinator.remove(legacyStore)

        let migratedContainer = NSPersistentContainer(name: "HabitTracker", managedObjectModel: currentModel)
        let description = NSPersistentStoreDescription(url: storeURL)
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        migratedContainer.persistentStoreDescriptions = [description]
        try await loadPersistentStores(for: migratedContainer)

        let migratedContext = migratedContainer.viewContext
        let habits = try migratedContext.fetch(Habit.fetchRequest())
        let completions = try migratedContext.fetch(Completion.fetchRequest())
        #expect(habits.count == 1)
        #expect(habits.first?.name == "Preserved Habit")
        #expect(completions.count == 1)
        #expect(completions.first?.date == completionDate)
        #expect(completions.first?.habit === habits.first)
    }

    @Test func selectedDayReminderUsesOnlyScheduledWeekdays() {
        let weekdays: HabitWeekdays = [.monday, .wednesday, .friday]

        #expect(NotificationManager.notificationWeekdays(for: .selectedDays, weekdays: weekdays) == [2, 4, 6])
        #expect(NotificationManager.notificationWeekdays(for: .daily, weekdays: weekdays).isEmpty)
        #expect(NotificationManager.requestIdentifiers(for: "habit").count == 8)
        #expect(NotificationManager.requestIdentifiers(for: "habit").contains("habit.weekday.6"))
    }

    @Test func quoteFavoritesToggleAndRoundTrip() {
        var stored = QuoteFavorites.toggle("aurelius-1", in: "")
        stored = QuoteFavorites.toggle("seneca-1", in: stored)
        #expect(QuoteFavorites.decode(stored) == ["aurelius-1", "seneca-1"])

        stored = QuoteFavorites.toggle("aurelius-1", in: stored)
        #expect(QuoteFavorites.decode(stored) == ["seneca-1"])
    }

    @Test func dailyQuotesUseEveryQuoteBeforeRepeating() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)))
        let quotes = try (0..<MotivationalQuote.library.count).map { offset in
            let date = try #require(calendar.date(byAdding: .day, value: offset, to: start))
            return MotivationalQuote.daily(category: .all, on: date, calendar: calendar)
        }
        let loopDate = try #require(
            calendar.date(byAdding: .day, value: MotivationalQuote.library.count, to: start)
        )

        #expect(Set(quotes.map(\.id)).count == MotivationalQuote.library.count)
        #expect(MotivationalQuote.daily(category: .all, on: loopDate, calendar: calendar).id == quotes.first?.id)
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @Test func duplicateCheckInsCountOnce() {
        let first = date(2026, 8, 1, hour: 8)
        let duplicate = date(2026, 8, 1, hour: 20)
        let statistics = HabitStatistics(
            completionDates: [first, duplicate],
            relativeTo: date(2026, 8, 2),
            calendar: calendar
        )

        #expect(statistics.totalCompletions == 1)
        #expect(statistics.consistencyPercentage == 50)
    }

    @Test func currentStreakRemainsActiveThroughYesterday() {
        let statistics = HabitStatistics(
            completionDates: [date(2026, 7, 30), date(2026, 7, 31), date(2026, 8, 1)],
            relativeTo: date(2026, 8, 2),
            calendar: calendar
        )

        #expect(statistics.currentStreak == 3)
        #expect(statistics.longestStreak == 3)
    }

    @Test func brokenRunUsesLatestAndLongestStreaks() {
        let statistics = HabitStatistics(
            completionDates: [
                date(2026, 7, 25), date(2026, 7, 26), date(2026, 7, 27),
                date(2026, 8, 1), date(2026, 8, 2)
            ],
            relativeTo: date(2026, 8, 2),
            calendar: calendar
        )

        #expect(statistics.currentStreak == 2)
        #expect(statistics.longestStreak == 3)
    }

    @Test func futureDatesAreExcluded() {
        let statistics = HabitStatistics(
            completionDates: [date(2026, 8, 2), date(2026, 8, 3)],
            relativeTo: date(2026, 8, 2),
            calendar: calendar
        )

        #expect(statistics.totalCompletions == 1)
        #expect(statistics.consistencyPercentage == 100)
    }

    @Test func monthGridHonorsConfiguredFirstWeekday() throws {
        var mondayFirst = calendar
        mondayFirst.firstWeekday = 2
        let grid = try #require(MonthGrid(month: date(2026, 8, 2), calendar: mondayFirst))

        #expect(grid.leadingBlankCount == 5)
        #expect(grid.dates.count == 31)
        #expect(grid.weekdaySymbols.first == "Mon")
    }
}

private func loadPersistentStores(for container: NSPersistentContainer) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        container.loadPersistentStores { _, error in
            if let error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume(returning: ())
            }
        }
    }
}

@MainActor
struct HabitStoreTests {
    private func makeStore() -> (PersistenceController, NSManagedObjectContext) {
        let persistence = PersistenceController(inMemory: true)
        return (persistence, persistence.container.viewContext)
    }

    @Test func toggleNormalizesDateAndPreventsDuplicateDays() throws {
        let (_, context) = makeStore()
        let habit = try HabitStore.createHabit(named: "  Read  ", in: context)
        let date = Date(timeIntervalSince1970: 1_785_652_800)

        let completed = try HabitStore.toggleCompletion(for: habit, on: date, in: context)

        #expect(completed)
        #expect(habit.name == "Read")
        #expect(habit.validCompletions.count == 1)
        #expect(habit.lastDone == Calendar.current.startOfDay(for: date))

        let undone = try HabitStore.toggleCompletion(for: habit, on: date, in: context)
        #expect(!undone)
        #expect(habit.validCompletions.isEmpty)
        #expect(habit.lastDone == nil)
    }

    @Test func deletingHabitRemovesItsCompletions() throws {
        let (_, context) = makeStore()
        let habit = try HabitStore.createHabit(named: "Walk", in: context)
        try HabitStore.toggleCompletion(for: habit, in: context)
        #expect(habit.validCompletions.count == 1)

        try HabitStore.delete(habit, in: context)

        let request: NSFetchRequest<Completion> = Completion.fetchRequest()
        let remainingCount = try context.fetch(request).count
        #expect(remainingCount == 0)
    }

    @Test func emptyNamesAreRejected() throws {
        let (_, context) = makeStore()
        #expect(throws: HabitStoreError.self) {
            try HabitStore.createHabit(named: "   ", in: context)
        }
    }

    @Test func quantityGoalOnlyCompletesAtTargetAndUpdatesExistingDay() throws {
        let (_, context) = makeStore()
        var draft = HabitDraft()
        draft.name = "Water"
        draft.goal = .count
        draft.targetCount = 8
        draft.unitName = "glasses"
        let habit = try HabitStore.save(draft, in: context)
        let day = Date(timeIntervalSince1970: 1_785_652_800)

        try HabitStore.recordCompletion(for: habit, on: day, value: 5, note: "Afternoon", in: context)
        #expect(!habit.isComplete(on: day))
        #expect(habit.validCompletions.count == 1)

        try HabitStore.recordCompletion(for: habit, on: day, value: 8, note: "Done", in: context)
        #expect(habit.isComplete(on: day))
        #expect(habit.validCompletions.count == 1)
        #expect(habit.completion(on: day)?.note == "Done")
    }

    @Test func selectedWeekdaysControlDailySchedule() throws {
        let (_, context) = makeStore()
        var draft = HabitDraft()
        draft.name = "Weekday walk"
        draft.schedule = .selectedDays
        draft.weekdays = [.monday, .wednesday]
        let habit = try HabitStore.save(draft, in: context)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let monday = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 3)))
        let tuesday = try #require(calendar.date(byAdding: .day, value: 1, to: monday))

        #expect(habit.isScheduled(on: monday, calendar: calendar))
        #expect(!habit.isScheduled(on: tuesday, calendar: calendar))
    }

    @Test func backupRoundTripPreservesHabitAndHistory() throws {
        let (_, sourceContext) = makeStore()
        let habit = try HabitStore.createHabit(named: "Read", in: sourceContext)
        let day = Date(timeIntervalSince1970: 1_785_652_800)
        try HabitStore.recordCompletion(for: habit, on: day, value: 1, note: "Chapter one", in: sourceContext)
        let backup = try HabitBackupService.makeBackup(from: sourceContext)
        let encoded = try HabitBackupCodec.encoder.encode(backup)
        let decoded = try HabitBackupCodec.decoder.decode(HabitBackup.self, from: encoded)

        let (_, destinationContext) = makeStore()
        let restoredCount = try HabitBackupService.restore(decoded, into: destinationContext)
        let habits = try destinationContext.fetch(Habit.fetchRequest())

        #expect(restoredCount == 1)
        #expect(habits.count == 1)
        #expect(habits.first?.displayName == "Read")
        #expect(habits.first?.validCompletions.first?.note == "Chapter one")
    }

    @Test func adherenceOnlyCountsSelectedScheduleDays() throws {
        let (_, context) = makeStore()
        var draft = HabitDraft()
        draft.name = "Weekday walk"
        draft.schedule = .selectedDays
        draft.weekdays = [.monday, .wednesday, .friday]
        let habit = try HabitStore.save(draft, in: context)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let monday = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 3)))
        let sunday = try #require(calendar.date(byAdding: .day, value: 6, to: monday))
        try HabitStore.toggleCompletion(for: habit, on: monday, calendar: calendar, in: context)

        let adherence = HabitAdherence(habit: habit, from: monday, through: sunday, calendar: calendar)
        #expect(adherence.expected == 3)
        #expect(adherence.achieved == 1)
        #expect(adherence.percentage == 33)
    }

    @Test func selectedDayStreakIgnoresUnscheduledDays() throws {
        let (_, context) = makeStore()
        var draft = HabitDraft()
        draft.name = "Three-day routine"
        draft.schedule = .selectedDays
        draft.weekdays = [.monday, .wednesday, .friday]
        let habit = try HabitStore.save(draft, in: context)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let monday = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 3)))
        habit.startDate = monday
        for offset in [0, 2, 4] {
            let day = try #require(calendar.date(byAdding: .day, value: offset, to: monday))
            try HabitStore.toggleCompletion(for: habit, on: day, calendar: calendar, in: context)
        }
        let saturday = try #require(calendar.date(byAdding: .day, value: 5, to: monday))

        let streak = HabitScheduleStreak(habit: habit, relativeTo: saturday, calendar: calendar)
        #expect(streak.current == 3)
        #expect(streak.longest == 3)
        #expect(streak.unit == .checkIn)
    }

    @Test func flexibleScheduleUsesWeeklyStreaks() throws {
        let (_, context) = makeStore()
        var draft = HabitDraft()
        draft.name = "Move three times"
        draft.schedule = .flexible
        draft.scheduleTarget = 3
        let habit = try HabitStore.save(draft, in: context)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        let monday = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 3)))
        habit.startDate = monday
        for offset in 0...2 {
            let day = try #require(calendar.date(byAdding: .day, value: offset, to: monday))
            try HabitStore.toggleCompletion(for: habit, on: day, calendar: calendar, in: context)
        }
        let nextWednesday = try #require(calendar.date(byAdding: .day, value: 9, to: monday))

        let streak = HabitScheduleStreak(habit: habit, relativeTo: nextWednesday, calendar: calendar)
        #expect(streak.current == 1)
        #expect(streak.longest == 1)
        #expect(streak.unit == .week)
    }

    @Test func journalMaintainsOneEntryPerDayAndBackupIncludesIt() throws {
        let (_, context) = makeStore()
        var first = JournalDraft()
        first.date = Date(timeIntervalSince1970: 1_785_652_800)
        first.spiritualWin = "Stayed grateful"
        first.mentalWin = "Morning reflection"
        first.physicalWin = "Walked outside"
        try JournalStore.save(first, in: context)

        var update = first
        update.mentalWin = "Updated reflection"
        try JournalStore.save(update, in: context)

        let entries = try context.fetch(JournalEntry.fetchRequest())
        let backup = try HabitBackupService.makeBackup(from: context)
        #expect(entries.count == 1)
        #expect(entries.first?.body == "Updated reflection")
        #expect(entries.first?.gratitude == "Stayed grateful")
        #expect(entries.first?.intention == "Walked outside")
        #expect(backup.journalEntries?.count == 1)
    }

    @Test func programCreationIsAtomicAndAppliesDuration() throws {
        let (_, context) = makeStore()
        var first = HabitDraft()
        first.name = "Move"
        var second = HabitDraft()
        second.name = "Read"

        let created = try HabitStore.createProgram(
            drafts: [first, second],
            programTitle: "Foundation",
            durationDays: 30,
            in: context
        )
        #expect(created.count == 2)
        #expect(created.allSatisfy { $0.notes?.contains("Foundation") == true })
        let daySpan = Calendar.current.dateComponents(
            [.day],
            from: try #require(created.first?.startDate),
            to: try #require(created.first?.endDate)
        ).day
        #expect(daySpan == 29)

        var invalid = HabitDraft()
        invalid.name = "   "
        #expect(throws: HabitStoreError.self) {
            try HabitStore.createProgram(
                drafts: [first, invalid],
                programTitle: "Invalid",
                durationDays: 10,
                in: context
            )
        }
        let stored = try context.fetch(Habit.fetchRequest())
        #expect(stored.count == 2)
    }

    @Test func programDifficultyAdjustsTargetsWithoutChangingPreset() throws {
        let program = try #require(HabitProgram.catalog.first { $0.id == "foundation-30" })
        let selected = Set(program.habits.map(\.id))
        let gentle = program.drafts(selectedIDs: selected, difficulty: .gentle)
        let intense = program.drafts(selectedIDs: selected, difficulty: .intense)
        let gentleWalk = try #require(gentle.first { $0.name == "Daily walk" })
        let intenseWalk = try #require(intense.first { $0.name == "Daily walk" })

        #expect(gentleWalk.targetCount == 15)
        #expect(intenseWalk.targetCount == 25)
        #expect(program.habits.first { $0.id == "30-walk" }?.target == 20)
    }
}
