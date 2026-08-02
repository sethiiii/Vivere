import SwiftUI
import UIKit

enum AppTheme {
    static let accent = Color.accentColor
    static let canvas = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let subtleFill = Color.primary.opacity(0.055)
}

enum AppAccentTheme: String, CaseIterable, Identifiable {
    case monochrome
    case red
    case sunset
    case ocean
    case forest
    case indigo
    case berry

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monochrome: "Mono"
        case .red: "Red"
        case .sunset: "Orange"
        case .ocean: "Yellow"
        case .forest: "Green"
        case .indigo: "Blue"
        case .berry: "Purple"
        }
    }

    var color: Color {
        switch self {
        case .monochrome:
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(white: 0.58, alpha: 1)
                    : .black
            })
        case .red: Color(red: 0.86, green: 0.18, blue: 0.22)
        case .sunset: Color(red: 0.88, green: 0.35, blue: 0.24)
        case .ocean: Color(red: 0.95, green: 0.72, blue: 0.10)
        case .forest: Color(red: 0.12, green: 0.52, blue: 0.34)
        case .indigo: Color(red: 0.24, green: 0.43, blue: 0.96)
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
