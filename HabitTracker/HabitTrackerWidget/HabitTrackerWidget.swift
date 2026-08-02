import SwiftUI
import WidgetKit

private let appGroupIdentifier = "group.com.sethi.HabitTracker"
private let snapshotKey = "widget.today.snapshot.v1"

private struct WidgetSnapshot: Codable {
    let generatedAt: Date
    let completedCount: Int
    let totalCount: Int
    let habits: [WidgetHabit]

    static let preview = WidgetSnapshot(
        generatedAt: .now,
        completedCount: 2,
        totalCount: 4,
        habits: [
            WidgetHabit(id: UUID(), name: "Morning walk", iconName: "figure.walk", tintHex: "4E7BD9", isComplete: true),
            WidgetHabit(id: UUID(), name: "Read", iconName: "book.fill", tintHex: "7A62C9", isComplete: true),
            WidgetHabit(id: UUID(), name: "Drink water", iconName: "drop.fill", tintHex: "2D9CDB", isComplete: false)
        ]
    )
}

private struct WidgetHabit: Codable, Identifiable {
    let id: UUID
    let name: String
    let iconName: String
    let tintHex: String
    let isComplete: Bool
}

private struct HabitWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

private struct HabitWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> HabitWidgetEntry {
        HabitWidgetEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (HabitWidgetEntry) -> Void) {
        completion(HabitWidgetEntry(date: .now, snapshot: loadSnapshot() ?? .preview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HabitWidgetEntry>) -> Void) {
        let now = Date.now
        let entry = HabitWidgetEntry(date: now, snapshot: loadSnapshot() ?? emptySnapshot(at: now))
        let nextMidnight = Calendar.current.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 1),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(3_600)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }

    private func loadSnapshot() -> WidgetSnapshot? {
        guard
            let defaults = UserDefaults(suiteName: appGroupIdentifier),
            let data = defaults.data(forKey: snapshotKey)
        else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    private func emptySnapshot(at date: Date) -> WidgetSnapshot {
        WidgetSnapshot(generatedAt: date, completedCount: 0, totalCount: 0, habits: [])
    }
}

private struct HabitTrackerWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HabitWidgetEntry

    private var progress: Double {
        guard entry.snapshot.totalCount > 0 else { return 0 }
        return Double(entry.snapshot.completedCount) / Double(entry.snapshot.totalCount)
    }

    var body: some View {
        switch family {
        case .systemMedium:
            mediumLayout
        default:
            smallLayout
        }
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Today", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(entry.snapshot.completedCount)/\(entry.snapshot.totalCount)")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .contentTransition(.numericText())
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                ProgressRing(progress: progress)
                    .frame(width: 48, height: 48)
            }
        }
        .padding(16)
    }

    private var mediumLayout: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Today", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                ProgressRing(progress: progress)
                    .frame(width: 64, height: 64)
                    .overlay {
                        Text("\(Int((progress * 100).rounded()))%")
                            .font(.caption.weight(.bold).monospacedDigit())
                    }
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 92, alignment: .leading)

            Divider()

            VStack(spacing: 8) {
                if entry.snapshot.habits.isEmpty {
                    ContentUnavailableView("A clear day", systemImage: "sun.max")
                } else {
                    ForEach(entry.snapshot.habits.prefix(3)) { habit in
                        HStack(spacing: 9) {
                            Image(systemName: habit.isComplete ? "checkmark.circle.fill" : habit.iconName)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(habit.isComplete ? Color.green : Color(hex: habit.tintHex))
                                .frame(width: 22)
                            Text(habit.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(habit.isComplete ? .secondary : .primary)
                                .strikethrough(habit.isComplete, color: .secondary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityValue(habit.isComplete ? "Complete" : "Not complete")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
    }

    private var statusText: String {
        if entry.snapshot.totalCount == 0 { return "Nothing scheduled" }
        if entry.snapshot.completedCount == entry.snapshot.totalCount { return "Day complete" }
        return "Keep your rhythm"
    }
}

private struct ProgressRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle().stroke(.tertiary, lineWidth: 7)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(progress >= 1 ? Color.green : Color.accentColor,
                        style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .accessibilityHidden(true)
    }
}

private extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let value = UInt64(cleaned, radix: 16) ?? 0x5B5BD6
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

struct HabitTrackerWidget: Widget {
    let kind = "HabitTrackerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HabitWidgetProvider()) { entry in
            HabitTrackerWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Today’s Habits")
        .description("See your daily progress and next habits at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    HabitTrackerWidget()
} timeline: {
    HabitWidgetEntry(date: .now, snapshot: .preview)
}

#Preview(as: .systemMedium) {
    HabitTrackerWidget()
} timeline: {
    HabitWidgetEntry(date: .now, snapshot: .preview)
}
