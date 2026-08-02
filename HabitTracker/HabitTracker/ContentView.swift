import SwiftUI

struct ContentView: View {
    @AppStorage("feature.journal") private var journalEnabled = true
    @AppStorage("accentTheme") private var accentTheme = AppAccentTheme.indigo.rawValue

    private var selectedAccent: AppAccentTheme {
        AppAccentTheme(rawValue: accentTheme) ?? .indigo
    }

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Habits", systemImage: "checkmark.circle") }

            if journalEnabled {
                JournalView()
                    .tabItem { Label("Journal", systemImage: "book.closed") }
            }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(selectedAccent.color)
    }
}
