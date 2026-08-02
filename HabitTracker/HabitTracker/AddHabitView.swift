import SwiftUI

struct AddHabitView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("feature.advancedHabitOptions") private var advancedOptionsEnabled = false

    private let habit: Habit?
    @State private var draft: HabitDraft
    @State private var errorMessage: String?

    private let icons = [
        "checkmark", "figure.walk", "book.closed", "drop", "heart",
        "brain.head.profile", "dumbbell", "leaf", "moon.stars", "pencil"
    ]
    private let colors = ["#5B7CFA", "#31A86A", "#E58A2B", "#E05A67", "#8E64D9", "#278EAE"]

    init(habit: Habit? = nil) {
        self.habit = habit
        var initial = HabitDraft()
        if let habit {
            initial.name = habit.name ?? ""
            initial.iconName = habit.displayIcon
            initial.tintHex = habit.tintHex ?? "#5B7CFA"
            initial.schedule = habit.schedule
            initial.weekdays = habit.weekdays
            initial.scheduleTarget = max(1, habit.scheduleTarget)
            initial.goal = habit.goal
            initial.targetCount = max(1, habit.targetCount)
            initial.unitName = habit.unitName ?? ""
            initial.preferredTime = habit.preferredTime
            initial.reminderEnabled = habit.reminderEnabled
            initial.reminderTime = habit.reminderTime ?? Date()
            initial.notes = habit.notes ?? ""
        }
        _draft = State(initialValue: initial)
    }

    init(template: HabitTemplate) {
        habit = nil
        _draft = State(initialValue: template.draft)
    }

    var body: some View {
        NavigationStack {
            Form {
                essentialsSection
                if advancedOptionsEnabled { advancedSections }
            }
            .navigationTitle(habit == nil ? "New Habit" : "Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Couldn’t Save Habit", isPresented: errorPresented) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
        }
    }

    private var essentialsSection: some View {
        Section {
            TextField("Habit name", text: $draft.name)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)

            VStack(alignment: .leading, spacing: 12) {
                Text("Icon").font(.subheadline).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(icons, id: \.self) { icon in
                            Button {
                                draft.iconName = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.body.weight(.semibold))
                                    .frame(width: 42, height: 42)
                                    .foregroundStyle(draft.iconName == icon ? selectedTintForeground : selectedTint)
                                    .background(
                                        draft.iconName == icon ? selectedTint : selectedTint.opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: 12)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(icon.replacingOccurrences(of: ".", with: " "))
                            .accessibilityAddTraits(draft.iconName == icon ? .isSelected : [])
                        }
                    }
                }
            }

            HStack(spacing: 15) {
                Text("Color")
                Spacer()
                ForEach(colors, id: \.self) { hex in
                    Button {
                        draft.tintHex = hex
                    } label: {
                        Circle()
                            .fill(Color(habitHex: hex) ?? AppTheme.accent)
                            .frame(width: 25, height: 25)
                            .overlay {
                                if draft.tintHex == hex {
                                    Circle().stroke(.primary.opacity(0.65), lineWidth: 2).padding(-3)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Select color")
                    .accessibilityAddTraits(draft.tintHex == hex ? .isSelected : [])
                }
            }
        } header: {
            Text("Essentials")
        } footer: {
            if !advancedOptionsEnabled {
                Text("Advanced schedules, goals, notes, and reminders can be enabled in Settings.")
            }
        }
    }

    @ViewBuilder
    private var advancedSections: some View {
        Section("Schedule") {
            Picker("Frequency", selection: $draft.schedule) {
                ForEach(HabitScheduleType.allCases) { type in
                    Text(type.title).tag(type)
                }
            }

            if draft.schedule == .selectedDays {
                weekdayPicker
            } else if draft.schedule == .flexible {
                Stepper("\(draft.scheduleTarget) times per week", value: $draft.scheduleTarget, in: 1...7)
            }

            Picker("Time of day", selection: $draft.preferredTime) {
                ForEach(HabitTimeOfDay.allCases) { time in
                    Text(time.title).tag(time)
                }
            }
        }

        Section("Goal") {
            Picker("Goal type", selection: $draft.goal) {
                ForEach(HabitGoalType.allCases) { goal in
                    Text(goal.title).tag(goal)
                }
            }

            if draft.goal == .count || draft.goal == .duration {
                Stepper("Target: \(draft.targetCount)", value: $draft.targetCount, in: 1...10_000)
                TextField(draft.goal == .duration ? "Unit, such as minutes" : "Unit, such as glasses", text: $draft.unitName)
            }
        }

        Section("Reminder") {
            Toggle("Daily reminder", isOn: $draft.reminderEnabled)
            if draft.reminderEnabled {
                DatePicker("Time", selection: $draft.reminderTime, displayedComponents: .hourAndMinute)
            }
        }

        Section("Notes") {
            TextField("Why does this matter to you?", text: $draft.notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    private var weekdayPicker: some View {
        let weekdays: [(String, HabitWeekdays)] = [
            ("S", .sunday), ("M", .monday), ("T", .tuesday), ("W", .wednesday),
            ("T", .thursday), ("F", .friday), ("S", .saturday)
        ]

        return HStack {
            ForEach(Array(weekdays.enumerated()), id: \.offset) { _, item in
                let selected = draft.weekdays.contains(item.1)
                Button {
                    if selected {
                        draft.weekdays.remove(item.1)
                    } else {
                        draft.weekdays.insert(item.1)
                    }
                } label: {
                    Text(item.0)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .foregroundStyle(selected ? Color.white : Color.primary)
                        .background(selected ? selectedTint : AppTheme.subtleFill, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(selected ? "Selected" : "Not selected")
            }
        }
    }

    private var selectedTint: Color { Color(habitHex: draft.tintHex) ?? AppTheme.accent }
    private var selectedTintForeground: Color { .readableForeground(forHabitHex: draft.tintHex) }

    private func save() {
        do {
            let savedHabit = try HabitStore.save(draft, editing: habit, in: context)
            configureReminder(for: savedHabit)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func configureReminder(for habit: Habit) {
        let identifier = habit.id?.uuidString ?? habit.objectID.uriRepresentation().absoluteString
        if draft.reminderEnabled {
            NotificationManager.shared.authorizeAndScheduleDailyReminder(
                id: identifier,
                title: habit.displayName,
                time: draft.reminderTime
            )
        } else {
            NotificationManager.shared.cancelReminder(id: identifier)
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}
