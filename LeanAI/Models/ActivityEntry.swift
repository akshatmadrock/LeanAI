import Foundation
import SwiftData

@Model
final class ActivityEntry {
    var id: UUID
    var activityName: String
    var activityCategory: String        // "cardio" | "strength" | "sport" | "steps"
    var durationMinutes: Double
    var caloriesBurned: Double
    var intensityLevel: Int             // 0=light, 1=moderate, 2=intense
    var met: Double                     // metabolic equivalent used in calculation
    var timestamp: Date
    var notes: String
    var aiEstimated: Bool               // true if Groq API estimated this

    init(
        activityName: String,
        activityCategory: String,
        durationMinutes: Double,
        caloriesBurned: Double,
        intensityLevel: Int,
        met: Double,
        notes: String = "",
        aiEstimated: Bool = false
    ) {
        self.id = UUID()
        self.activityName = activityName
        self.activityCategory = activityCategory
        self.durationMinutes = durationMinutes
        self.caloriesBurned = caloriesBurned
        self.intensityLevel = intensityLevel
        self.met = met
        self.timestamp = Date()
        self.notes = notes
        self.aiEstimated = aiEstimated
    }

    var intensityLabel: String {
        switch intensityLevel {
        case 0: return "Light"
        case 1: return "Moderate"
        case 2: return "Intense"
        default: return "Moderate"
        }
    }

    var categoryIcon: String {
        switch activityCategory {
        case "cardio": return "heart.fill"
        case "strength": return "dumbbell.fill"
        case "sport": return "figure.pickleball"
        case "steps": return "figure.walk"
        default: return "flame.fill"
        }
    }

    var durationFormatted: String {
        let mins = Int(durationMinutes)
        if mins >= 60 {
            let h = mins / 60
            let m = mins % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(mins)m"
    }
}

// MARK: - Preset activities with MET values
struct ActivityPreset: Identifiable {
    let id = UUID()
    let name: String
    let category: String
    let lightMET: Double
    let moderateMET: Double
    let intenseMET: Double

    static let presets: [ActivityPreset] = [
        ActivityPreset(name: "Walking / Steps", category: "steps", lightMET: 2.5, moderateMET: 3.5, intenseMET: 4.5),
        ActivityPreset(name: "Running", category: "cardio", lightMET: 6.0, moderateMET: 9.0, intenseMET: 12.0),
        ActivityPreset(name: "Cycling", category: "cardio", lightMET: 4.0, moderateMET: 6.8, intenseMET: 10.0),
        ActivityPreset(name: "Weightlifting", category: "strength", lightMET: 2.5, moderateMET: 3.5, intenseMET: 5.5),
        ActivityPreset(name: "Pickleball", category: "sport", lightMET: 4.5, moderateMET: 6.0, intenseMET: 8.0),
        ActivityPreset(name: "Basketball", category: "sport", lightMET: 4.5, moderateMET: 6.5, intenseMET: 8.0),
        ActivityPreset(name: "Swimming", category: "cardio", lightMET: 4.0, moderateMET: 6.0, intenseMET: 9.8),
        ActivityPreset(name: "Yoga", category: "cardio", lightMET: 2.0, moderateMET: 3.0, intenseMET: 4.0),
        ActivityPreset(name: "HIIT", category: "cardio", lightMET: 6.0, moderateMET: 8.0, intenseMET: 12.0),
        ActivityPreset(name: "Tennis", category: "sport", lightMET: 4.5, moderateMET: 7.0, intenseMET: 8.5),
        ActivityPreset(name: "Soccer", category: "sport", lightMET: 5.0, moderateMET: 7.0, intenseMET: 10.0),
        ActivityPreset(name: "Jump Rope", category: "cardio", lightMET: 8.0, moderateMET: 10.0, intenseMET: 12.0),
        ActivityPreset(name: "Custom (AI)", category: "cardio", lightMET: 3.5, moderateMET: 5.0, intenseMET: 7.0),
    ]

    func met(for intensity: Int) -> Double {
        switch intensity {
        case 0: return lightMET
        case 2: return intenseMET
        default: return moderateMET
        }
    }
}
