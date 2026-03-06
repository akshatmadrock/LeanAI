import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var name: String
    var dateOfBirth: Date
    var biologicalSex: String           // "male" | "female"
    var heightCm: Double
    var currentWeightKg: Double
    var startWeightKg: Double
    var targetWeightKg: Double
    var activityLevel: Int              // 0=sedentary, 1=lightly, 2=moderately, 3=very active
    var startDate: Date
    var groqAPIKey: String
    var isPartnerProfile: Bool
    var partnerName: String             // GF's name when isPartnerProfile = true
    var createdAt: Date
    /// Your unique 6-char share code — give this to your partner so they can see your summary
    var pairCode: String
    /// Your partner's 6-char code — enter theirs to see their summary
    var partnerPairCode: String

    @Relationship(deleteRule: .cascade) var dailyLogs: [DailyLog]
    @Relationship(deleteRule: .cascade) var strengthTests: [StrengthTestEntry]
    @Relationship(deleteRule: .cascade) var measurements: [BodyMeasurement]

    init(
        name: String,
        dateOfBirth: Date,
        biologicalSex: String,
        heightCm: Double,
        currentWeightKg: Double,
        targetWeightKg: Double,
        activityLevel: Int,
        groqAPIKey: String = "",
        isPartnerProfile: Bool = false,
        partnerName: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.dateOfBirth = dateOfBirth
        self.biologicalSex = biologicalSex
        self.heightCm = heightCm
        self.currentWeightKg = currentWeightKg
        self.startWeightKg = currentWeightKg
        self.targetWeightKg = targetWeightKg
        self.activityLevel = activityLevel
        self.startDate = Date()
        self.groqAPIKey = groqAPIKey
        self.isPartnerProfile = isPartnerProfile
        self.partnerName = partnerName
        self.createdAt = Date()
        self.dailyLogs = []
        self.strengthTests = []
        self.measurements = []
        // Generate a unique 6-char pair code from the UUID
        let uuidStr = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        self.pairCode = String(uuidStr.prefix(6)).uppercased()
        self.partnerPairCode = ""
    }

    var ageYears: Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
    }

    // Conservative BMR using Mifflin-St Jeor × 0.95
    var bmr: Double {
        let raw: Double
        if biologicalSex == "male" {
            raw = (10 * currentWeightKg) + (6.25 * heightCm) - (5 * Double(ageYears)) + 5
        } else {
            raw = (10 * currentWeightKg) + (6.25 * heightCm) - (5 * Double(ageYears)) - 161
        }
        return raw
    }

    // Conservative TDEE multipliers (lower end of standard ranges)
    var tdee: Double {
        let multipliers: [Double] = [1.2, 1.35, 1.5, 1.65]
        let idx = min(activityLevel, multipliers.count - 1)
        return bmr * multipliers[idx]
    }

    // 500 kcal/day deficit, floored at 1500 (men) / 1200 (women)
    var dailyCalorieTarget: Double {
        let floor = biologicalSex == "male" ? 1500.0 : 1200.0
        return max(tdee - 500, floor)
    }

    // Protein: 2.2 g/kg body weight
    var dailyProteinGrams: Double {
        return currentWeightKg * 2.2
    }

    // Fat: 0.7 g/kg body weight minimum
    var dailyFatGrams: Double {
        return currentWeightKg * 0.7
    }

    // Carbs: remaining calories after protein (4 kcal/g) and fat (9 kcal/g)
    var dailyCarbsGrams: Double {
        let proteinCals = dailyProteinGrams * 4
        let fatCals = dailyFatGrams * 9
        let remaining = dailyCalorieTarget - proteinCals - fatCals
        return max(remaining / 4, 50)  // minimum 50g carbs
    }

    var totalWeightToLoseKg: Double {
        return max(startWeightKg - targetWeightKg, 0)
    }

    var weightLostSoFarKg: Double {
        return max(startWeightKg - currentWeightKg, 0)
    }

    var progressPercent: Double {
        guard totalWeightToLoseKg > 0 else { return 1.0 }
        return min(weightLostSoFarKg / totalWeightToLoseKg, 1.0)
    }

    var estimatedWeeksToGoal: Int {
        let remaining = currentWeightKg - targetWeightKg
        guard remaining > 0 else { return 0 }
        return Int(ceil(remaining / 0.5))  // 0.5 kg/week conservative estimate
    }

    var activityLevelLabel: String {
        switch activityLevel {
        case 0: return "Sedentary"
        case 1: return "Lightly Active"
        case 2: return "Moderately Active"
        case 3: return "Very Active"
        default: return "Sedentary"
        }
    }
}
