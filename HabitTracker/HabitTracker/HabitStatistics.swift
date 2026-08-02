import Foundation

struct HabitStatistics: Equatable {
    let completedDays: Set<Date>
    let today: Date
    let calendar: Calendar

    init(
        completionDates: [Date],
        relativeTo referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.calendar = calendar
        let normalizedToday = calendar.startOfDay(for: referenceDate)
        today = normalizedToday
        completedDays = Set(
            completionDates
                .map { calendar.startOfDay(for: $0) }
                .filter { $0 <= normalizedToday }
        )
    }

    var totalCompletions: Int { completedDays.count }

    var firstCompletion: Date? { completedDays.min() }

    var lastCompletion: Date? { completedDays.max() }

    var currentStreak: Int {
        guard !completedDays.isEmpty else { return 0 }

        var cursor = completedDays.contains(today)
            ? today
            : calendar.date(byAdding: .day, value: -1, to: today) ?? today
        var streak = 0

        while completedDays.contains(cursor) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previousDay
        }

        return streak
    }

    var longestStreak: Int {
        let days = completedDays.sorted()
        guard let firstDay = days.first else { return 0 }

        var longest = 1
        var running = 1
        var previous = firstDay

        for day in days.dropFirst() {
            if calendar.dateComponents([.day], from: previous, to: day).day == 1 {
                running += 1
                longest = max(longest, running)
            } else {
                running = 1
            }
            previous = day
        }

        return longest
    }

    var elapsedDays: Int {
        guard let firstCompletion else { return 0 }
        return (calendar.dateComponents([.day], from: firstCompletion, to: today).day ?? 0) + 1
    }

    var consistencyPercentage: Int {
        guard elapsedDays > 0 else { return 0 }
        let percentage = Double(totalCompletions) / Double(elapsedDays) * 100
        return min(100, max(0, Int(percentage.rounded())))
    }

    func isCompleted(on date: Date) -> Bool {
        completedDays.contains(calendar.startOfDay(for: date))
    }
}

struct HabitAdherence: Equatable {
    let expected: Int
    let achieved: Int

    init(expected: Int, achieved: Int) {
        self.expected = max(0, expected)
        self.achieved = max(0, min(achieved, expected))
    }

    var percentage: Int {
        guard expected > 0 else { return 0 }
        return min(100, max(0, Int((Double(achieved) / Double(expected) * 100).rounded())))
    }

    init(
        habit: Habit,
        from rawStart: Date,
        through rawEnd: Date = Date(),
        calendar: Calendar = .current
    ) {
        let start = calendar.startOfDay(for: rawStart)
        let end = calendar.startOfDay(for: rawEnd)
        guard start <= end else {
            expected = 0
            achieved = 0
            return
        }

        var dates: [Date] = []
        var cursor = start
        while cursor <= end {
            dates.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        switch habit.schedule {
        case .daily, .selectedDays:
            let opportunities = dates.filter { habit.isScheduled(on: $0, calendar: calendar) }
            expected = opportunities.count
            achieved = opportunities.filter { habit.isComplete(on: $0, calendar: calendar) }.count
        case .flexible:
            let elapsedDays = dates.count
            let proratedTarget = Int(ceil(Double(elapsedDays) / 7.0 * Double(max(1, habit.scheduleTarget))))
            expected = min(elapsedDays, proratedTarget)
            achieved = min(expected, dates.filter { habit.isComplete(on: $0, calendar: calendar) }.count)
        }
    }
}

struct HabitScheduleStreak: Equatable {
    enum Unit: Equatable {
        case checkIn
        case week

        func label(for value: Int) -> String {
            switch self {
            case .checkIn: value == 1 ? "check-in" : "check-ins"
            case .week: value == 1 ? "week" : "weeks"
            }
        }
    }

    let current: Int
    let longest: Int
    let unit: Unit

    private init(current: Int, longest: Int, unit: Unit) {
        self.current = max(0, current)
        self.longest = max(0, longest)
        self.unit = unit
    }

