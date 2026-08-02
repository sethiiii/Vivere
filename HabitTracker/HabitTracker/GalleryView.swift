import SwiftUI

struct HabitTemplate: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let category: String
    let icon: String
    let tintHex: String
    let schedule: HabitScheduleType
    let goal: HabitGoalType
    let target: Int32
    let unit: String

    var draft: HabitDraft {
        var draft = HabitDraft()
        draft.name = title
        draft.iconName = icon
        draft.tintHex = tintHex
        draft.schedule = schedule
        draft.scheduleTarget = schedule == .flexible ? 3 : 1
        draft.goal = goal
        draft.targetCount = target
        draft.unitName = unit
        draft.notes = summary
        return draft
    }
}

extension HabitTemplate {
    static let catalog: [HabitTemplate] = [
        .init(id: "walk", title: "Walk 10,000 steps", summary: "Build everyday movement and cardiovascular health.", category: "Fitness", icon: "figure.walk", tintHex: "#31A86A", schedule: .daily, goal: .count, target: 10_000, unit: "steps"),
        .init(id: "strength", title: "Strength training", summary: "A sustainable full-body training rhythm.", category: "Fitness", icon: "dumbbell", tintHex: "#E58A2B", schedule: .flexible, goal: .duration, target: 45, unit: "minutes"),
        .init(id: "stretch", title: "Morning mobility", summary: "Start the day with a calm mobility practice.", category: "Fitness", icon: "figure.flexibility", tintHex: "#278EAE", schedule: .daily, goal: .duration, target: 10, unit: "minutes"),
        .init(id: "read", title: "Read every day", summary: "Make focused reading part of your daily life.", category: "Learning", icon: "book.closed", tintHex: "#8E64D9", schedule: .daily, goal: .duration, target: 20, unit: "minutes"),
        .init(id: "language", title: "Practice a language", summary: "Small, consistent sessions that compound.", category: "Learning", icon: "character.book.closed", tintHex: "#5B7CFA", schedule: .daily, goal: .duration, target: 15, unit: "minutes"),
        .init(id: "write", title: "Write 500 words", summary: "Protect time for clear, uninterrupted creation.", category: "Creativity", icon: "pencil.line", tintHex: "#E05A67", schedule: .daily, goal: .count, target: 500, unit: "words"),
        .init(id: "draw", title: "Sketch something", summary: "Practice observation without judging the result.", category: "Creativity", icon: "paintbrush", tintHex: "#E58A2B", schedule: .flexible, goal: .duration, target: 20, unit: "minutes"),
        .init(id: "water", title: "Drink water", summary: "Use a visible daily hydration target.", category: "Wellbeing", icon: "drop", tintHex: "#278EAE", schedule: .daily, goal: .count, target: 8, unit: "glasses"),
        .init(id: "meditate", title: "Meditate", summary: "Create a quiet pause before the day takes over.", category: "Wellbeing", icon: "brain.head.profile", tintHex: "#8E64D9", schedule: .daily, goal: .duration, target: 10, unit: "minutes"),
        .init(id: "sleep", title: "No phone before bed", summary: "Protect the final 30 minutes of your evening.", category: "Digital Balance", icon: "moon.stars", tintHex: "#5B7CFA", schedule: .daily, goal: .avoidance, target: 1, unit: ""),
        .init(id: "social", title: "Social media-free day", summary: "Choose your attention instead of surrendering it.", category: "Digital Balance", icon: "iphone.slash", tintHex: "#E05A67", schedule: .flexible, goal: .avoidance, target: 1, unit: ""),
        .init(id: "gratitude", title: "Practice gratitude", summary: "Notice one specific thing worth appreciating.", category: "Mindset", icon: "heart", tintHex: "#E05A67", schedule: .daily, goal: .checkIn, target: 1, unit: "")
    ]
}

enum ProgramDifficulty: String, CaseIterable, Identifiable {
    case gentle
    case standard
    case intense

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var factor: Double {
        switch self {
        case .gentle: 0.75
        case .standard: 1
        case .intense: 1.25
        }
    }
}

struct HabitProgram: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let duration: Int
    let icon: String
    let tintHex: String
    let habits: [HabitTemplate]

    func drafts(selectedIDs: Set<String>, difficulty: ProgramDifficulty) -> [HabitDraft] {
        habits.filter { selectedIDs.contains($0.id) }.map { template in
            var draft = template.draft
            if draft.goal == .count || draft.goal == .duration {
                draft.targetCount = Int32(max(1, (Double(draft.targetCount) * difficulty.factor).rounded()))
            }
            if draft.schedule == .flexible {
                switch difficulty {
                case .gentle: draft.scheduleTarget = max(1, draft.scheduleTarget - 1)
                case .standard: break
                case .intense: draft.scheduleTarget = min(7, draft.scheduleTarget + 1)
                }
            }
            return draft
        }
    }
}

