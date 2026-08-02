//
//  Completion+CoreDataProperties.swift
//  HabitTracker
//
//  Created by Hercules S on 5/17/25.
//
//

import Foundation
import CoreData


extension Completion {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Completion> {
        return NSFetchRequest<Completion>(entityName: "Completion")
    }

    @NSManaged public var date: Date?
    @NSManaged public var habit: Habit?
    @NSManaged public var id: UUID?
    @NSManaged public var createdAt: Date?
    @NSManaged public var note: String?
    @NSManaged public var state: String?
    @NSManaged public var value: Double

}

extension Completion : Identifiable {

}
