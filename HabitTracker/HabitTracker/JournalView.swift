import CoreData
import PhotosUI
import SwiftUI
import UIKit

struct JournalView: View {
    @Environment(\.managedObjectContext) private var context
    @AppStorage("quote.category") private var categoryRaw = QuoteCategory.all.rawValue
    @AppStorage("quote.favoriteIDs") private var favoriteQuoteIDs = ""
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \JournalEntry.date, ascending: false)],
        animation: .default
    ) private var entries: FetchedResults<JournalEntry>
    @State private var searchText = ""
    @State private var editingEntry: JournalEntry?
    @State private var showingTodayEditor = false
    @State private var showingCalendar = false

    private var quote: MotivationalQuote {
        MotivationalQuote.daily(category: QuoteCategory(rawValue: categoryRaw) ?? .all)
    }

    private var filteredEntries: [JournalEntry] {
        guard !searchText.isEmpty else { return Array(entries) }
        return entries.filter {
            $0.displayTitle.localizedCaseInsensitiveContains(searchText)
                || $0.previewText.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    quoteCard
                    todayCard
                    recentEntries
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .background(AppTheme.canvas)
            .navigationTitle("Journal")
            .searchable(text: $searchText, prompt: "Search your journal")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingCalendar = true } label: { Image(systemName: "calendar") }
                        .accessibilityLabel("Journal calendar")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingTodayEditor = true } label: { Image(systemName: "square.and.pencil") }
                        .accessibilityLabel("Write journal entry")
                }
            }
            .sheet(isPresented: $showingTodayEditor) {
                JournalEditorView(entry: entryForToday, quote: quote, date: Date())
                    .environment(\.managedObjectContext, context)
            }
            .sheet(item: $editingEntry) { entry in
                JournalEditorView(entry: entry, quote: quote, date: entry.date ?? Date())
                    .environment(\.managedObjectContext, context)
            }
            .sheet(isPresented: $showingCalendar) {
                JournalCalendarView()
                    .environment(\.managedObjectContext, context)
            }
        }
    }

    private var entryForToday: JournalEntry? {
        entries.first { entry in
            guard let date = entry.date else { return false }
            return Calendar.current.isDateInToday(date)
        }
    }

    private var quoteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "quote.opening")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.tint)
                Spacer()
                ShareLink(item: shareText(for: quote)) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share today’s quote")
                Button {
                    favoriteQuoteIDs = QuoteFavorites.toggle(quote.id, in: favoriteQuoteIDs)
                } label: {
                    Image(systemName: isFavorite(quote) ? "star.fill" : "star")
                        .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel(isFavorite(quote) ? "Remove quote from favorites" : "Add quote to favorites")
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(quote.text)
                    .font(.body.weight(.medium))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                Text("— \(quote.author)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let source = quote.source {
                    Text(source)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .accessibilityElement(children: .combine)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private func isFavorite(_ quote: MotivationalQuote) -> Bool {
        QuoteFavorites.decode(favoriteQuoteIDs).contains(quote.id)
    }

    private func shareText(for quote: MotivationalQuote) -> String {
        "“\(quote.text)” — \(quote.author)"
    }

    private var todayCard: some View {
        Button { showingTodayEditor = true } label: {
            HStack(spacing: 16) {
                Image(systemName: entryForToday == nil ? "pencil.line" : "checkmark")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 50, height: 50)
                    .background(Color.accentColor.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(entryForToday == nil ? "Write today’s page" : "Continue today’s page")
                        .font(.headline)
                    Text(entryForToday?.previewText ?? "A few honest sentences are enough.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(18)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var recentEntries: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Pages").font(.title3.bold())
                Spacer()
                Text("\(entries.count)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            if filteredEntries.isEmpty {
                Text("Your pages will collect here, privately on this device.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 18))
            } else {
                ForEach(filteredEntries) { entry in
                    Button { editingEntry = entry } label: {
                        JournalEntryRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct JournalCalendarView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("quote.category") private var categoryRaw = QuoteCategory.all.rawValue
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \JournalEntry.date, ascending: false)]
    ) private var entries: FetchedResults<JournalEntry>
    @State private var selectedDate = Date()
    @State private var showingEditor = false

    private var selectedEntry: JournalEntry? {
        entries.first { entry in
            guard let date = entry.date else { return false }
            return Calendar.current.isDate(date, inSameDayAs: selectedDate)
        }
    }

    private var quote: MotivationalQuote {
        MotivationalQuote.daily(
            category: QuoteCategory(rawValue: categoryRaw) ?? .all,
            on: selectedDate
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                DatePicker(
                    "Journal date",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 7) {
                    Label(
                        selectedEntry == nil ? "An unwritten page" : selectedEntry?.displayTitle ?? "Journal page",
                        systemImage: selectedEntry == nil ? "doc" : "checkmark.circle.fill"
                    )
                    .font(.headline)
                    Text(selectedEntry?.previewText ?? JournalPrompt.daily(on: selectedDate))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 20)

                Button(selectedEntry == nil ? "Write This Page" : "Open This Page") {
                    showingEditor = true
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 14))
                .controlSize(.large)

                Spacer()
            }
            .background(AppTheme.canvas)
            .navigationTitle("Journal Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $showingEditor) {
                JournalEditorView(entry: selectedEntry, quote: quote, date: selectedDate)
                    .environment(\.managedObjectContext, context)
            }
        }
    }
}

private struct JournalEntryRow: View {
    @ObservedObject var entry: JournalEntry

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(entry.date ?? Date(), format: .dateTime.day())
                    .font(.title2.bold().monospacedDigit())
                Text(entry.date ?? Date(), format: .dateTime.month(.abbreviated))
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            .frame(width: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayTitle).font(.headline).lineLimit(1)
                Text(entry.previewText).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            Text(["", "Very low", "Low", "Steady", "Good", "Great"][Int(max(0, min(5, entry.mood)))])
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct JournalEditorView: View {
    let entry: JournalEntry?
    let quote: MotivationalQuote
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var draft: JournalDraft
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var errorMessage: String?
    @State private var confirmingDeletion = false

    init(entry: JournalEntry?, quote: MotivationalQuote, date: Date) {
        self.entry = entry
        self.quote = quote
        var initial = JournalDraft()
        if let entry {
            initial.date = entry.date ?? Date()
            initial.title = entry.title ?? ""
            initial.body = entry.body ?? ""
            initial.gratitude = entry.gratitude ?? ""
            initial.intention = entry.intention ?? ""
            initial.mood = entry.mood
            initial.prompt = entry.prompt ?? ""
            initial.quoteID = entry.quoteID
            initial.photoData = entry.photoData
        } else {
            initial.date = date
            initial.prompt = JournalPrompt.daily(on: date)
            initial.quoteID = quote.id
        }
        _draft = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $draft.date, displayedComponents: .date)
                    TextField("Title (optional)", text: $draft.title)
                    moodPicker
                }
                Section(draft.prompt) {
                    TextField("Write without editing yourself…", text: $draft.body, axis: .vertical)
                        .lineLimit(8...18)
                }
                Section("Gratitude") {
                    TextField("Something I appreciate…", text: $draft.gratitude, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section("Tomorrow") {
                    TextField("One clear intention…", text: $draft.intention, axis: .vertical)
                        .lineLimit(2...5)
                }
                photoSection
                if entry != nil {
                    Section {
                        Button("Delete Entry", role: .destructive) { confirmingDeletion = true }
                    }
                }
            }
            .navigationTitle("Daily Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).fontWeight(.semibold) }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                guard let newValue else { return }
                Task { await loadPhoto(newValue) }
            }
            .alert("Couldn’t Save Entry", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) { Button("OK") { errorMessage = nil } } message: {
                Text(errorMessage ?? "Please try again.")
            }
            .confirmationDialog("Delete this journal entry?", isPresented: $confirmingDeletion, titleVisibility: .visible) {
                Button("Delete Entry", role: .destructive, action: deleteEntry)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes the page and its photo.")
            }
        }
    }

    private var moodPicker: some View {
        Picker("Mood", selection: $draft.mood) {
            Text("Very Low").tag(Int16(1))
            Text("Low").tag(Int16(2))
            Text("Steady").tag(Int16(3))
            Text("Good").tag(Int16(4))
            Text("Great").tag(Int16(5))
        }
    }

    @ViewBuilder
    private var photoSection: some View {
        Section("Memory") {
            if let data = draft.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable().scaledToFill().frame(height: 190).clipShape(RoundedRectangle(cornerRadius: 14))
                Button("Remove Photo", role: .destructive) { draft.photoData = nil }
            }
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label(draft.photoData == nil ? "Add Photo" : "Replace Photo", systemImage: "photo")
            }
        }
    }

    private func save() {
        do {
            try JournalStore.save(draft, editing: entry, in: context)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteEntry() {
        guard let entry else { return }
        do {
            try JournalStore.delete(entry, in: context)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadPhoto(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return }
            let longestSide = max(image.size.width, image.size.height)
            guard longestSide.isFinite, longestSide > 0 else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let scale = min(1, 1600 / longestSide)
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: size)
            let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            draft.photoData = resized.jpegData(compressionQuality: 0.82)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum JournalPrompt {
    static let prompts = [
        "What felt meaningful today?",
        "What gave you energy, and what took it away?",
        "Where did you show courage today?",
        "What is one moment you want to remember?",
        "What did today teach you about yourself?",
        "What are you carrying that you can put down?",
        "When did you feel most present today?",
        "What small choice moved your life forward?",
        "What deserves more of your attention tomorrow?",
        "What are you proud of that no one else saw?",
        "What surprised you today?",
        "Where could you offer yourself more patience?",
        "What conversation stayed with you?",
        "What made today feel lighter?",
        "What would make tomorrow feel successful?",
        "Which habit supported the person you want to become?",
        "What did you avoid, and what might help you begin?",
        "What beauty did you notice today?",
        "What is within your control right now?",
        "If today had a title, what would it be?"
    ]

    static func daily(on date: Date = Date(), calendar: Calendar = .current) -> String {
        guard !prompts.isEmpty else { return "What feels important right now?" }
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return prompts[abs(day) % prompts.count]
    }
}
