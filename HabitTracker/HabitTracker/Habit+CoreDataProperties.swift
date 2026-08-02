//
//  Habit+CoreDataProperties.swift
//  HabitTracker
//

import Foundation
import CoreData

extension Habit {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Habit> {
        return NSFetchRequest<Habit>(entityName: "Habit")
    }

    @NSManaged public var name: String?
    @NSManaged public var lastDone: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var iconName: String?
    @NSManaged public var tintHex: String?
    @NSManaged public var isArchived: Bool
    @NSManaged public var isPaused: Bool
    @NSManaged public var sortOrder: Int64
    @NSManaged public var scheduleType: String?
    @NSManaged public var scheduleTarget: Int16
    @NSManaged public var scheduledWeekdays: Int16
    @NSManaged public var goalType: String?
    @NSManaged public var targetCount: Int32
    @NSManaged public var unitName: String?
    @NSManaged public var reminderEnabled: Bool
    @NSManaged public var reminderTime: Date?
    @NSManaged public var notes: String?
    @NSManaged public var startDate: Date?
    @NSManaged public var endDate: Date?
    @NSManaged public var timeOfDay: String?
    @NSManaged public var completions: NSSet?
}

extension Habit: Identifiable {}

// MARK: Generated accessors for completions
extension Habit {

    @objc(addCompletionsObject:)
    @NSManaged public func addToCompletions(_ value: Completion)

    @objc(removeCompletionsObject:)
    @NSManaged public func removeFromCompletions(_ value: Completion)

    @objc(addCompletions:)
    @NSManaged public func addToCompletions(_ values: NSSet)

    @objc(removeCompletions:)
    @NSManaged public func removeFromCompletions(_ values: NSSet)
}
