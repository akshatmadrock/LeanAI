// LeanAI
// DailyLog.swift
//
// One record per calendar day, aggregating food entries, activity entries, and step data.
// Author: Akshat Gupta

import Foundation
import SwiftData

// MARK: - DailyLog

/// A single day's log record. Normalised to the start of the day (midnight) so that exactly
/// one `DailyLog` exists per calendar date per user.
///
/// Calorie totals are computed lazily from the child `foodEntries` and `activityEntries`
/// relationships. `morningWeightKg` is optional — the user doesn't have to weigh in daily.
@Model
final class DailyLog {

    // MARK: - Identity

    var id: UUID

    /// The date this log represents, always normalised to `startOfDay` (midnight).
    var date: Date

    // MARK: - Daily Data

    /// Morning fasted weight in kg. Optional — user may skip on a given day.
    var morningWeightKg: Double?

    /// Step count synced from HealthKit (or entered manually).
    var steps: Int

    /// Free-form notes for the day (e.g. "feeling tired, skipped gym").
    var notes: String

    var createdAt: Date

    // MARK: - Relationships

    @Relationship(deleteRule: .cascade) var foodEntries: [FoodEntry]
    @Relationship(deleteRule: .cascade) var activityEntries: [ActivityEntry]

    // MARK: - Initialiser

    /// Creates a new log for the given date, normalised to midnight.
    /// - Parameter date: Any `Date` within the target calendar day.
    init(date: Date) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.morningWeightKg = nil
        self.steps = 0
        self.notes = ""
        self.createdAt = Date()
        self.foodEntries = []
        self.activityEntries = []
    }

    // MARK: - Computed Nutrition Totals

    /// Sum of calories across all food entries for this day.
    var totalCaloriesConsumed: Double {
        foodEntries.reduce(0) { $0 + $1.calories }
    }

    /// Total protein in grams from all food entries.
    var totalProteinG: Double {
        foodEntries.reduce(0) { $0 + $1.proteinG }
    }

    /// Total carbohydrates in grams from all food entries.
    var totalCarbsG: Double {
        foodEntries.reduce(0) { $0 + $1.carbsG }
    }

    /// Total fat in grams from all food entries.
    var totalFatG: Double {
        foodEntries.reduce(0) { $0 + $1.fatG }
    }

    /// Total dietary fiber in grams from all food entries.
    var totalFiberG: Double {
        foodEntries.reduce(0) { $0 + $1.fiberG }
    }

    // MARK: - Computed Activity Totals

    /// Combined calories burned from logged activities plus step-based burn estimate.
    var totalCaloriesBurned: Double {
        let activityBurn = activityEntries.reduce(0.0) { $0 + $1.caloriesBurned }
        return activityBurn + stepCaloriesBurned
    }

    /// Estimated calories burned from step count.
    ///
    /// Uses a simplified constant of 0.04 kcal/step, which approximates MET 3.5 (brisk walk)
    /// for a ~75 kg person. The `ActivityCalculator.stepsToCalories` method provides a more
    /// accurate height- and weight-adjusted calculation when the full profile is available.
    var stepCaloriesBurned: Double {
        // Each step ≈ 0.04 kcal for a ~75 kg person (rough avg)
        return Double(steps) * 0.04
    }

    // MARK: - Calorie Balance

    /// Net calorie balance for the day relative to the user's target.
    ///
    /// Negative value means the user ate less than (target + activity burn) — good for fat loss.
    /// - Parameter targetCalories: The user's daily calorie target from `UserProfile.dailyCalorieTarget`.
    /// - Returns: Consumed calories minus (target + calories burned). Negative = deficit.
    func netBalance(targetCalories: Double) -> Double {
        return totalCaloriesConsumed - (targetCalories + totalCaloriesBurned)
    }

    /// Whether the day is considered "on track" for both calorie and protein goals.
    ///
    /// Calorie check: consumed ≤ target + 50% of activity burn (allows partial credit for burn).
    /// Protein check: consumed ≥ 85% of protein target (muscle-preservation threshold).
    /// - Parameters:
    ///   - targetCalories: Daily calorie target from `UserProfile`.
    ///   - proteinTarget: Daily protein target in grams from `UserProfile`.
    /// - Returns: `true` only when both calorie and protein conditions are satisfied.
    func isOnTrack(targetCalories: Double, proteinTarget: Double) -> Bool {
        let balanceOK = totalCaloriesConsumed <= targetCalories + (totalCaloriesBurned * 0.5)
        let proteinOK = totalProteinG >= proteinTarget * 0.85
        return balanceOK && proteinOK
    }
}
