// LeanAI
// UserProfile.swift
//
// Core user model storing biometrics, fitness goals, and all derived nutrition targets.
// Author: Akshat Gupta

import Foundation
import SwiftData

// MARK: - UserProfile

/// The primary user model. Stores biometrics, fitness goals, and CloudKit pairing codes.
///
/// All nutrition targets (calories, protein, fat, carbs) are derived from these values
/// using Mifflin-St Jeor BMR and standard TDEE multipliers. The model supports three
/// fitness goals: "cut" (default), "maintain", and "bulk", each adjusting macros accordingly.
///
/// CloudKit partner sharing uses a 6-character `pairCode` that the user shares with their
/// accountability partner, and a `partnerPairCode` for reading the partner's summary.
@Model
final class UserProfile {

    // MARK: - Identity

    var id: UUID
    var name: String
    var dateOfBirth: Date

    /// "male" or "female" — determines BMR sex-adjustment (+5 or -161) and calorie floors.
    var biologicalSex: String

    // MARK: - Body Metrics

    var heightCm: Double
    var currentWeightKg: Double

    /// Weight at the start of a cut/bulk cycle — used to compute progress percentage.
    var startWeightKg: Double

    var targetWeightKg: Double

    // MARK: - Preferences

    /// Activity level index: 0 = sedentary, 1 = lightly active, 2 = moderately active, 3 = very active.
    /// Maps to TDEE multipliers [1.2, 1.35, 1.5, 1.65].
    var activityLevel: Int

    var startDate: Date

    /// User's Groq API key stored locally (never sent to any backend other than Groq).
    var groqAPIKey: String

    /// Fitness goal string: "cut" | "maintain" | "bulk". Nil defaults to "cut".
    var fitnessGoal: String?

    // MARK: - Partner Sharing (CloudKit)

    /// When true this profile represents the partner, not the primary user.
    var isPartnerProfile: Bool

    /// Display name for the partner's profile (e.g. girlfriend's name).
    var partnerName: String

    var createdAt: Date

    /// Your unique 6-char share code — give this to your partner so they can see your summary.
    var pairCode: String

    /// Your partner's 6-char code — enter theirs to see their summary.
    var partnerPairCode: String

    // MARK: - Relationships

    @Relationship(deleteRule: .cascade) var dailyLogs: [DailyLog]
    @Relationship(deleteRule: .cascade) var strengthTests: [StrengthTestEntry]
    @Relationship(deleteRule: .cascade) var measurements: [BodyMeasurement]

    // MARK: - Initialiser

    /// Creates a new user profile with the given biometrics. `startWeightKg` is set to
    /// `currentWeightKg` automatically. A random 6-character `pairCode` is generated from a UUID.
    init(
        name: String,
        dateOfBirth: Date,
        biologicalSex: String,
        heightCm: Double,
        currentWeightKg: Double,
        targetWeightKg: Double,
        activityLevel: Int,
        groqAPIKey: String = "",
        fitnessGoal: String? = nil,
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
        self.fitnessGoal = fitnessGoal
        self.isPartnerProfile = isPartnerProfile
        self.partnerName = partnerName
        self.createdAt = Date()
        self.dailyLogs = []
        self.strengthTests = []
        self.measurements = []
        // Generate a unique 6-char pair code from a new UUID (separate from self.id)
        let uuidStr = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        self.pairCode = String(uuidStr.prefix(6)).uppercased()
        self.partnerPairCode = ""
    }

    // MARK: - Derived Age

