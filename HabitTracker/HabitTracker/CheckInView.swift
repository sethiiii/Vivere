import SwiftUI

struct CheckInView: View {
    @ObservedObject var habit: Habit
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var value: Double
    @State private var note: String
    @State private var errorMessage: String?

    init(habit: Habit) {
        self.habit = habit
        let existing = habit.completion(on: Date())
        _value = State(initialValue: existing?.value ?? Double(max(1, habit.targetCount)))
        _note = State(initialValue: existing?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: habit.displayIcon)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(habit.tintColor)
                            .frame(width: 52, height: 52)
                            .background(habit.tintColor.opacity(0.14), in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(habit.displayName).font(.headline)
                            Text(goalDescription).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }

                if habit.goal == .count || habit.goal == .duration {
                    Section(habit.goal == .duration ? "Time" : "Amount") {
                        HStack {
                            Button { value = max(0, value - stepSize) } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .accessibilityLabel("Decrease value")
                            Spacer()
                            VStack(spacing: 2) {
                                Text(value.formatted(.number.precision(.fractionLength(0...1))))
                                    .font(.largeTitle.bold().monospacedDigit())
                                Text(unitLabel).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button { value += stepSize } label: {
                                Image(systemName: "plus.circle.fill")
                            }
                            .accessibilityLabel("Increase value")
                        }
                        .font(.title2)
                        .buttonStyle(.plain)

                        Slider(value: $value, in: 0...sliderMaximum, step: stepSize)
                            .tint(habit.tintColor)
                            .accessibilityLabel("Completed amount")
                    }
                }

                Section("Observation") {
                    TextField("How did it go? Add an optional note.", text: $note, axis: .vertical)
                        .lineLimit(4...8)
                }
            }
            .navigationTitle("Check In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).fontWeight(.semibold)
                }
            }
            .alert("Couldn’t Save Check-In", isPresented: errorPresented) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
        }
    }

    private var stepSize: Double { habit.goal == .duration ? 5 : 1 }
    private var sliderMaximum: Double { max(Double(habit.targetCount) * 2, stepSize * 2) }
    private var unitLabel: String {
        let trimmed = habit.unitName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty { return trimmed }
        return habit.goal == .duration ? "minutes" : "completed"
    }
    private var goalDescription: String {
        switch habit.goal {
        case .count, .duration: "Goal: \(habit.targetCount) \(unitLabel)"
        case .avoidance: "Log a successful day"
        case .checkIn: "Add an optional observation"
        }
    }

    private func save() {
        do {
            _ = try HabitStore.recordCompletion(
                for: habit,
                value: habit.goal == .checkIn || habit.goal == .avoidance ? 1 : value,
                note: note,
                in: context
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }
}
