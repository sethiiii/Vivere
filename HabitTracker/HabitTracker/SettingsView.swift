import CoreData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("accentTheme") private var accentTheme = AppAccentTheme.indigo.rawValue
    @AppStorage("feature.insights") private var insightsEnabled = true
    @AppStorage("feature.advancedHabitOptions") private var advancedHabitOptions = true
    @AppStorage("feature.haptics") private var hapticsEnabled = true
    @AppStorage("feature.weeklyReview") private var weeklyReviewEnabled = true
    @AppStorage("feature.gallery") private var galleryEnabled = true
    @AppStorage("feature.journal") private var journalEnabled = true
    @AppStorage("quote.category") private var quoteCategory = QuoteCategory.all.rawValue
    @AppStorage("feature.dailyMotivation") private var dailyMotivationEnabled = true
    @AppStorage("onboarding.completed") private var onboardingCompleted = false

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
                        settingLabel("Insights", detail: "Trends and reviews in Habit tools", symbol: "chart.xyaxis.line")
                    }
                    Toggle(isOn: $advancedHabitOptions) {
                        settingLabel("Advanced Habit Tools", detail: "Schedules, goals, notes, and more", symbol: "slider.horizontal.3")
                    }
                    Toggle(isOn: $galleryEnabled) {
                        settingLabel("Gallery", detail: "Programs and presets in Habit tools", symbol: "sparkles.rectangle.stack")
                    }
                    Toggle(isOn: $journalEnabled) {
                        settingLabel("Journal", detail: "Daily pages, prompts, photos, and quotes", symbol: "book.closed")
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

                if journalEnabled {
                    Section("Journal") {
                        Toggle(isOn: $dailyMotivationEnabled) {
                            settingLabel(
                                "Daily Motivation",
                                detail: "A compact quote at the top of Journal",
                                symbol: "quote.opening"
                            )
                        }
                        if dailyMotivationEnabled {
                            Picker("Quote category", selection: $quoteCategory) {
                                ForEach(QuoteCategory.allCases) { category in
                                    Text(category.title).tag(category.rawValue)
                                }
                            }
                        }
                        NavigationLink {
                            FavoriteQuotesView()
                        } label: {
                            settingLabel("Favorite Quotes", detail: "Saved inspiration for any day", symbol: "star")
                        }
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
                    LabeledContent("Vivere", value: "To live")
                    LabeledContent("Version", value: "1.0")
                    Button("View Welcome Tour") { onboardingCompleted = false }
                } header: {
                    Text("About")
                } footer: {
                    Text("No account. No ads. No subscription. Your progress belongs to you.")
                }

                Section("Legal") {
                    NavigationLink {
                        TermsView()
                    } label: {
                        settingLabel("Terms & Conditions", detail: "Legal terms for using this app", symbol: "doc.text")
                    }
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        settingLabel("Privacy Policy", detail: "How Vivere handles your data", symbol: "hand.raised")
                    }
                } footer: {
                    Text("By using Vivere you agree to these terms.")
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

private struct FavoriteQuotesView: View {
    @AppStorage("quote.favoriteIDs") private var favoriteQuoteIDs = ""

    private var quotes: [MotivationalQuote] {
        let identifiers = QuoteFavorites.decode(favoriteQuoteIDs)
        return MotivationalQuote.library.filter { identifiers.contains($0.id) }
    }

    var body: some View {
        Group {
            if quotes.isEmpty {
                ContentUnavailableView(
                    "No Favorite Quotes",
                    systemImage: "star",
                    description: Text("Tap the star on a daily quote to keep it here.")
                )
            } else {
                List(quotes) { quote in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(quote.text)
                            .font(.body.weight(.medium))
                        Text("— \(quote.author)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack {
                            if let source = quote.source {
                                Text(source).font(.caption).foregroundStyle(.tertiary)
                            }
                            Spacer()
                            ShareLink(item: "“\(quote.text)” — \(quote.author)") {
                                Image(systemName: "square.and.arrow.up")
                            }
                            Button(role: .destructive) {
                                favoriteQuoteIDs = QuoteFavorites.toggle(quote.id, in: favoriteQuoteIDs)
                            } label: {
                                Image(systemName: "star.slash")
                            }
                            .accessibilityLabel("Remove \(quote.author) quote from favorites")
                        }
                    }
                    .padding(.vertical, 5)
                    .accessibilityElement(children: .contain)
                }
            }
        }
        .navigationTitle("Favorite Quotes")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DataPrivacyView: View {
    @Environment(\.managedObjectContext) private var context
    @State private var exportDocument: HabitBackupDocument?
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var showingDeleteConfirmation = false

    var body: some View {
        List {
            Section {
                Label("Stored on this device", systemImage: "iphone")
                Label("No advertising identifiers", systemImage: "eye.slash")
                Label("No analytics SDKs", systemImage: "hand.raised")
                Label("No account required", systemImage: "person.crop.circle.badge.xmark")
            }
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Backups are readable JSON files. Restore merges matching records and does not erase habits already on this device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Warning: exported backups may contain your personal habit and journal content. Store exported files securely and only share intentionally.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button {
                    prepareExport()
                } label: {
                    Label("Export Backup", systemImage: "square.and.arrow.up")
                }
                Button {
                    showingImporter = true
                } label: {
                    Label("Restore from Backup", systemImage: "arrow.clockwise.icloud")
                }
            } header: {
                Text("Backup & Restore")
            } footer: {
                Text("Backups are readable JSON files. Keep exported files private — they include your habits and journal entries.")
            }

            Section("Danger Zone") {
                Text("Permanently delete all local data stored by Vivere on this device. This cannot be undone and will remove habits, completions, and journal entries.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete All Data", systemImage: "trash")
                }
            } footer: {
                Text("We recommend exporting a backup before deleting anything.")
            }
        }
        .navigationTitle("Your Data")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "Vivere Backup"
        ) { result in
            if case .failure(let error) = result { errorMessage = error.localizedDescription }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            restore(result)
        }
        .alert("Backup", isPresented: Binding(
            get: { statusMessage != nil },
            set: { if !$0 { statusMessage = nil } }
        )) { Button("OK") { statusMessage = nil } } message: {
            Text(statusMessage ?? "Done")
        }
        .alert("Couldn’t Complete Backup", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) { Button("OK") { errorMessage = nil } } message: {
            Text(errorMessage ?? "Please try again.")
        }
        .alert("Delete All Data?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) { deleteAllData() }
            Button("Cancel", role: .cancel) { showingDeleteConfirmation = false }
        } message: {
            Text("This will permanently remove all habits, completions, and journal entries stored on this device. This cannot be undone.")
        }
    }

    private func prepareExport() {
        do {
            exportDocument = HabitBackupDocument(backup: try HabitBackupService.makeBackup(from: context))
            showingExporter = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restore(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let backup = try HabitBackupCodec.decoder.decode(HabitBackup.self, from: data)
            let count = try HabitBackupService.restore(backup, into: context)
            statusMessage = "Restored \(count) habit\(count == 1 ? "" : "s") and merged their history."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteAllData() {
        do {
            // Delete Core Data entities
            let habitFetch: NSFetchRequest<Habit> = Habit.fetchRequest()
            let habits = try context.fetch(habitFetch)
            habits.forEach { context.delete($0) }

            let completionFetch: NSFetchRequest<Completion> = Completion.fetchRequest()
            let completions = try context.fetch(completionFetch)
            completions.forEach { context.delete($0) }

            let journalFetch: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
            let journals = try context.fetch(journalFetch)
            journals.forEach { context.delete($0) }

            try HabitStore.save(context)

            // Clear known AppStorage/UserDefaults keys used by the app
            let keys = [
                "appearance",
                "accentTheme",
                "feature.insights",
                "feature.advancedHabitOptions",
                "feature.haptics",
                "feature.weeklyReview",
                "feature.gallery",
                "feature.journal",
                "quote.category",
                "feature.dailyMotivation",
                "onboarding.completed",
                "quote.favoriteIDs"
            ]
            for key in keys { UserDefaults.standard.removeObject(forKey: key) }
            UserDefaults.standard.synchronize()

            statusMessage = "All local data deleted."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
