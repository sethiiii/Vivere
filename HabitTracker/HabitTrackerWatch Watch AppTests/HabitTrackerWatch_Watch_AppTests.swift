//
//  HabitTrackerWatch_Watch_AppTests.swift
//  HabitTrackerWatch Watch AppTests
//
//  Created by Hercules S on 8/2/26.
//

import Foundation
import Testing
@testable import HabitTrackerWatch_Watch_App

struct HabitTrackerWatch_Watch_AppTests {
    @MainActor
    @Test func snapshotRoundTripsAndRecomputesProgress() throws {
        let firstID = UUID()
        let snapshot = WatchHabitSnapshot(
            generatedAt: .now,
            completedCount: 0,
            totalCount: 2,
            habits: [
                WatchHabit(id: firstID, name: "Walk", iconName: "figure.walk", tintHex: "#4E7BD9", isComplete: false),
                WatchHabit(id: UUID(), name: "Read", iconName: "book", tintHex: "#7A62C9", isComplete: false)
            ]
        )

        let decoded = try JSONDecoder().decode(
            WatchHabitSnapshot.self,
            from: JSONEncoder().encode(snapshot)
        )
        let toggled = decoded.toggling(firstID)

        #expect(decoded == snapshot)
        #expect(toggled.completedCount == 1)
        #expect(toggled.totalCount == 2)
        #expect(toggled.habits.first?.isComplete == true)
    }
}
