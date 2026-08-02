@preconcurrency import CoreData
import Foundation
import Testing
@testable import HabitTracker

struct HabitStatisticsTests {
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

    @Test func journalMaintainsOneEntryPerDayAndBackupIncludesIt() throws {
        let (_, context) = makeStore()
        var first = JournalDraft()
        first.date = Date(timeIntervalSince1970: 1_785_652_800)
        first.body = "Morning reflection"
        try JournalStore.save(first, in: context)

        var update = first
        update.body = "Updated reflection"
        try JournalStore.save(update, in: context)

        let entries = try context.fetch(JournalEntry.fetchRequest())
        let backup = try HabitBackupService.makeBackup(from: context)
        #expect(entries.count == 1)
        #expect(entries.first?.body == "Updated reflection")
        #expect(backup.journalEntries?.count == 1)
    }
}
