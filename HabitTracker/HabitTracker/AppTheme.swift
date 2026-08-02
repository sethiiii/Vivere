import SwiftUI

enum AppTheme {
    static let accent = Color.accentColor
    static let canvas = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let subtleFill = Color.primary.opacity(0.055)
}

enum AppAccentTheme: String, CaseIterable, Identifiable {
    case indigo
    case monochrome
    case forest
    case ocean
    case sunset
    case berry

    var id: String { rawValue }

    var title: String {
        switch self {
        case .indigo: "Indigo"
        case .monochrome: "Mono"
        case .forest: "Forest"
        case .ocean: "Ocean"
        case .sunset: "Sunset"
        case .berry: "Berry"
        }
    }

    var color: Color {
        switch self {
        case .indigo: Color(red: 0.32, green: 0.45, blue: 0.96)
        case .monochrome: .primary
        case .forest: Color(red: 0.12, green: 0.52, blue: 0.34)
        case .ocean: Color(red: 0.04, green: 0.48, blue: 0.69)
        case .sunset: Color(red: 0.88, green: 0.35, blue: 0.24)
        case .berry: Color(red: 0.66, green: 0.25, blue: 0.58)
        }
    }
}

extension Color {
    init?(habitHex: String?) {
        guard let habitHex else { return nil }
        let cleaned = habitHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    static func readableForeground(forHabitHex hex: String?) -> Color {
        guard let hex else { return .white }
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else { return .white }
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return luminance > 0.62 ? .black : .white
    }
}

extension Habit {
    var tintColor: Color { Color(habitHex: tintHex) ?? AppTheme.accent }
    var tintForegroundColor: Color { .readableForeground(forHabitHex: tintHex) }
    var displayIcon: String {
        guard let iconName, !iconName.isEmpty else { return "checkmark" }
        return iconName
    }
}
