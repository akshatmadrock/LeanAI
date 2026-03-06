import Foundation

/// MET-based calorie burn calculations for activities.
/// Formula: Calories = MET × weight_kg × (duration_minutes / 60)
/// Source: Compendium of Physical Activities (Ainsworth et al.)
struct ActivityCalculator {

    // MARK: - Core Formula

    /// Calculate calories burned using MET × weight × time.
    static func calories(
        met: Double,
        weightKg: Double,
        durationMinutes: Double
    ) -> Double {
        return met * weightKg * (durationMinutes / 60.0)
    }

    // MARK: - Steps to Calories

    /// Convert step count to calories burned.
    /// Approach: steps → distance (using avg stride) → MET 3.5 brisk walk
    static func stepsToCalories(
        steps: Int,
        weightKg: Double,
        heightCm: Double
    ) -> Double {
        guard steps > 0 else { return 0 }
        // Stride length ≈ height × 0.414 (for brisk walking)
        let strideLengthM = heightCm / 100.0 * 0.414
        let distanceKm = Double(steps) * strideLengthM / 1000.0
        let durationHours = distanceKm / 5.0  // assume 5 km/h brisk walk
        return 3.5 * weightKg * durationHours  // MET 3.5 for brisk walking
    }

    // MARK: - Preset Activity Calculations

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

    struct WeeklyActivitySummary {
        let totalCaloriesBurned: Double
        let totalDurationMinutes: Double
        let workoutDays: Int
        let byCategory: [String: Double]    // category → total calories
    }

    static func weeklyActivitySummary(entries: [ActivityEntry]) -> WeeklyActivitySummary {
        let total = entries.reduce(0.0) { $0 + $1.caloriesBurned }
        let totalMins = entries.reduce(0.0) { $0 + $1.durationMinutes }

        // Count unique workout days
        let uniqueDays = Set(entries.map {
            Calendar.current.startOfDay(for: $0.timestamp)
        })

        // Group by category
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

    // MARK: - Strength Training Calorie Estimation
    // (For when user doesn't use the AI estimator)

    /// Conservative calorie estimate for a lifting session.
    /// Accounts for EPOC (excess post-exercise oxygen consumption) — 10% bonus for heavy lifting.
    static func strengthSessionCalories(
        durationMinutes: Double,
        weightKg: Double,
        isHeavy: Bool                   // heavy compound lifts vs machine/isolation
    ) -> Double {
        let met = isHeavy ? 5.0 : 3.5   // compound heavy = MET 5, isolation = MET 3.5
        let baseCals = calories(met: met, weightKg: weightKg, durationMinutes: durationMinutes)
        let epoc = isHeavy ? baseCals * 0.10 : 0  // 10% EPOC bonus for heavy lifting
        return baseCals + epoc
    }
}
