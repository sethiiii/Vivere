import Foundation

enum HabitScheduleType: String, CaseIterable, Identifiable {
    case daily
    case selectedDays
    case flexible

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: "Every Day"
        case .selectedDays: "Selected Days"
        case .flexible: "Times per Week"
        }
    }
}

enum HabitGoalType: String, CaseIterable, Identifiable {
    case checkIn
    case count
    case duration
    case avoidance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .checkIn: "Simple Check-In"
        case .count: "Quantity"
        case .duration: "Duration"
        case .avoidance: "Avoidance"
        }
    }
}

enum HabitTimeOfDay: String, CaseIterable, Identifiable {
    case anytime
    case morning
    case afternoon
    case evening

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct HabitWeekdays: OptionSet, Equatable {
    let rawValue: Int16

    static let sunday = HabitWeekdays(rawValue: 1 << 0)
    static let monday = HabitWeekdays(rawValue: 1 << 1)
    static let tuesday = HabitWeekdays(rawValue: 1 << 2)
    static let wednesday = HabitWeekdays(rawValue: 1 << 3)
    static let thursday = HabitWeekdays(rawValue: 1 << 4)
    static let friday = HabitWeekdays(rawValue: 1 << 5)
    static let saturday = HabitWeekdays(rawValue: 1 << 6)
    static let all: HabitWeekdays = [
        .sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday
    ]

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        guard (1...7).contains(weekday) else { return false }
        return contains(HabitWeekdays(rawValue: 1 << Int16(weekday - 1)))
    }
}

extension Habit {
    var schedule: HabitScheduleType {
        get { HabitScheduleType(rawValue: scheduleType ?? "") ?? .daily }
        set { scheduleType = newValue.rawValue }
    }

    var goal: HabitGoalType {
        get { HabitGoalType(rawValue: goalType ?? "") ?? .checkIn }
        set { goalType = newValue.rawValue }
    }

    var preferredTime: HabitTimeOfDay {
        get { HabitTimeOfDay(rawValue: timeOfDay ?? "") ?? .anytime }
        set { timeOfDay = newValue.rawValue }
    }

    var weekdays: HabitWeekdays {
        get { HabitWeekdays(rawValue: scheduledWeekdays) }
        set { scheduledWeekdays = newValue.rawValue }
    }

    func isScheduled(on date: Date, calendar: Calendar = .current) -> Bool {
        if let startDate, calendar.startOfDay(for: date) < calendar.startOfDay(for: startDate) {
            return false
        }
        if let endDate, calendar.startOfDay(for: date) > calendar.startOfDay(for: endDate) {
            return false
        }

        switch schedule {
        case .daily, .flexible:
            return true
        case .selectedDays:
            return weekdays.contains(date, calendar: calendar)
        }
    }
}
