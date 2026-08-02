import CoreData
import PhotosUI
import SwiftUI
import UIKit

struct JournalView: View {
    @Environment(\.managedObjectContext) private var context
    @AppStorage("quote.category") private var categoryRaw = QuoteCategory.all.rawValue
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \JournalEntry.date, ascending: false)],
        animation: .default
    ) private var entries: FetchedResults<JournalEntry>
    @State private var searchText = ""
    @State private var editingEntry: JournalEntry?
    @State private var showingTodayEditor = false

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
                    Button { showingTodayEditor = true } label: { Image(systemName: "square.and.pencil") }
                        .accessibilityLabel("Write journal entry")
                }
            }
            .sheet(isPresented: $showingTodayEditor) {
                JournalEditorView(entry: entryForToday, quote: quote)
                    .environment(\.managedObjectContext, context)
            }
            .sheet(item: $editingEntry) { entry in
                JournalEditorView(entry: entry, quote: quote)
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
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "quote.opening")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.tint)
            Text(quote.text)
                .font(.title3.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
            Text("— \(quote.author)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
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

    init(entry: JournalEntry?, quote: MotivationalQuote) {
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
            initial.prompt = "What felt meaningful today?"
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
            let scale = min(1, 1600 / max(image.size.width, image.size.height))
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: size)
            let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            draft.photoData = resized.jpegData(compressionQuality: 0.82)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
