import CoreData
import SwiftUI

struct HabitsView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Habit.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \Habit.name, ascending: true)
        ],
        predicate: NSPredicate(format: "isArchived == NO"),
        animation: .default
    ) private var habits: FetchedResults<Habit>

    @State private var searchText = ""
    @State private var showingAddHabit = false
    @State private var pendingDeletion: Habit?
    @State private var errorMessage: String?
    @State private var showingArchive = false

    private var filteredHabits: [Habit] {
        guard !searchText.isEmpty else { return Array(habits) }
        return habits.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if habits.isEmpty {
                    ContentUnavailableView(
                        "No Habits Yet",
                        systemImage: "leaf",
                        description: Text("Create a habit and it will appear here.")
                    )
                } else {
                    List {
                        ForEach(filteredHabits, id: \.objectID) { habit in
                            NavigationLink {
                                HabitDetailView(habit: habit)
                            } label: {
                                habitRow(habit)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    togglePaused(habit)
                                } label: {
                                    Label(habit.isPaused ? "Resume" : "Pause", systemImage: habit.isPaused ? "play" : "pause")
                                }
                                .tint(habit.isPaused ? .green : .orange)
                                Button {
                                    archive(habit)
                                } label: {
                                    Label("Archive", systemImage: "archivebox")
                                }
                                .tint(.indigo)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pendingDeletion = habit
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .accessibilityAction(named: habit.isPaused ? "Resume habit" : "Pause habit") {
                                togglePaused(habit)
                            }
                        }
                        .onMove(perform: move)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Habits")
            .searchable(text: $searchText, prompt: "Search habits")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingArchive = true } label: {
                        Image(systemName: "archivebox")
                    }
                    .accessibilityLabel("Archived habits")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if searchText.isEmpty && habits.count > 1 { EditButton() }
                    Button { showingAddHabit = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add habit")
                }
            }
            .sheet(isPresented: $showingAddHabit) {
                AddHabitView().environment(\.managedObjectContext, context)
            }
            .sheet(isPresented: $showingArchive) {
                ArchivedHabitsView()
                    .environment(\.managedObjectContext, context)
            }
            .confirmationDialog(
                "Delete this habit?",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete Habit and History", role: .destructive) {
                    if let habit = pendingDeletion { delete(habit) }
                    pendingDeletion = nil
                }
                Button("Cancel", role: .cancel) { pendingDeletion = nil }
            } message: {
                Text("This permanently removes the habit and all of its check-ins. Archive it instead if you may want it later.")
            }
            .alert("Couldn’t Update Habit", isPresented: errorPresented) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
        }
    }

    private func habitRow(_ habit: Habit) -> some View {
        let streak = HabitScheduleStreak(habit: habit)
        return HStack(spacing: 13) {
            Image(systemName: habit.displayIcon)
                .font(.body.weight(.semibold))
                .foregroundStyle(habit.tintColor)
                .frame(width: 38, height: 38)
                .background(habit.tintColor.opacity(0.13), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 3) {
                Text(habit.displayName).font(.body.weight(.medium))
                Text(habit.isPaused
                     ? "Paused — history is safe"
                     : streak.current == 0
                        ? "No active streak"
                        : "\(streak.current) \(streak.unit.label(for: streak.current)) streak")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }

    private func archive(_ habit: Habit) {
        do {
            habit.isArchived = true
            habit.updatedAt = Date()
            try HabitStore.save(context)
            cancelReminder(for: habit)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ habit: Habit) {
        do {
            cancelReminder(for: habit)
            try HabitStore.delete(habit, in: context)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func togglePaused(_ habit: Habit) {
        do {
            habit.isPaused.toggle()
            habit.updatedAt = Date()
            try HabitStore.save(context)
            if habit.isPaused {
                cancelReminder(for: habit)
            } else {
                restoreReminder(for: habit)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = Array(habits)
        reordered.move(fromOffsets: source, toOffset: destination)
        do {
            for (index, habit) in reordered.enumerated() {
                habit.sortOrder = Int64(index)
                habit.updatedAt = Date()
            }
            try HabitStore.save(context)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reminderIdentifier(for habit: Habit) -> String {
        habit.id?.uuidString ?? habit.objectID.uriRepresentation().absoluteString
    }

    private func cancelReminder(for habit: Habit) {
        NotificationManager.shared.cancelReminder(id: reminderIdentifier(for: habit))
    }

    private func restoreReminder(for habit: Habit) {
        guard habit.reminderEnabled, let time = habit.reminderTime else { return }
        NotificationManager.shared.authorizeAndScheduleReminder(
            id: reminderIdentifier(for: habit),
            title: habit.displayName,
            time: time,
            schedule: habit.schedule,
            weekdays: habit.weekdays
        )
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}

private struct ArchivedHabitsView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Habit.updatedAt, ascending: false)],
        predicate: NSPredicate(format: "isArchived == YES"),
        animation: .default
    ) private var habits: FetchedResults<Habit>
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if habits.isEmpty {
                    ContentUnavailableView("No Archived Habits", systemImage: "archivebox")
                } else {
                    List(habits, id: \.objectID) { habit in
                        HStack {
                            Label(habit.displayName, systemImage: habit.displayIcon)
                            Spacer()
                            Button("Restore") { restore(habit) }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .navigationTitle("Archive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .alert("Couldn’t Restore Habit", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) { Button("OK") { errorMessage = nil } } message: {
                Text(errorMessage ?? "Please try again.")
            }
        }
    }

    private func restore(_ habit: Habit) {
        do {
            habit.isArchived = false
            habit.updatedAt = Date()
            try HabitStore.save(context)
            if habit.reminderEnabled, !habit.isPaused, let time = habit.reminderTime {
                let identifier = habit.id?.uuidString ?? habit.objectID.uriRepresentation().absoluteString
                NotificationManager.shared.authorizeAndScheduleReminder(
                    id: identifier,
                    title: habit.displayName,
                    time: time,
                    schedule: habit.schedule,
                    weekdays: habit.weekdays
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
