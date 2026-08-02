import Foundation

enum QuoteCategory: String, CaseIterable, Identifiable {
    case all
    case philosophy
    case resilience
    case creativity
    case leadership
    case sport

    var id: String { rawValue }
    var title: String { rawValue == "all" ? "All Categories" : rawValue.capitalized }
}

struct MotivationalQuote: Identifiable, Hashable {
    let id: String
    let text: String
    let author: String
    let category: QuoteCategory
    let source: String?
}

extension MotivationalQuote {
    static let library: [MotivationalQuote] = [
        .init(id: "aurelius-1", text: "You have power over your mind—not outside events. Realize this, and you will find strength.", author: "Marcus Aurelius", category: .philosophy, source: "Meditations"),
        .init(id: "aurelius-2", text: "The happiness of your life depends upon the quality of your thoughts.", author: "Marcus Aurelius", category: .philosophy, source: "Meditations"),
        .init(id: "seneca-1", text: "While we are postponing, life speeds by.", author: "Seneca", category: .philosophy, source: "Letters from a Stoic"),
        .init(id: "seneca-2", text: "Luck is what happens when preparation meets opportunity.", author: "Seneca", category: .resilience, source: nil),
        .init(id: "epictetus-1", text: "No great thing is created suddenly.", author: "Epictetus", category: .philosophy, source: "Discourses"),
        .init(id: "epictetus-2", text: "First say to yourself what you would be; and then do what you have to do.", author: "Epictetus", category: .resilience, source: "Discourses"),
        .init(id: "laozi-1", text: "A journey of a thousand miles begins with a single step.", author: "Lao Tzu", category: .philosophy, source: "Tao Te Ching"),
        .init(id: "confucius-1", text: "It does not matter how slowly you go as long as you do not stop.", author: "Confucius", category: .resilience, source: nil),
        .init(id: "roosevelt-1", text: "Believe you can and you're halfway there.", author: "Theodore Roosevelt", category: .leadership, source: nil),
        .init(id: "roosevelt-2", text: "Do what you can, with what you have, where you are.", author: "Theodore Roosevelt", category: .resilience, source: nil),
        .init(id: "lincoln-1", text: "I will prepare and someday my chance will come.", author: "Abraham Lincoln", category: .leadership, source: nil),
        .init(id: "douglass-1", text: "If there is no struggle, there is no progress.", author: "Frederick Douglass", category: .resilience, source: "West India Emancipation speech"),
        .init(id: "emerson-1", text: "Nothing great was ever achieved without enthusiasm.", author: "Ralph Waldo Emerson", category: .creativity, source: "Circles"),
        .init(id: "emerson-2", text: "Adopt the pace of nature: her secret is patience.", author: "Ralph Waldo Emerson", category: .philosophy, source: nil),
        .init(id: "thoreau-1", text: "Go confidently in the direction of your dreams. Live the life you have imagined.", author: "Henry David Thoreau", category: .creativity, source: "Walden"),
        .init(id: "wilde-1", text: "Be yourself; everyone else is already taken.", author: "Oscar Wilde", category: .creativity, source: nil),
        .init(id: "shakespeare-1", text: "Our doubts are traitors, and make us lose the good we oft might win, by fearing to attempt.", author: "William Shakespeare", category: .resilience, source: "Measure for Measure"),
        .init(id: "shakespeare-2", text: "To thine own self be true.", author: "William Shakespeare", category: .philosophy, source: "Hamlet"),
        .init(id: "twain-1", text: "The secret of getting ahead is getting started.", author: "Mark Twain", category: .resilience, source: nil),
        .init(id: "nightingale-1", text: "I attribute my success to this: I never gave or took any excuse.", author: "Florence Nightingale", category: .leadership, source: nil),
        .init(id: "keller-1", text: "Life is either a daring adventure or nothing.", author: "Helen Keller", category: .resilience, source: "The Open Door"),
        .init(id: "addams-1", text: "Action indeed is the sole medium of expression for ethics.", author: "Jane Addams", category: .leadership, source: "Democracy and Social Ethics"),
        .init(id: "ali-1", text: "Don't count the days; make the days count.", author: "Muhammad Ali", category: .sport, source: nil),
        .init(id: "ruth-1", text: "Every strike brings me closer to the next home run.", author: "Babe Ruth", category: .sport, source: nil),
        .init(id: "lombardi-1", text: "Perfection is not attainable, but if we chase perfection we can catch excellence.", author: "Vince Lombardi", category: .sport, source: nil),
        .init(id: "ashe-1", text: "Start where you are. Use what you have. Do what you can.", author: "Arthur Ashe", category: .sport, source: nil),
        .init(id: "wooden-1", text: "Make each day your masterpiece.", author: "John Wooden", category: .sport, source: nil),
        .init(id: "earhart-1", text: "The most difficult thing is the decision to act; the rest is merely tenacity.", author: "Amelia Earhart", category: .resilience, source: nil),
        .init(id: "curie-1", text: "Nothing in life is to be feared; it is only to be understood.", author: "Marie Curie", category: .resilience, source: nil),
        .init(id: "davinci-1", text: "Simplicity is the ultimate sophistication.", author: "Leonardo da Vinci", category: .creativity, source: nil)
    ]

    static func daily(category: QuoteCategory, on date: Date = Date(), calendar: Calendar = .current) -> MotivationalQuote {
        let candidates = category == .all ? library : library.filter { $0.category == category }
        let pool = candidates.isEmpty ? library : candidates
        guard !pool.isEmpty else {
            return MotivationalQuote(
                id: "fallback",
                text: "Begin again with one small step.",
                author: "HabitTracker",
                category: .resilience,
                source: nil
            )
        }
        let day = max(calendar.ordinality(of: .day, in: .era, for: date) ?? 0, 0)
        return pool[day % pool.count]
    }
}

enum QuoteFavorites {
    static func decode(_ storedValue: String) -> Set<String> {
        Set(storedValue.split(separator: "|").map(String.init))
    }

    static func encode(_ identifiers: Set<String>) -> String {
        identifiers.sorted().joined(separator: "|")
    }

    static func toggle(_ identifier: String, in storedValue: String) -> String {
        var identifiers = decode(storedValue)
        if identifiers.contains(identifier) {
            identifiers.remove(identifier)
        } else {
            identifiers.insert(identifier)
        }
        return encode(identifiers)
    }
}