    /// Age in whole years computed from `dateOfBirth` to today.
    var ageYears: Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
    }

    // MARK: - Fitness Goal

    /// Resolved fitness goal, falling back to "cut" when `fitnessGoal` is nil.
    var resolvedFitnessGoal: String { fitnessGoal ?? "cut" }

    // MARK: - BMR & TDEE

    /// Basal Metabolic Rate using the Mifflin-St Jeor equation.
    ///
    /// Formula:
    /// - Male:   (10 × kg) + (6.25 × cm) − (5 × age) + 5
    /// - Female: (10 × kg) + (6.25 × cm) − (5 × age) − 161
    var bmr: Double {
        let raw: Double
        if biologicalSex == "male" {
            raw = (10 * currentWeightKg) + (6.25 * heightCm) - (5 * Double(ageYears)) + 5
        } else {
            raw = (10 * currentWeightKg) + (6.25 * heightCm) - (5 * Double(ageYears)) - 161
        }
        return raw
    }

    /// Total Daily Energy Expenditure = BMR × activity multiplier.
    /// Multipliers are conservative lower-end values: [1.2, 1.35, 1.5, 1.65].
    var tdee: Double {
        let multipliers: [Double] = [1.2, 1.35, 1.5, 1.65]
        let idx = min(activityLevel, multipliers.count - 1)
        return bmr * multipliers[idx]
    }

    // MARK: - Daily Nutrition Targets

    /// Daily calorie target adjusted by fitness goal.
    ///
    /// - Cut:      TDEE − 500 kcal (≈ 0.5 kg/week fat loss), floored at 1500/1200 kcal.
    /// - Maintain: TDEE (no deficit).
    /// - Bulk:     TDEE + 300 kcal (lean surplus for muscle growth).
    var dailyCalorieTarget: Double {
        let floor = biologicalSex == "male" ? 1500.0 : 1200.0
        switch resolvedFitnessGoal {
        case "bulk":     return tdee + 300
        case "maintain": return tdee
        default:         return max(tdee - 500, floor) // cut
        }
    }

    /// Daily protein target in grams, scaled per goal (g/kg body weight).
    ///
    /// Ratios used:
    /// - Cut:      1.8 g/kg — high enough to preserve muscle in deficit.
    /// - Maintain: 1.6 g/kg — standard maintenance level.
    /// - Bulk:     2.0 g/kg — extra supply for muscle synthesis.
    var dailyProteinGrams: Double {
        let ratio: Double
        switch resolvedFitnessGoal {
        case "bulk":     ratio = 2.0
        case "maintain": ratio = 1.6
        default:         ratio = 1.8 // cut
        }
        return currentWeightKg * ratio
    }

    /// Daily fat target in grams. Minimum threshold for hormonal health, scaled by goal.
    ///
    /// Ratios used:
    /// - Cut:      0.7 g/kg (minimum safe threshold)
    /// - Maintain: 0.8 g/kg
    /// - Bulk:     0.9 g/kg (supports anabolic hormones during surplus)
    var dailyFatGrams: Double {
        let ratio: Double
        switch resolvedFitnessGoal {
        case "bulk":     ratio = 0.9
        case "maintain": ratio = 0.8
        default:         ratio = 0.7 // cut
        }
        return currentWeightKg * ratio
    }

    /// Daily carb target: remaining calories after protein (4 kcal/g) and fat (9 kcal/g).
    /// Floored at 50g to prevent unintentional ketosis.
    var dailyCarbsGrams: Double {
        let proteinCals = dailyProteinGrams * 4
        let fatCals = dailyFatGrams * 9
        let remaining = dailyCalorieTarget - proteinCals - fatCals
        return max(remaining / 4, 50)  // minimum 50g carbs
    }

    // MARK: - Progress Metrics

    /// Total weight to lose from start weight to target (0 if already at/below target).
    var totalWeightToLoseKg: Double {
        return max(startWeightKg - targetWeightKg, 0)
    }

    /// Weight lost so far compared to start weight.
    var weightLostSoFarKg: Double {
        return max(startWeightKg - currentWeightKg, 0)
    }

    /// Progress as a fraction from 0.0 to 1.0. Returns 1.0 if no weight to lose.
    var progressPercent: Double {
        guard totalWeightToLoseKg > 0 else { return 1.0 }
        return min(weightLostSoFarKg / totalWeightToLoseKg, 1.0)
    }

    /// Estimated weeks remaining to reach target weight at a conservative 0.5 kg/week rate.
    var estimatedWeeksToGoal: Int {
        let remaining = currentWeightKg - targetWeightKg
        guard remaining > 0 else { return 0 }
        return Int(ceil(remaining / 0.5))  // 0.5 kg/week conservative estimate
    }

    // MARK: - Display Helpers

    /// Human-readable label for `activityLevel`.
    var activityLevelLabel: String {
        switch activityLevel {
        case 0: return "Sedentary"
        case 1: return "Lightly Active"
        case 2: return "Moderately Active"
        case 3: return "Very Active"
        default: return "Sedentary"
        }
    }

    /// Human-readable label for the resolved fitness goal.
    var fitnessGoalLabel: String {
        switch resolvedFitnessGoal {
        case "bulk":     return "Bulk"
        case "maintain": return "Maintain"
        default:         return "Cut"
        }
    }

    /// SF Symbol name representing the current fitness goal direction.
    var fitnessGoalIcon: String {
        switch resolvedFitnessGoal {
        case "bulk":     return "arrow.up.circle.fill"
        case "maintain": return "equal.circle.fill"
        default:         return "arrow.down.circle.fill"
        }
    }
}
