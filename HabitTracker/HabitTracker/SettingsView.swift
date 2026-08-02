import SwiftUI

struct SettingsView: View {
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("accentTheme") private var accentTheme = AppAccentTheme.indigo.rawValue
    @AppStorage("feature.insights") private var insightsEnabled = true
    @AppStorage("feature.advancedHabitOptions") private var advancedHabitOptions = false
    @AppStorage("feature.haptics") private var hapticsEnabled = true
    @AppStorage("feature.weeklyReview") private var weeklyReviewEnabled = false
    @AppStorage("feature.gallery") private var galleryEnabled = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $appearance) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Accent").font(.subheadline)
                        HStack {
                            ForEach(AppAccentTheme.allCases) { theme in
                                Button {
                                    accentTheme = theme.rawValue
                                } label: {
                                    VStack(spacing: 6) {
                                        Circle()
                                            .fill(theme.color)
                                            .frame(width: 28, height: 28)
                                            .overlay {
                                                if accentTheme == theme.rawValue {
                                                    Circle().stroke(.primary, lineWidth: 2).padding(-4)
                                                }
                                            }
                                        Text(theme.title)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(theme.title) accent")
                                .accessibilityAddTraits(accentTheme == theme.rawValue ? .isSelected : [])
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Toggle(isOn: $insightsEnabled) {
                        settingLabel("Insights", detail: "Trends, streaks, and consistency", symbol: "chart.xyaxis.line")
                    }
                    Toggle(isOn: $advancedHabitOptions) {
                        settingLabel("Advanced Habit Tools", detail: "Schedules, goals, notes, and more", symbol: "slider.horizontal.3")
                    }
                    Toggle(isOn: $galleryEnabled) {
                        settingLabel("Gallery", detail: "Curated templates and guided experiments", symbol: "sparkles.rectangle.stack")
                    }
                    Toggle(isOn: $weeklyReviewEnabled) {
                        settingLabel("Weekly Review", detail: "A calm summary of your progress", symbol: "calendar.badge.clock")
                    }
                } header: {
                    Text("Modules")
                } footer: {
                    Text("Keep the app simple, or enable only the capabilities you want.")
                }

                Section("Feedback") {
                    Toggle(isOn: $hapticsEnabled) {
                        settingLabel("Haptics", detail: "Subtle feedback for check-ins", symbol: "waveform")
                    }
                }

                Section("Data & Privacy") {
                    NavigationLink {
                        DataPrivacyView()
                    } label: {
                        settingLabel("Your Data", detail: "Private and stored on this device", symbol: "lock.shield")
                    }
                }

                Section {
                    LabeledContent("Version", value: "1.0")
                } header: {
                    Text("About")
                } footer: {
                    Text("No account. No ads. No subscription. Your progress belongs to you.")
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func settingLabel(_ title: String, detail: String, symbol: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 24)
        }
    }
}

private struct DataPrivacyView: View {
    var body: some View {
        List {
            Section {
                Label("Stored on this device", systemImage: "iphone")
                Label("No advertising identifiers", systemImage: "eye.slash")
                Label("No analytics SDKs", systemImage: "hand.raised")
                Label("No account required", systemImage: "person.crop.circle.badge.xmark")
            }
            Section {
                Text("Export and restore controls will live here, using standard Apple share and file tools.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Your Data")
        .navigationBarTitleDisplayMode(.inline)
    }
}
