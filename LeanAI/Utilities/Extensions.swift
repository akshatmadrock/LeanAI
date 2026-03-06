import SwiftUI
import Foundation

// MARK: - Date Extensions

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    var dayOfWeekShort: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: self)
    }

    var dayOfWeekFull: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: self)
    }

    var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }

    var timeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    var monthYearFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: self)
    }

    func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: self) ?? self
    }

    func weeksAgo(_ weeks: Int) -> Date {
        Calendar.current.date(byAdding: .weekOfYear, value: -weeks, to: self) ?? self
    }

    var ageYears: Int {
        Calendar.current.dateComponents([.year], from: self, to: Date()).year ?? 0
    }
}

// MARK: - Double Extensions

extension Double {
    /// Format as integer (e.g., "2,400")
    var kcalFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: self)) ?? "\(Int(self))"
    }

    /// Format with 1 decimal place (e.g., "84.2")
    var oneDecimal: String {
        String(format: "%.1f", self)
    }

    /// Format with 0 decimal places (e.g., "84")
    var zeroDecimals: String {
        String(format: "%.0f", self)
    }

    /// Format grams (e.g., "156g")
    var gramsFormatted: String {
        "\(Int(self.rounded()))g"
    }

    /// Format kg (e.g., "84.2 kg")
    var kgFormatted: String {
        "\(String(format: "%.1f", self)) kg"
    }

    /// Format cm (e.g., "175 cm")
    var cmFormatted: String {
        "\(Int(self.rounded())) cm"
    }

    /// Clamp to a range
    func clamped(to range: ClosedRange<Double>) -> Double {
        return max(range.lowerBound, min(range.upperBound, self))
    }

    /// Safe division returning 0 if denominator is 0
    func safeDivide(by denominator: Double) -> Double {
        guard denominator != 0 else { return 0 }
        return self / denominator
    }

    /// Progress fraction clamped to [0, 1]
    func progressFraction(of total: Double) -> Double {
        return (self / total).clamped(to: 0...1)
    }
}

// MARK: - Color Extensions

extension Color {
    // App color palette — dark-themed fitness aesthetic
    static let leanGreen = Color(red: 0.18, green: 0.88, blue: 0.50)      // success / on track
    static let leanBlue = Color(red: 0.25, green: 0.60, blue: 1.0)        // calories
    static let leanOrange = Color(red: 1.0, green: 0.60, blue: 0.15)      // protein
    static let leanPurple = Color(red: 0.70, green: 0.35, blue: 1.0)      // carbs
    static let leanRed = Color(red: 1.0, green: 0.30, blue: 0.30)         // alert / over target
    static let leanYellow = Color(red: 1.0, green: 0.85, blue: 0.10)      // fat / streak
    static let leanGray = Color(red: 0.35, green: 0.35, blue: 0.40)       // secondary text
    static let cardBackground = Color(red: 0.12, green: 0.12, blue: 0.15) // card bg
    static let appBackground = Color(red: 0.06, green: 0.06, blue: 0.08)  // main bg

    static func forMacro(_ macro: String) -> Color {
        switch macro {
        case "protein": return .leanOrange
        case "carbs": return .leanPurple
        case "fat": return .leanYellow
        case "calories": return .leanBlue
        default: return .leanGray
        }
    }

    static func deficitColor(remaining: Double) -> Color {
        if remaining > 200 { return .leanGreen }
        if remaining > 0 { return .leanYellow }
        return .leanRed
    }
}

// MARK: - View Modifiers

extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(16)
    }

    func sectionHeaderStyle() -> some View {
        self
            .font(.headline)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal)
            .padding(.top, 8)
    }
}

// MARK: - Array Extensions

extension Array {
    /// Safe subscript — returns nil instead of crashing on out-of-bounds
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension [Double] {
    var average: Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
}

// MARK: - Int Extension

extension Int {
    var stepsFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
