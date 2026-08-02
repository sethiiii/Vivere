import CoreData
import SwiftUI

struct HabitDetailView: View {
    @ObservedObject var habit: Habit
    @Environment(\.managedObjectContext) private var context
    @FetchRequest private var completions: FetchedResults<Completion>
    @State private var displayMonth = Date()
    @State private var errorMessage: String?
    @State private var showingEdit = false
    @State private var showingCheckIn = false

    private var validCompletions: [Completion] {
        completions.filter { $0.date != nil }
    }

    private var statistics: HabitStatistics {
        HabitStatistics(completionDates: habit.achievedCompletionDates)
    }

    private var streak: HabitScheduleStreak { HabitScheduleStreak(habit: habit) }

    init(habit: Habit) {
        self.habit = habit
        let request: NSFetchRequest<Completion> = Completion.fetchRequest()
        request.predicate = NSPredicate(format: "habit == %@", habit)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Completion.date, ascending: false)]
        _completions = FetchRequest(fetchRequest: request)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text(habit.displayName)
                    .font(.largeTitle.bold())
                    .padding(.top)

                progressSection
                statisticsSection
                calendarView
                detailsSection
                entriesSection
                checkInButton
            }
            .padding(.bottom)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            AddHabitView(habit: habit)
                .environment(\.managedObjectContext, context)
        }
        .sheet(isPresented: $showingCheckIn) {
            CheckInView(habit: habit)
                .environment(\.managedObjectContext, context)
        }
        .alert("Couldn’t Update Habit", isPresented: errorPresented) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    private var progressSection: some View {
        let days = statistics.elapsedDays
        let milestone = max(30, ((max(1, days) - 1) / 30 + 1) * 30)

        return VStack(spacing: 6) {
            HStack {
                Text("Progress").font(.headline)
                Spacer()
                Text("\(days)/\(milestone) days")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(days), total: Double(milestone))
        }
        .padding(.horizontal)
    }

    private var statisticsSection: some View {
        HStack {
            stat("Streak", "\(streak.current)")
            Spacer()
            stat("Check-Ins", "\(statistics.totalCompletions)")
            Spacer()
            stat("Score", "\(statistics.consistencyPercentage)%")
        }
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details").font(.headline)
            detailRow("First Check-In:", formatted(statistics.firstCompletion))
            detailRow("Last Done:", formatted(statistics.lastCompletion))
            detailRow("Duration:", "\(statistics.elapsedDays) days")
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var entriesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Entries").font(.headline)
            if validCompletions.isEmpty {
                Text("No check-ins yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(validCompletions, id: \.objectID) { completion in
                    if let date = completion.date {
                        HStack {
                            Text(date, style: .date)
                            Spacer()
                            Button(role: .destructive) {
                                delete(completion)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Delete check-in for \(date.formatted(date: .long, time: .omitted))")
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private var checkInButton: some View {
        let isComplete = statistics.isCompleted(on: Date())
        return Button(action: checkInAction) {
            Label(
                isComplete ? "Undo Check-In" : "Check In",
                systemImage: isComplete ? "arrow.uturn.backward" : "checkmark"
            )
            .frame(maxWidth: .infinity)
            .padding()
        }
        .buttonStyle(.borderedProminent)
        .tint(isComplete ? .red : .accentColor)
        .padding(.horizontal)
    }

    private func checkInAction() {
        if statistics.isCompleted(on: Date()) {
            toggle()
        } else {
            showingCheckIn = true
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack {
            Text(value).font(.title2.bold())
            Text(title).font(.caption)
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }

    private func formatted(_ date: Date?) -> String {
        date?.formatted(date: .abbreviated, time: .omitted) ?? "–"
    }

    private func toggle() {
        do {
            try HabitStore.toggleCompletion(for: habit, in: context)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ completion: Completion) {
        do {
            try HabitStore.delete(completion, in: context)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @ViewBuilder
    private var calendarView: some View {
        if let grid = MonthGrid(month: displayMonth) {
            VStack {
                HStack {
                    Button {
                        moveMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel("Previous month")

                    Spacer()
                    Text(grid.month, format: .dateTime.month(.wide).year())
                        .font(.headline)
                    Spacer()

                    Button {
                        moveMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .accessibilityLabel("Next month")
                }
                .padding(.horizontal)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(grid.weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(0..<grid.leadingBlankCount, id: \.self) { _ in
                        Color.clear.frame(height: 32)
                    }
                    ForEach(grid.dates, id: \.self) { date in
                        calendarDay(date)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func calendarDay(_ date: Date) -> some View {
        let isComplete = statistics.isCompleted(on: date)
        let isToday = Calendar.current.isDateInToday(date)

        return ZStack {
            if isComplete {
                Circle().fill(.tint)
            } else if isToday {
                Circle().stroke(.tint, lineWidth: 2)
            }
            Text(date, format: .dateTime.day())
                .foregroundStyle(isComplete ? habit.tintForegroundColor : Color.primary)
                .fontWeight(.semibold)
        }
        .frame(width: 32, height: 32)
        .accessibilityElement()
        .accessibilityLabel(date.formatted(date: .long, time: .omitted))
        .accessibilityValue(isComplete ? "Completed" : isToday ? "Today, not completed" : "Not completed")
    }

    private func moveMonth(by value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: displayMonth) {
            displayMonth = newMonth
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}
