import CoreData
import SwiftUI

struct ActivityCalendarView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Habit.sortOrder, ascending: true)],
        animation: .default
    ) private var habits: FetchedResults<Habit>
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \JournalEntry.date, ascending: false)],
        animation: .default
    ) private var journalEntries: FetchedResults<JournalEntry>

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("accentTheme") private var accentTheme = AppAccentTheme.indigo.rawValue
    @State private var displayedMonth = Calendar.current.startOfDay(for: Date())
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())

    let onOpenJournal: (JournalEntry) -> Void

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    private var monthGrid: MonthGrid? { MonthGrid(month: displayedMonth, calendar: calendar) }

    private var activityStatistics: HabitStatistics {
        HabitStatistics(
            completionDates: habits.flatMap(\.achievedCompletionDates),
            calendar: calendar
        )
    }

    private var completedOnSelectedDate: [Habit] {
        completedHabits(on: selectedDate)
    }

    private var selectedJournalEntry: JournalEntry? {
        journalEntries.first { entry in
            guard let date = entry.date else { return false }
            return calendar.isDate(date, inSameDayAs: selectedDate)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    streakSummary
                    calendarCard
                    selectedDayCard
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .background(AppTheme.canvas)
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var streakSummary: some View {
        HStack(spacing: 12) {
            streakMetric(
                title: "Current streak",
                value: activityStatistics.currentStreak,
                symbol: "flame.fill",
                color: .orange
            )
            streakMetric(
                title: "Best streak",
                value: activityStatistics.longestStreak,
                symbol: "trophy.fill",
                color: .yellow
            )
        }
    }

    private func streakMetric(title: String, value: Int, symbol: String, color: Color) -> some View {
        HStack(spacing: 11) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.13), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text("\(value)")
                    .font(.title2.bold().monospacedDigit())
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value) days")
    }

    private var calendarCard: some View {
        VStack(spacing: 14) {
            HStack {
                Button { changeMonth(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 38, height: 38)
                }
                .accessibilityLabel("Previous month")

                Spacer()
                Text(displayedMonth, format: .dateTime.month(.wide).year())
                    .font(.headline)
                Spacer()

                Button { changeMonth(by: 1) } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 38, height: 38)
                }
                .disabled(isDisplayingCurrentMonth)
                .accessibilityLabel("Next month")
            }

            if let monthGrid {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(monthGrid.weekdaySymbols, id: \.self) { symbol in
                        Text(symbol.uppercased())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach((0..<monthGrid.leadingBlankCount).map { "blank-\($0)" }, id: \.self) { _ in
                        Color.clear.frame(height: 42)
                    }

                    ForEach(monthGrid.dates, id: \.self) { date in
                        dayButton(date)
                    }
                }
            }

            HStack(spacing: 7) {
                Text("Less")
                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(activityColor(level: level))
                        .frame(width: 18, height: 10)
                }
                Text("More")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func dayButton(_ date: Date) -> some View {
        let count = completedHabits(on: date).count
        let level = intensityLevel(for: count)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isFuture = date > calendar.startOfDay(for: Date())

        return Button {
            select(date)
        } label: {
            Text(date, format: .dateTime.day())
                .font(.subheadline.weight(isSelected ? .bold : .medium).monospacedDigit())
                .foregroundStyle(level >= 3 ? highIntensityForeground : Color.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(activityColor(level: level), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                }
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .opacity(isFuture ? 0.35 : 1)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        .accessibilityValue(count == 1 ? "1 habit completed" : "\(count) habits completed")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var selectedDayCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedDate, format: .dateTime.weekday(.wide).month(.wide).day())
                        .font(.headline)
                    Text(completedOnSelectedDate.isEmpty
                         ? "No habits completed"
                         : "\(completedOnSelectedDate.count) completed")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if calendar.isDateInToday(selectedDate) {
                    Text("Today")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                }
            }

            if completedOnSelectedDate.isEmpty {
                Text("A blank day is information, not failure. Begin again with one small action.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(completedOnSelectedDate, id: \.objectID) { habit in
                    HStack(spacing: 11) {
                        Image(systemName: habit.displayIcon)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(habit.tintForegroundColor)
                            .frame(width: 30, height: 30)
                            .background(habit.tintColor, in: Circle())
                        Text(habit.displayName)
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(.tint)
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            if let entry = selectedJournalEntry {
                Divider()
                Button {
                    onOpenJournal(entry)
                } label: {
                    HStack {
                        Label("Open Journal Entry", systemImage: "book.closed.fill")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .accessibilityHint("Opens the journal page for this date")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .id(selectedDate)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var isDisplayingCurrentMonth: Bool {
        calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month)
    }

    private func completedHabits(on date: Date) -> [Habit] {
        habits.filter { $0.isComplete(on: date, calendar: calendar) }
    }

    private func intensityLevel(for count: Int) -> Int {
        guard count > 0 else { return 0 }
        let maximum = max(1, habits.count)
        return min(4, max(1, Int(ceil(Double(count) / Double(maximum) * 4))))
    }

    private func activityColor(level: Int) -> Color {
        guard level > 0 else { return Color.primary.opacity(0.055) }
        return Color.accentColor.opacity([0, 0.24, 0.42, 0.64, 0.9][min(4, level)])
    }

    private var highIntensityForeground: Color {
        let theme = AppAccentTheme(rawValue: accentTheme) ?? .indigo
        return theme == .ocean ? .black : .white
    }

    private func changeMonth(by amount: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: amount, to: displayedMonth) else { return }
        let normalized = calendar.date(from: calendar.dateComponents([.year, .month], from: newMonth)) ?? newMonth
        let newSelection = calendar.isDate(normalized, equalTo: Date(), toGranularity: .month)
            ? calendar.startOfDay(for: Date())
            : normalized
        if reduceMotion {
            displayedMonth = normalized
            selectedDate = newSelection
        } else {
            withAnimation(.snappy(duration: 0.25)) {
                displayedMonth = normalized
                selectedDate = newSelection
            }
        }
    }

    private func select(_ date: Date) {
        let normalized = calendar.startOfDay(for: date)
        if reduceMotion {
            selectedDate = normalized
        } else {
            withAnimation(.snappy(duration: 0.22)) { selectedDate = normalized }
        }
    }
}
