import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: WatchHabitStore

    var body: some View {
        NavigationStack {
            Group {
                if store.snapshot.habits.isEmpty {
                    ContentUnavailableView {
                        Label("A Clear Day", systemImage: "checkmark.circle")
                    } description: {
                        Text("Open HabitTracker on your iPhone to sync today’s habits.")
                    }
                } else {
                    List {
                        Section {
                            progressHeader
                                .listRowBackground(Color.clear)
                        }

                        Section("Today") {
                            ForEach(store.snapshot.habits) { habit in
                                habitButton(habit)
                            }
                        }
                    }
                    .listStyle(.carousel)
                }
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: store.isReachable ? "iphone.radiowaves.left.and.right" : "iphone.slash")
                        .font(.caption)
                        .foregroundStyle(store.isReachable ? .green : .secondary)
                        .accessibilityLabel(store.isReachable ? "iPhone connected" : "iPhone not currently connected")
                }
            }
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Daily rhythm")
                    .font(.headline)
                Spacer()
                Text("\(store.snapshot.completedCount)/\(store.snapshot.totalCount)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: store.progress)
                .tint(store.progress >= 1 ? .green : .accentColor)
            Text(store.progress >= 1 ? "Day complete" : "One tap at a time")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(store.snapshot.completedCount) of \(store.snapshot.totalCount) habits complete")
    }

    private func habitButton(_ habit: WatchHabit) -> some View {
        Button {
            store.toggle(habit)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: habit.isComplete ? "checkmark.circle.fill" : habit.iconName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(habit.isComplete ? Color.green : Color(hex: habit.tintHex))
                    .frame(width: 26)
                Text(habit.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(habit.isComplete ? .secondary : .primary)
                    .strikethrough(habit.isComplete, color: .secondary)
                    .lineLimit(2)
                Spacer(minLength: 2)
                if store.pendingHabitIDs.contains(habit.id) {
                    ProgressView()
                        .controlSize(.mini)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(habit.name)
        .accessibilityValue(habit.isComplete ? "Complete" : "Not complete")
        .accessibilityHint("Double tap to \(habit.isComplete ? "mark incomplete" : "complete")")
    }
}

private extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let value = UInt64(cleaned, radix: 16) ?? 0x5B7CFA
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchHabitStore.preview)
}