extension HabitProgram {
    private static func habit(
        _ id: String,
        _ title: String,
        _ summary: String,
        _ icon: String,
        _ color: String,
        schedule: HabitScheduleType = .daily,
        goal: HabitGoalType = .checkIn,
        target: Int32 = 1,
        unit: String = ""
    ) -> HabitTemplate {
        HabitTemplate(
            id: id,
            title: title,
            summary: summary,
            category: "Program",
            icon: icon,
            tintHex: color,
            schedule: schedule,
            goal: goal,
            target: target,
            unit: unit
        )
    }

    static let catalog: [HabitProgram] = [
        HabitProgram(
            id: "hard-reset-75",
            title: "75-Day Hard Reset",
            summary: "A demanding but adjustable consistency program for movement, learning, nutrition, and reflection.",
            duration: 75,
            icon: "mountain.2.fill",
            tintHex: "#E05A67",
            habits: [
                habit("75-outdoor", "Move outdoors", "Train outside while adapting intensity to your health and experience.", "figure.run", "#31A86A", goal: .duration, target: 45, unit: "minutes"),
                habit("75-training", "Focused training", "Complete a second purposeful movement or recovery session.", "dumbbell", "#E58A2B", goal: .duration, target: 45, unit: "minutes"),
                habit("75-read", "Read nonfiction", "Read something that develops a skill or perspective.", "book.closed", "#8E64D9", goal: .count, target: 10, unit: "pages"),
                habit("75-water", "Meet hydration goal", "Choose a hydration target appropriate for you.", "drop", "#278EAE", goal: .count, target: 8, unit: "glasses"),
                habit("75-nutrition", "Honor nutrition plan", "Follow the realistic food intention you set for yourself.", "fork.knife", "#31A86A"),
                habit("75-reflect", "Daily progress reflection", "Capture a note or private progress photo in your journal.", "camera", "#5B7CFA")
            ]
        ),
        HabitProgram(
            id: "lock-in-125",
            title: "125-Day Lock In",
            summary: "A long-horizon focus season for deep work, fitness, sleep, learning, and attention.",
            duration: 125,
            icon: "lock.fill",
            tintHex: "#5B7CFA",
            habits: [
                habit("125-deep", "Deep work block", "Protect uninterrupted time for the work that matters most.", "brain.head.profile", "#5B7CFA", goal: .duration, target: 60, unit: "minutes"),
                habit("125-move", "Train or recover", "Use movement that supports consistency instead of burnout.", "figure.strengthtraining.traditional", "#E58A2B", schedule: .flexible, goal: .duration, target: 45, unit: "minutes"),
                habit("125-read", "Read and learn", "Create a daily learning rhythm.", "book.closed", "#8E64D9", goal: .duration, target: 20, unit: "minutes"),
                habit("125-morning", "Phone-free first hour", "Begin deliberately before opening feeds and messages.", "iphone.slash", "#278EAE", goal: .avoidance),
                habit("125-sleep", "Protect sleep routine", "Keep a consistent wind-down ritual.", "moon.stars", "#5B7CFA"),
                habit("125-journal", "Evening journal", "Review the day and set tomorrow’s intention.", "book.pages", "#E05A67")
            ]
        ),
        HabitProgram(
            id: "foundation-30",
            title: "30-Day Foundation",
            summary: "A friendly starting point built around walking, water, reading, and reflection.",
            duration: 30,
            icon: "leaf.fill",
            tintHex: "#31A86A",
            habits: [
                habit("30-walk", "Daily walk", "Use a walk to make movement automatic.", "figure.walk", "#31A86A", goal: .duration, target: 20, unit: "minutes"),
                habit("30-water", "Drink water", "Keep a visible hydration rhythm.", "drop", "#278EAE", goal: .count, target: 6, unit: "glasses"),
                habit("30-read", "Read", "Build a small daily reading practice.", "book.closed", "#8E64D9", goal: .duration, target: 10, unit: "minutes"),
                habit("30-reflect", "One-line reflection", "Record one honest sentence about the day.", "pencil.line", "#E05A67")
            ]
        ),
        HabitProgram(
            id: "digital-21",
            title: "21-Day Digital Reset",
            summary: "Reclaim attention with boundaries that remain practical in everyday life.",
            duration: 21,
            icon: "iphone.slash",
            tintHex: "#278EAE",
            habits: [
                habit("21-morning", "Phone-free morning", "Delay nonessential screen use after waking.", "sun.horizon", "#E58A2B", goal: .avoidance),
                habit("21-evening", "Phone-free wind-down", "Put the phone away before sleep.", "moon.stars", "#5B7CFA", goal: .avoidance),
                habit("21-scroll", "No mindless scrolling", "Notice and interrupt automatic feed checking.", "hand.raised", "#E05A67", goal: .avoidance),
                habit("21-replace", "Offline replacement", "Read, walk, create, or connect without a screen.", "leaf", "#31A86A", goal: .duration, target: 30, unit: "minutes")
            ]
        ),
        HabitProgram(
            id: "creative-60",
            title: "60-Day Creative Sprint",
            summary: "Turn inspiration into a body of work through protected, repeatable practice.",
            duration: 60,
            icon: "paintpalette.fill",
            tintHex: "#8E64D9",
            habits: [
                habit("60-create", "Create before consuming", "Make something before opening entertainment or feeds.", "sparkles", "#8E64D9", goal: .duration, target: 30, unit: "minutes"),
                habit("60-ideas", "Capture ideas", "Collect raw material without judging it.", "lightbulb", "#E58A2B", goal: .count, target: 3, unit: "ideas"),
                habit("60-study", "Study the craft", "Learn deliberately from excellent work.", "books.vertical", "#5B7CFA", schedule: .flexible, goal: .duration, target: 30, unit: "minutes"),
                habit("60-share", "Share or review work", "Get feedback or conduct an honest personal review.", "person.2", "#E05A67", schedule: .flexible)
            ]
        ),
        HabitProgram(
            id: "mind-body-90",
            title: "90-Day Mind & Body",
            summary: "A balanced season of strength, mobility, mindfulness, sleep, and gratitude.",
            duration: 90,
            icon: "figure.mind.and.body",
            tintHex: "#31A86A",
            habits: [
                habit("90-strength", "Strength practice", "Build capability with a sustainable weekly rhythm.", "dumbbell", "#E58A2B", schedule: .flexible, goal: .duration, target: 40, unit: "minutes"),
                habit("90-mobility", "Mobility", "Keep joints and movement feeling supported.", "figure.flexibility", "#278EAE", goal: .duration, target: 10, unit: "minutes"),
                habit("90-meditate", "Mindfulness", "Pause and practice attention.", "brain.head.profile", "#8E64D9", goal: .duration, target: 10, unit: "minutes"),
                habit("90-sleep", "Consistent wind-down", "Protect the habits that make sleep easier.", "moon.stars", "#5B7CFA"),
                habit("90-gratitude", "Gratitude note", "Name something specific worth appreciating.", "heart", "#E05A67")
            ]
        )
    ]
}

