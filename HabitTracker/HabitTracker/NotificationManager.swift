import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    /// Ask the user for permission to send alerts & sounds.
    func requestPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error:", error)
            }
        }
    }

    func authorizeAndScheduleReminder(
        id: String,
        title: String,
        time: Date,
        schedule: HabitScheduleType,
        weekdays: HabitWeekdays
    ) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                self?.scheduleReminder(id: id, title: title, time: time, schedule: schedule, weekdays: weekdays)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, error in
                    if granted {
                        self?.scheduleReminder(id: id, title: title, time: time, schedule: schedule, weekdays: weekdays)
                    } else if let error {
                        print("Notification permission error:", error)
                    }
                }
            case .denied:
                break
            @unknown default:
                break
            }
        }
    }

    func scheduleReminder(
        id: String,
        title: String,
        time: Date,
        schedule: HabitScheduleType,
        weekdays: HabitWeekdays
    ) {
        let center = UNUserNotificationCenter.current()
        cancelReminder(id: id)

        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: time)
        let selectedWeekdays = Self.notificationWeekdays(for: schedule, weekdays: weekdays)
        let requestWeekdays: [Int?] = schedule == .selectedDays
            ? selectedWeekdays.map(Optional.some)
            : [nil]

        for weekday in requestWeekdays {
            var components = DateComponents()
            components.hour = timeComponents.hour
            components.minute = timeComponents.minute
            components.second = 0
            components.weekday = weekday

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = "A small step today keeps your momentum going."
            content.sound = .default
            content.categoryIdentifier = "HABIT_REMINDER"

            let requestID = weekday.map { "\(id).weekday.\($0)" } ?? id
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: requestID, content: content, trigger: trigger)
            center.add(request) { error in
                if let error {
                    print("Failed to schedule notification:", error)
                }
            }
        }
    }

    func cancelReminder(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: Self.requestIdentifiers(for: id)
        )
    }

    static func notificationWeekdays(
        for schedule: HabitScheduleType,
        weekdays: HabitWeekdays
    ) -> [Int] {
        guard schedule == .selectedDays else { return [] }
        return (1...7).filter { weekday in
            weekdays.contains(HabitWeekdays(rawValue: 1 << Int16(weekday - 1)))
        }
    }

    static func requestIdentifiers(for id: String) -> [String] {
        [id] + (1...7).map { "\(id).weekday.\($0)" }
    }
}