    init(habit: Habit, relativeTo referenceDate: Date = Date(), calendar: Calendar = .current) {
        switch habit.schedule {
        case .daily, .selectedDays:
            self = Self.scheduledDayStreak(habit: habit, relativeTo: referenceDate, calendar: calendar)
        case .flexible:
            self = Self.flexibleWeekStreak(habit: habit, relativeTo: referenceDate, calendar: calendar)
        }
    }

    private static func scheduledDayStreak(
        habit: Habit,
        relativeTo referenceDate: Date,
        calendar: Calendar
    ) -> HabitScheduleStreak {
        let today = calendar.startOfDay(for: referenceDate)
        let completed = Set(habit.achievedCompletionDates.map { calendar.startOfDay(for: $0) }.filter { $0 <= today })
        guard let firstCompletion = completed.min() else {
            return HabitScheduleStreak(current: 0, longest: 0, unit: .checkIn)
        }
        let rawStart = habit.startDate.map { calendar.startOfDay(for: $0) } ?? firstCompletion
        let start = min(rawStart, firstCompletion)
        var opportunities: [Date] = []
        var cursor = start
        while cursor <= today {
            if habit.isScheduled(on: cursor, calendar: calendar) { opportunities.append(cursor) }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        var longest = 0
        var running = 0
        for date in opportunities {
            if completed.contains(date) {
                running += 1
                longest = max(longest, running)
            } else {
                running = 0
            }
        }

        var current = 0
        var index = opportunities.count - 1
        if index >= 0, opportunities[index] == today, !completed.contains(today) { index -= 1 }
        while index >= 0, completed.contains(opportunities[index]) {
            current += 1
            index -= 1
        }
        return HabitScheduleStreak(current: current, longest: longest, unit: .checkIn)
    }

    private static func flexibleWeekStreak(
        habit: Habit,
        relativeTo referenceDate: Date,
        calendar: Calendar
    ) -> HabitScheduleStreak {
        let completed = habit.achievedCompletionDates
        guard let firstCompletion = completed.min(),
              let firstWeek = calendar.dateInterval(of: .weekOfYear, for: min(habit.startDate ?? firstCompletion, firstCompletion))?.start,
              let currentWeek = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start
        else {
            return HabitScheduleStreak(current: 0, longest: 0, unit: .week)
        }

        let target = Int(max(1, habit.scheduleTarget))
        var metWeeks: [Bool] = []
        var week = firstWeek
        while week <= currentWeek {
            guard let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: week) else { break }
            let count = completed.filter { $0 >= week && $0 < nextWeek && $0 <= referenceDate }.count
            metWeeks.append(count >= target)
            week = nextWeek
        }

        var longest = 0
        var running = 0
        for met in metWeeks {
            running = met ? running + 1 : 0
            longest = max(longest, running)
        }

        var index = metWeeks.count - 1
        if index >= 0, !metWeeks[index] { index -= 1 }
        var current = 0
        while index >= 0, metWeeks[index] {
            current += 1
            index -= 1
        }
        return HabitScheduleStreak(current: current, longest: longest, unit: .week)
    }
}

struct MonthGrid: Equatable {
    let month: Date
    let weekdaySymbols: [String]
    let leadingBlankCount: Int
    let dates: [Date]

    init?(month: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month], from: month)
        guard
            let firstDay = calendar.date(from: components),
            let dayRange = calendar.range(of: .day, in: .month, for: firstDay)
        else { return nil }

        self.month = firstDay
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        leadingBlankCount = (firstWeekday - calendar.firstWeekday + 7) % 7

        let symbols = calendar.shortStandaloneWeekdaySymbols
        let startIndex = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        weekdaySymbols = Array(symbols[startIndex...] + symbols[..<startIndex])
        dates = dayRange.compactMap {
            calendar.date(byAdding: .day, value: $0 - 1, to: firstDay)
        }
    }
}
