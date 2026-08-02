import SwiftUI

struct ContentView: View {
    @AppStorage("feature.insights") private var insightsEnabled = true
    @AppStorage("feature.gallery") private var galleryEnabled = false
    @AppStorage("accentTheme") private var accentTheme = AppAccentTheme.indigo.rawValue

    private var selectedAccent: AppAccentTheme {
        AppAccentTheme(rawValue: accentTheme) ?? .indigo
    }

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "checkmark.circle") }

            HabitsView()
                .tabItem { Label("Habits", systemImage: "square.grid.2x2") }

            if galleryEnabled {
                GalleryView()
                    .tabItem { Label("Gallery", systemImage: "sparkles.rectangle.stack") }
            }

            if insightsEnabled {
                InsightsView()
                    .tabItem { Label("Insights", systemImage: "chart.xyaxis.line") }
            }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(selectedAccent.color)
    }
}
