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
