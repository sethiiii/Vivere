import CoreData
import SwiftUI

struct TodayView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Habit.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \Habit.name, ascending: true)
        ],
        predicate: NSPredicate(format: "isArchived == NO"),
        animation: .snappy
    ) private var activeHabits: FetchedResults<Habit>

    @State private var showingAddHabit = false
    @State private var errorMessage: String?
    @State private var feedbackTrigger = 0
    @State private var habitToCheckIn: Habit?
    @State private var showingAllHabits = false
    @State private var showingGallery = false
    @State private var showingInsights = false
    @AppStorage("feature.haptics") private var hapticsEnabled = true
    @AppStorage("feature.insights") private var insightsEnabled = true
    @AppStorage("feature.gallery") private var galleryEnabled = true

    private var todayHabits: [Habit] {
        activeHabits.filter { !$0.isPaused && $0.isScheduled(on: Date()) }
    }

    private var completedCount: Int {
        todayHabits.filter { $0.isComplete(on: Date()) }.count
    }

    private var progress: Double {
        guard !todayHabits.isEmpty else { return 0 }
        return Double(completedCount) / Double(todayHabits.count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    dayHeader

                    if todayHabits.isEmpty {
                        emptyState
                    } else {
                        progressCard
                        habitCards
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .background(AppTheme.canvas)
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button { showingAllHabits = true } label: {
                            Label("All Habits", systemImage: "square.grid.2x2")
                        }
                        if insightsEnabled {
                            Button { showingInsights = true } label: {
                                Label("Insights", systemImage: "chart.xyaxis.line")
                            }
                        }
                        if galleryEnabled {
                            Button { showingGallery = true } label: {
                                Label("Gallery", systemImage: "sparkles.rectangle.stack")
                            }
                        }
                    } label: {
                        Image(systemName: "square.grid.2x2")
                    }
                    .accessibilityLabel("Habit tools")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddHabit = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add habit")
                }
            }
            .sheet(isPresented: $showingAddHabit) {
                AddHabitView()
                    .environment(\.managedObjectContext, context)
            }
            .sheet(item: $habitToCheckIn) { habit in
                CheckInView(habit: habit)
                    .environment(\.managedObjectContext, context)
            }
            .sheet(isPresented: $showingAllHabits) {
                HabitsView(presentedModally: true)
                    .environment(\.managedObjectContext, context)
            }
            .sheet(isPresented: $showingGallery) {
                GalleryView(presentedModally: true)
                    .environment(\.managedObjectContext, context)
            }
            .sheet(isPresented: $showingInsights) {
                InsightsView(presentedModally: true)
                    .environment(\.managedObjectContext, context)
            }
            .sensoryFeedback(.success, trigger: feedbackTrigger)
            .alert("Couldn’t Update Habit", isPresented: errorPresented) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
        }
    }

    private var dayHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(Date.now, format: .dateTime.weekday(.wide))
                    .font(.title2.weight(.semibold))
                Text(Date.now, format: .dateTime.month(.wide).day())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.top, 4)
    }

    private var progressCard: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(AppTheme.subtleFill, lineWidth: 9)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        progress == 1 ? Color.green : AppTheme.accent,
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.headline.monospacedDigit())
            }
            .frame(width: 78, height: 78)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(progress == 1 ? "Today is complete" : "Your daily rhythm")
                    .font(.headline)
                Text("\(completedCount) of \(todayHabits.count) habits completed")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if progress == 1 {
                    Label("Nicely done", systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Today progress")
        .accessibilityValue("\(completedCount) of \(todayHabits.count) habits completed")
    }

    private var habitCards: some View {
        ForEach(todayHabits, id: \.objectID) { habit in
            HabitTodayCard(habit: habit) {
                if habit.goal == .checkIn || habit.goal == .avoidance {
                    toggle(habit)
                } else {
                    habitToCheckIn = habit
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(AppTheme.accent.gradient)
                .accessibilityHidden(true)
            VStack(spacing: 7) {
                Text(activeHabits.isEmpty ? "Begin with one small habit" : "Nothing scheduled today")
                    .font(.title3.weight(.semibold))
                Text(activeHabits.isEmpty
                     ? "Choose something meaningful and make showing up effortless."
                     : "Enjoy the space, or add another habit when you’re ready.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button("Create a Habit") { showingAddHabit = true }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 62)
        .padding(.horizontal, 28)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func toggle(_ habit: Habit) {
        do {
            let changes = {
                _ = try HabitStore.toggleCompletion(for: habit, in: context)
            }
            if reduceMotion {
                try changes()
            } else {
                try withAnimation(.snappy(duration: 0.32)) { try changes() }
            }
            if hapticsEnabled { feedbackTrigger += 1 }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}

private struct HabitTodayCard: View {
    @ObservedObject var habit: Habit
    let toggle: () -> Void

    private var statistics: HabitStatistics { HabitStatistics(completionDates: habit.achievedCompletionDates) }
    private var streak: HabitScheduleStreak { HabitScheduleStreak(habit: habit) }

    private var isCompleted: Bool { habit.isComplete(on: Date()) }

    private var recentDays: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(habit.tintColor.opacity(0.14))
                Image(systemName: habit.displayIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(habit.tintColor)
            }
            .frame(width: 46, height: 46)
            .accessibilityHidden(true)

            NavigationLink {
                HabitDetailView(habit: habit)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text(habit.displayName)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        if streak.current > 0 {
                            Label("\(streak.current)", systemImage: "flame.fill")
                                .labelStyle(.titleAndIcon)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                    }
                    HStack(spacing: 5) {
                        ForEach(recentDays, id: \.self) { date in
                            Circle()
                                .fill(statistics.isCompleted(on: date) ? habit.tintColor : AppTheme.subtleFill)
                                .frame(width: 7, height: 7)
                        }
                    }
                    .accessibilityHidden(true)
                    if let progressText {
                        Text(progressText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button(action: toggle) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 30, weight: .regular))
                    .foregroundStyle(isCompleted ? habit.tintColor : Color.secondary.opacity(0.45))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .frame(width: 44, height: 44)
            .accessibilityLabel(isCompleted ? "Undo \(habit.displayName)" : "Complete \(habit.displayName)")
            .accessibilityValue(isCompleted ? "Completed today" : "Not completed today")
        }
        .padding(16)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var progressText: String? {
        guard habit.goal == .count || habit.goal == .duration else { return nil }
        let value = habit.completion(on: Date())?.value ?? 0
        let savedUnit = habit.unitName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let unit = savedUnit.isEmpty ? (habit.goal == .duration ? "min" : "") : savedUnit
        return "\(value.formatted(.number.precision(.fractionLength(0...1)))) / \(habit.targetCount) \(unit)"
    }
}