struct GalleryView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    let presentedModally: Bool
    @State private var searchText = ""
    @State private var selectedTemplate: HabitTemplate?
    @State private var selectedProgram: HabitProgram?

    init(presentedModally: Bool = false) {
        self.presentedModally = presentedModally
    }

    private var filtered: [HabitTemplate] {
        guard !searchText.isEmpty else { return HabitTemplate.catalog }
        return HabitTemplate.catalog.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.category.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var categories: [String] {
        Array(Set(filtered.map(\.category))).sorted()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    programSection
                    challengeCard
                    ForEach(categories, id: \.self) { category in
                        templateSection(category)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .background(AppTheme.canvas)
            .navigationTitle("Gallery")
            .toolbar {
                if presentedModally {
                    ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                }
            }
            .searchable(text: $searchText, prompt: "Search ideas")
            .sheet(item: $selectedTemplate) { template in
                AddHabitView(template: template)
                    .environment(\.managedObjectContext, context)
            }
            .sheet(item: $selectedProgram) { program in
                ProgramSetupView(program: program)
                    .environment(\.managedObjectContext, context)
            }
        }
    }

    private var programSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Programs").font(.title2.bold())
                Text("Choose a starting point, then make every detail yours.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(HabitProgram.catalog) { program in
                        Button { selectedProgram = program } label: {
                            programCard(program)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .contentMargins(.horizontal, 0, for: .scrollContent)
        }
    }

    private func programCard(_ program: HabitProgram) -> some View {
        let color = Color(habitHex: program.tintHex) ?? .accentColor
        return VStack(alignment: .leading, spacing: 12) {
            Image(systemName: program.icon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 52, height: 52)
                .background(color.opacity(0.14), in: Circle())
            Spacer(minLength: 8)
            Text(program.title).font(.headline).foregroundStyle(.primary)
            Text("\(program.duration) days · \(program.habits.count) habits")
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(program.summary)
                .font(.caption).foregroundStyle(.secondary).lineLimit(3)
        }
        .frame(width: 230, height: 225, alignment: .leading)
        .padding(18)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens a fully customizable program")
    }

    private var challengeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("30 DAY EXPERIMENT")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("A calmer morning").font(.title3.bold())
                    Text("Build a simple wake, water, and mobility ritual.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Button("Start with Mobility") {
                        selectedTemplate = HabitTemplate.catalog.first { $0.id == "stretch" }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 3)
                }
                Image(systemName: "sun.horizon.fill")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.tint)
                    .frame(width: 70, height: 70)
                    .background(Color.accentColor.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)
            }
        }
        .padding(20)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func templateSection(_ category: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(category).font(.title3.bold())
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(filtered.filter { $0.category == category }) { template in
                    Button { selectedTemplate = template } label: {
                        templateCard(template)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func templateCard(_ template: HabitTemplate) -> some View {
        let color = Color(habitHex: template.tintHex) ?? .accentColor
        return VStack(alignment: .leading, spacing: 12) {
            Image(systemName: template.icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 42, height: 42)
                .background(color.opacity(0.13), in: Circle())
            Spacer(minLength: 0)
            Text(template.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
            Text(template.goal.title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
        .padding(15)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens a customizable habit template")
    }
}

private struct ProgramSetupView: View {
    let program: HabitProgram
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var duration: Int
    @State private var difficulty = ProgramDifficulty.standard
    @State private var selectedHabitIDs: Set<String>
    @State private var errorMessage: String?

    init(program: HabitProgram) {
        self.program = program
        _duration = State(initialValue: program.duration)
        _selectedHabitIDs = State(initialValue: Set(program.habits.map(\.id)))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 15) {
                        Image(systemName: program.icon)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color(habitHex: program.tintHex) ?? .accentColor)
                            .frame(width: 54, height: 54)
                            .background((Color(habitHex: program.tintHex) ?? .accentColor).opacity(0.14), in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text(program.title).font(.title3.bold())
                            Text(program.summary).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Customize") {
                    Stepper("\(duration) days", value: $duration, in: 7...365, step: 1)
                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(ProgramDifficulty.allCases) { level in
                            Text(level.title).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    ForEach(program.habits) { template in
                        Toggle(isOn: selectionBinding(for: template.id)) {
                            Label {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(template.title)
                                    Text(adjustedDetail(for: template))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: template.icon)
                                    .foregroundStyle(Color(habitHex: template.tintHex) ?? .accentColor)
                            }
                        }
                    }
                } header: {
                    Text("Included Habits")
                } footer: {
                    Text("Start with only what serves you. Every created habit can be renamed and fully edited afterward, including its target, schedule, notes, and reminder.")
                }

                Section {
                    Button(action: createProgram) {
                        Label(
                            "Create \(selectedHabitIDs.count) Habit\(selectedHabitIDs.count == 1 ? "" : "s")",
                            systemImage: "sparkles"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowBackground(Color.clear)
                    .disabled(selectedHabitIDs.isEmpty)
                } footer: {
                    Text("This is an independent, customizable preset—not medical guidance or an affiliation with a third-party challenge. Choose targets appropriate for you.")
                }
            }
            .navigationTitle("Customize Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .alert("Couldn’t Create Program", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) { Button("OK") { errorMessage = nil } } message: {
                Text(errorMessage ?? "Please try again.")
            }
        }
    }

    private func selectionBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { selectedHabitIDs.contains(id) },
            set: { selected in
                if selected { selectedHabitIDs.insert(id) } else { selectedHabitIDs.remove(id) }
            }
        )
    }

    private func adjustedDetail(for template: HabitTemplate) -> String {
        let draft = program.drafts(selectedIDs: [template.id], difficulty: difficulty).first ?? template.draft
        switch draft.goal {
        case .count, .duration:
            return "\(draft.targetCount) \(draft.unitName) · \(draft.schedule.title)"
        case .checkIn, .avoidance:
            return "\(draft.goal.title) · \(draft.schedule.title)"
        }
    }

    private func createProgram() {
        do {
            let drafts = program.drafts(selectedIDs: selectedHabitIDs, difficulty: difficulty)
            _ = try HabitStore.createProgram(
                drafts: drafts,
                programTitle: "\(program.title) — \(difficulty.title)",
                durationDays: duration,
                in: context
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
