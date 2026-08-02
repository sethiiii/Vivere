import SwiftUI

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("feature.journal") private var journalEnabled = true
    @AppStorage("accentTheme") private var accentTheme = AppAccentTheme.indigo.rawValue
    @State private var selectedTab = AppTab.habits
    @State private var requestedJournalEntry: JournalEntry?

    private var selectedAccent: AppAccentTheme {
        AppAccentTheme(rawValue: accentTheme) ?? .indigo
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                ActivityCalendarView { entry in
                    if reduceMotion {
                        selectedTab = .journal
                    } else {
                        withAnimation(.snappy(duration: 0.26)) { selectedTab = .journal }
                    }
                    DispatchQueue.main.async { requestedJournalEntry = entry }
                }
                .opacity(selectedTab == .calendar ? 1 : 0)
                .allowsHitTesting(selectedTab == .calendar)
                .accessibilityHidden(selectedTab != .calendar)

                TodayView()
                    .opacity(selectedTab == .habits ? 1 : 0)
                    .allowsHitTesting(selectedTab == .habits)
                    .accessibilityHidden(selectedTab != .habits)

                if journalEnabled {
                    JournalView(requestedEntry: $requestedJournalEntry)
                        .opacity(selectedTab == .journal ? 1 : 0)
                        .allowsHitTesting(selectedTab == .journal)
                        .accessibilityHidden(selectedTab != .journal)
                }

                SettingsView()
                    .opacity(selectedTab == .settings ? 1 : 0)
                    .allowsHitTesting(selectedTab == .settings)
                    .accessibilityHidden(selectedTab != .settings)
            }
            .safeAreaPadding(.bottom, 76)

            FloatingTabBar(
                selectedTab: $selectedTab,
                tabs: journalEnabled ? AppTab.allCases : [.calendar, .habits, .settings],
                reduceMotion: reduceMotion
            )
        }
        .tint(selectedAccent.color)
    }
}

private enum AppTab: String, CaseIterable, Identifiable {
    case calendar
    case habits
    case journal
    case settings

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .calendar: "calendar"
        case .habits: "checkmark.circle.fill"
        case .journal: "book.closed.fill"
        case .settings: "gearshape.fill"
        }
    }
}

private struct FloatingTabBar: View {
    @Binding var selectedTab: AppTab
    let tabs: [AppTab]
    let reduceMotion: Bool

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tabs) { tab in
                Button {
                    if reduceMotion {
                        selectedTab = tab
                    } else {
                        withAnimation(.snappy(duration: 0.26)) { selectedTab = tab }
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 19, weight: .semibold))
                        Text(tab.title)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background {
                        if selectedTab == tab {
                            Capsule(style: .continuous)
                                .fill(Color.primary.opacity(0.075))
                        }
                    }
                    .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .padding(6)
        .frame(maxWidth: 390)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.14), radius: 18, y: 8)
        .padding(.horizontal, 26)
        .padding(.top, 7)
        .padding(.bottom, 5)
        // Keep persistent navigation labels legible at accessibility sizes while
        // allowing the content behind the bar to honor the user's full setting.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Main tab bar")
    }
}
