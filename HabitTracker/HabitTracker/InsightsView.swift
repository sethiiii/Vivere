import Charts
import CoreData
import SwiftUI

private struct DailyCompletionTotal: Identifiable {
    let date: Date
    let completed: Int
    var id: Date { date }
}

struct InsightsView: View {
    @AppStorage("feature.weeklyReview") private var weeklyReviewEnabled = false
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Habit.name, ascending: true)],
        predicate: NSPredicate(format: "isArchived == NO"),
        animation: .default
    ) private var habits: FetchedResults<Habit>

    private var totalCompletions: Int {
        habits.reduce(0) { $0 + HabitStatistics(completionDates: $1.achievedCompletionDates).totalCompletions }
    }

    private var longestStreak: Int {
        habits.map { HabitScheduleStreak(habit: $0).longest }.max() ?? 0
    }

    private var activeToday: Int {
        habits.filter { $0.isComplete(on: Date()) }.count
    }

    private var weeklyTotals: [DailyCompletionTotal] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let count = habits.filter {
                $0.isComplete(on: date)
            }.count
            return DailyCompletionTotal(date: date, completed: count)
        }
    }

    private var startOfWeek: Date {
        Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }

    private var weeklyAdherence: HabitAdherence {
        let values = habits.map { HabitAdherence(habit: $0, from: startOfWeek) }
        return HabitAdherence(expected: values.reduce(0) { $0 + $1.expected }, achieved: values.reduce(0) { $0 + $1.achieved })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summaryGrid
                    weeklyChart
                    if weeklyReviewEnabled { weeklyReview }
                    habitPerformance
                }
                .padding(20)
            }
            .background(AppTheme.canvas)
            .navigationTitle("Insights")
        }
    }

    private var weeklyReview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Weekly Review", systemImage: "calendar.badge.checkmark")
                    .font(.headline)
                Spacer()
                Text("\(weeklyAdherence.percentage)%")
                    .font(.title3.bold().monospacedDigit())
            }
            ProgressView(value: Double(weeklyAdherence.achieved), total: Double(max(1, weeklyAdherence.expected)))
            Text(weeklyReviewMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            LabeledContent("Completed", value: "\(weeklyAdherence.achieved) of \(weeklyAdherence.expected) planned")
                .font(.subheadline)
        }
        .padding(18)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var weeklyReviewMessage: String {
        switch weeklyAdherence.percentage {
        case 90...: "A remarkably steady week. Protect what made showing up easy."
        case 70..<90: "Strong momentum. Notice which routines fit naturally into your days."
        case 40..<70: "Progress is visible. Make the next action smaller and easier to begin."
        default: "No judgment—use this week as information and restart with one gentle commitment."
        }
    }

    private var summaryGrid: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                metric("Total", value: "\(totalCompletions)", symbol: "checkmark.circle.fill", color: AppTheme.accent)
                metric("Best streak", value: "\(longestStreak)", symbol: "flame.fill", color: .orange)
            }
            GridRow {
                metric("Today", value: "\(activeToday)", symbol: "sun.max.fill", color: .yellow)
                metric("Active habits", value: "\(habits.count)", symbol: "leaf.fill", color: .green)
            }
        }
    }

    private func metric(_ title: String, value: String, symbol: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(value).font(.title2.bold().monospacedDigit())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Last 7 Days").font(.headline)
            Chart(weeklyTotals) { total in
                BarMark(
                    x: .value("Day", total.date, unit: .day),
                    y: .value("Completions", total.completed)
                )
                .foregroundStyle(AppTheme.accent.gradient)
                .cornerRadius(5)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) }
            .frame(height: 190)
        }
        .padding(18)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var habitPerformance: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Habit Performance").font(.headline)
            if habits.isEmpty {
                Text("Your trends will appear after your first check-in.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(habits, id: \.objectID) { habit in
                    let adherence = HabitAdherence(
                        habit: habit,
                        from: Calendar.current.date(byAdding: .day, value: -29, to: Date()) ?? Date()
                    )
                    HStack {
                        Circle().fill(habit.tintColor).frame(width: 9, height: 9)
                        Text(habit.displayName).lineLimit(1)
                        Spacer()
                        Text("\(adherence.percentage)%")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(18)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
