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

struct GalleryView: View {
    @Environment(\.managedObjectContext) private var context
    @State private var searchText = ""
    @State private var selectedTemplate: HabitTemplate?

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
            .searchable(text: $searchText, prompt: "Search ideas")
            .sheet(item: $selectedTemplate) { template in
                AddHabitView(template: template)
                    .environment(\.managedObjectContext, context)
            }
        }
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
