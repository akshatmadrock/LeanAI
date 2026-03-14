// LeanAI
// ActivityCalculator.swift
//
// MET-based calorie burn calculations for steps, preset activities, and strength sessions.
// Author: Akshat Gupta

import Foundation

// MARK: - ActivityCalculator

/// Stateless utility for exercise calorie estimation based on Metabolic Equivalent of Task (MET) values.
///
/// The core formula — `Calories = MET × weight_kg × (duration_hours)` — is sourced from the
/// Compendium of Physical Activities (Ainsworth et al., 2011). All methods are static.
///
/// The AI-powered estimator in `GroqService.estimateActivityCalories` uses the same formula
/// but leverages LLaMA 3.3 to select an appropriate MET value for arbitrary activity descriptions.
struct ActivityCalculator {

    // MARK: - Core MET Formula

    /// Calculate calories burned from a known MET value, body weight, and duration.
    ///
    /// Formula: Calories = MET × weight_kg × (duration_minutes / 60)
    ///
    /// - Parameters:
    ///   - met: Metabolic Equivalent of Task. 1.0 = resting; typical exercise range 2.5–12.
    ///   - weightKg: User's body weight in kilograms.
    ///   - durationMinutes: Activity duration in minutes.
    /// - Returns: Estimated kilocalories burned.
    static func calories(
        met: Double,
        weightKg: Double,
        durationMinutes: Double
    ) -> Double {
        return met * weightKg * (durationMinutes / 60.0)
    }

    // MARK: - Step Count to Calories

    /// Convert a HealthKit step count to estimated calories burned.
    ///
    /// Approach:
    /// 1. Estimate stride length from height: stride ≈ height × 0.414 (brisk walking coefficient).
    /// 2. Compute distance: steps × stride length (metres) ÷ 1000 = kilometres.
    /// 3. Compute duration at a brisk-walk pace of 5 km/h.
    /// 4. Apply MET 3.5 (brisk walking) using the core formula.
    ///
    /// This is more accurate than a simple per-step constant because it accounts for the user's
    /// height (taller people take longer strides and cover more ground per step).
    ///
    /// - Parameters:
    ///   - steps: Total step count for the period.
    ///   - weightKg: User's body weight in kilograms.
    ///   - heightCm: User's height in centimetres (used to estimate stride length).
    /// - Returns: Estimated kilocalories burned. Returns 0 if steps ≤ 0.
    static func stepsToCalories(
        steps: Int,
        weightKg: Double,
        heightCm: Double
    ) -> Double {
        guard steps > 0 else { return 0 }
        // Stride length ≈ height × 0.414 (empirical coefficient for brisk walking)
        let strideLengthM = heightCm / 100.0 * 0.414
        let distanceKm = Double(steps) * strideLengthM / 1000.0
        let durationHours = distanceKm / 5.0  // assume 5 km/h brisk walk pace
        return 3.5 * weightKg * durationHours  // MET 3.5 for brisk walking
    }

    // MARK: - Preset Activity Calculations

    /// Calculate calories for a preset activity at a given intensity level.
    ///
    /// - Parameters:
    ///   - preset: One of the predefined `ActivityPreset` values.
    ///   - intensityLevel: Intensity index; meaning varies by preset (see `ActivityPreset.met(for:)`).
    ///   - durationMinutes: Duration in minutes.
    ///   - weightKg: User's body weight in kilograms.
    /// - Returns: Estimated kilocalories burned.
    static func caloriesForPreset(
        preset: ActivityPreset,
        intensityLevel: Int,
        durationMinutes: Double,
        weightKg: Double
    ) -> Double {
        let met = preset.met(for: intensityLevel)
        return calories(met: met, weightKg: weightKg, durationMinutes: durationMinutes)
    }

    // MARK: - Weekly Activity Summary

    /// Aggregated activity statistics across all entries in a given period.
    struct WeeklyActivitySummary {
        let totalCaloriesBurned: Double
        let totalDurationMinutes: Double
        /// Number of distinct calendar days with at least one activity entry.
        let workoutDays: Int
        /// Calories burned broken down by activity category (e.g. "cardio", "strength").
        let byCategory: [String: Double]
    }

    /// Compute a `WeeklyActivitySummary` from an array of `ActivityEntry` records.
    ///
    /// Unique workout days are determined by normalising each entry's `timestamp` to
    /// `startOfDay` and counting distinct values. Category breakdown sums `caloriesBurned`
    /// by `activityCategory`.
    ///
    /// - Parameter entries: All `ActivityEntry` records for the period.
    /// - Returns: A `WeeklyActivitySummary` with totals and per-category breakdown.
    static func weeklyActivitySummary(entries: [ActivityEntry]) -> WeeklyActivitySummary {
        let total     = entries.reduce(0.0) { $0 + $1.caloriesBurned }
        let totalMins = entries.reduce(0.0) { $0 + $1.durationMinutes }

        // Deduplicate to calendar days to count actual workout days
        let uniqueDays = Set(entries.map {
            Calendar.current.startOfDay(for: $0.timestamp)
        })

        // Sum calories by category for the insights dashboard breakdown
        var byCategory: [String: Double] = [:]
        for entry in entries {
            byCategory[entry.activityCategory, default: 0] += entry.caloriesBurned
        }

        return WeeklyActivitySummary(
            totalCaloriesBurned: total,
            totalDurationMinutes: totalMins,
            workoutDays: uniqueDays.count,
            byCategory: byCategory
        )
    }

    // MARK: - Strength Session Estimation

    /// Conservative calorie estimate for a lifting session when the AI estimator isn't used.
    ///
    /// MET values used:
    /// - Heavy compound lifts (squat, deadlift, bench):  MET 5.0
    /// - Isolation/machine work:                         MET 3.5
    ///
    /// An EPOC (Excess Post-Exercise Oxygen Consumption) bonus of 10% is added for heavy
    /// compound sessions, reflecting the elevated metabolism in the hours after heavy lifting.
    ///
    /// - Parameters:
    ///   - durationMinutes: Duration of the lifting session in minutes.
    ///   - weightKg: User's body weight in kilograms.
    ///   - isHeavy: `true` for compound heavy lifts (applies higher MET and EPOC bonus).
    /// - Returns: Total estimated kilocalories burned including EPOC where applicable.
    static func strengthSessionCalories(
        durationMinutes: Double,
        weightKg: Double,
        isHeavy: Bool
    ) -> Double {
        let met = isHeavy ? 5.0 : 3.5   // compound heavy = MET 5.0, isolation = MET 3.5
        let baseCals = calories(met: met, weightKg: weightKg, durationMinutes: durationMinutes)
        let epoc = isHeavy ? baseCals * 0.10 : 0  // 10% EPOC bonus for heavy compound work
        return baseCals + epoc
    }
}
