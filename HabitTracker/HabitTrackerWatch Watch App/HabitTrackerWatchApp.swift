//
//  HabitTrackerWatchApp.swift
//  HabitTrackerWatch Watch App
//
//  Created by Hercules S on 8/2/26.
//

import SwiftUI

@main
struct HabitTrackerWatch_Watch_AppApp: App {
    @StateObject private var store = WatchHabitStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
