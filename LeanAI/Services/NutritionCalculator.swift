// LeanAI
// NutritionCalculator.swift
//
// Science-backed, stateless nutrition math: BMR, TDEE, macro targets, body fat, and weekly summaries.
// Author: Akshat Gupta

import Foundation

// MARK: - NutritionCalculator

/// Stateless utility for all nutrition calculations used throughout LeanAI.
///
/// Conservative approach throughout: multipliers and targets are set at the lower end of
/// published ranges to avoid overestimating burn and underestimating intake requirements.
/// All methods are static — no instance needed.
struct NutritionCalculator {

    // MARK: - BMR (Mifflin-St Jeor)

    /// Basal Metabolic Rate using the Mifflin-St Jeor equation — the most validated
    /// general-population formula for estimating resting energy expenditure.
    ///
    /// Formula:
    /// - Male:   (10 × kg) + (6.25 × cm) − (5 × age) + 5
    /// - Female: (10 × kg) + (6.25 × cm) − (5 × age) − 161
    ///
    /// - Parameters:
    ///   - weightKg: Current body weight in kilograms.
    ///   - heightCm: Height in centimetres.
    ///   - ageYears: Age in whole years.
    ///   - isMale: Whether to apply the male (+5) or female (−161) sex adjustment.
    /// - Returns: BMR in kcal/day.
    static func bmr(
        weightKg: Double,
        heightCm: Double,
        ageYears: Int,
        isMale: Bool
    ) -> Double {
        let base = (10 * weightKg) + (6.25 * heightCm) - (5 * Double(ageYears))
        let sexAdjustment: Double = isMale ? 5 : -161
        let rawBMR = base + sexAdjustment

        return rawBMR
    }

    // MARK: - TDEE

    /// Total Daily Energy Expenditure = BMR × activity multiplier.
    ///
    /// Uses conservative (lower-end) multipliers to prevent overestimating daily burn,
    /// which is the most common cause of stalled fat loss:
    /// - 0 (sedentary):        × 1.20
    /// - 1 (lightly active):   × 1.35
    /// - 2 (moderately active):× 1.50
    /// - 3 (very active):      × 1.65
    ///
    /// - Parameters:
    ///   - bmr: Basal Metabolic Rate in kcal/day.
    ///   - activityLevel: Index 0–3 corresponding to the multipliers above.
    /// - Returns: Estimated TDEE in kcal/day.
    static func tdee(bmr: Double, activityLevel: Int) -> Double {
        let multipliers: [Double] = [1.2, 1.35, 1.5, 1.65]
        let idx = max(0, min(activityLevel, multipliers.count - 1))
        return bmr * multipliers[idx]
    }

    // MARK: - Calorie Target

    /// Daily calorie target for a fat-loss "cut": TDEE − 500 kcal, with a hard floor.
    ///
    /// A 500 kcal/day deficit equates to approximately 0.5 kg/week fat loss — the scientifically
    /// optimal rate for preserving lean muscle mass. The floor prevents metabolic adaptation
    /// and ensures micronutrient sufficiency.
    ///
    /// - Parameters:
    ///   - tdee: Total Daily Energy Expenditure in kcal/day.
    ///   - isMale: Determines the calorie floor (1500 kcal male, 1200 kcal female).
    /// - Returns: Target daily intake in kcal.
    static func dailyCalorieTarget(
        tdee: Double,
        isMale: Bool
    ) -> Double {
        let floor = isMale ? 1500.0 : 1200.0
        let target = tdee - 500
        return max(target, floor)
    }

    // MARK: - Macros

    /// Protein target: 2.2 g/kg body weight — highest priority nutrient during a cut.
    ///
    /// High protein intake (≥ 1.8 g/kg) is consistently shown to preserve lean muscle
    /// in a calorie deficit. 2.2 g/kg is used as a conservative upper target.
    ///
    /// - Parameter weightKg: Current body weight in kilograms.
    /// - Returns: Daily protein target in grams.
    static func dailyProteinGrams(weightKg: Double) -> Double {
        return weightKg * 2.2
    }

    /// Fat minimum: 0.7 g/kg body weight — the floor for hormonal health.
    ///
    /// Dietary fat is required for testosterone synthesis, fat-soluble vitamins (A, D, E, K),
    /// and cell membrane integrity. Dropping below this risks hormonal disruption.
    ///
    /// - Parameter weightKg: Current body weight in kilograms.
    /// - Returns: Minimum daily fat in grams.
    static func dailyFatGrams(weightKg: Double) -> Double {
        return weightKg * 0.7
    }

    /// Carbohydrate target: remaining calories after protein and fat allocations.
    ///
    /// Carbs fill in whatever calorie budget is left after protein (4 kcal/g) and fat (9 kcal/g)
    /// are accounted for. The 50g floor prevents unintentional ketosis.
    ///
    /// - Parameters:
    ///   - calorieTarget: Total daily calorie target in kcal.
    ///   - proteinGrams: Daily protein allocation in grams.
    ///   - fatGrams: Daily fat allocation in grams.
    /// - Returns: Daily carbohydrate target in grams (minimum 50g).
    static func dailyCarbsGrams(
        calorieTarget: Double,
        proteinGrams: Double,
        fatGrams: Double
    ) -> Double {
        let proteinCals = proteinGrams * 4   // protein: 4 kcal/g
        let fatCals = fatGrams * 9           // fat: 9 kcal/g
        let remaining = calorieTarget - proteinCals - fatCals
        return max(remaining / 4, 50)        // carbs: 4 kcal/g; minimum 50g
    }

    // MARK: - Progress Metrics

    /// Estimated weeks to reach target weight, assuming a conservative 0.5 kg/week loss rate.
    ///
    /// - Parameters:
    ///   - currentWeightKg: Current body weight in kilograms.
    ///   - targetWeightKg: Goal body weight in kilograms.
    /// - Returns: Whole weeks required (0 if already at or below target).
    static func estimatedWeeksToGoal(
        currentWeightKg: Double,
        targetWeightKg: Double
    ) -> Int {
        let remaining = currentWeightKg - targetWeightKg
        guard remaining > 0 else { return 0 }
        return Int(ceil(remaining / 0.5))
    }

    /// Projected target-reach date based on a 0.5 kg/week loss rate.
    ///
    /// - Parameters:
    ///   - currentWeightKg: Current body weight in kilograms.
    ///   - targetWeightKg: Goal body weight in kilograms.
    /// - Returns: Estimated `Date`, or nil if already at goal.
    static func estimatedTargetDate(
        currentWeightKg: Double,
        targetWeightKg: Double
    ) -> Date? {
        let weeks = estimatedWeeksToGoal(
            currentWeightKg: currentWeightKg,
            targetWeightKg: targetWeightKg
        )
        guard weeks > 0 else { return nil }
        return Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: Date())
    }

    // MARK: - Weekly Summary

    /// Aggregated nutrition and activity statistics for a 7-day period.
    struct WeeklySummary {
        let avgCaloriesConsumed: Double
        let avgProteinG: Double
        let avgCarbsG: Double
        let avgFatG: Double
        /// Total calories burned across all activity entries in the week.
        let totalCaloriesBurned: Double
        /// Net weight change: negative = weight lost (favourable for a cut).
        let weightChange: Double
        let workoutsCompleted: Int
        /// Number of days where both calorie and protein targets were met.
        let daysOnTrack: Int
        /// Average daily calories as a percentage of target (capped at 150%).
        let calorieAdherencePercent: Double
        /// Average daily protein as a percentage of target (capped at 150%).
        let proteinAdherencePercent: Double
    }

    /// Compute a `WeeklySummary` from a set of `DailyLog` records.
    ///
    /// Only days with at least one food entry are included in averages to avoid
    /// dragging down stats from days the user forgot to log.
    ///
    /// - Parameters:
    ///   - logs: Array of `DailyLog` records for the week (typically 7).
    ///   - calorieTarget: The user's daily calorie target.
    ///   - proteinTarget: The user's daily protein target in grams.
    /// - Returns: A populated `WeeklySummary`. Returns zero-values if no logs have food entries.
    static func weeklySummary(
        logs: [DailyLog],
        calorieTarget: Double,
        proteinTarget: Double
    ) -> WeeklySummary {
        // Only include days where food was actually logged
        let validLogs = logs.filter { !$0.foodEntries.isEmpty }
        guard !validLogs.isEmpty else {
            return WeeklySummary(
                avgCaloriesConsumed: 0, avgProteinG: 0, avgCarbsG: 0, avgFatG: 0,
                totalCaloriesBurned: 0, weightChange: 0, workoutsCompleted: 0,
                daysOnTrack: 0, calorieAdherencePercent: 0, proteinAdherencePercent: 0
            )
        }

        let avgCal   = validLogs.map(\.totalCaloriesConsumed).reduce(0, +) / Double(validLogs.count)
        let avgProt  = validLogs.map(\.totalProteinG).reduce(0, +) / Double(validLogs.count)
        let avgCarbs = validLogs.map(\.totalCarbsG).reduce(0, +) / Double(validLogs.count)
        let avgFat   = validLogs.map(\.totalFatG).reduce(0, +) / Double(validLogs.count)
        let totalBurned = validLogs.map(\.totalCaloriesBurned).reduce(0, +)
        // Count activity entries across ALL logs (not just food-logged days)
        let workouts = logs.flatMap(\.activityEntries).count

        // Weight change: requires at least two weigh-in entries
        let weightLogs = logs.compactMap(\.morningWeightKg)
        let weightChange: Double
        if weightLogs.count >= 2 {
            weightChange = weightLogs.last! - weightLogs.first!
        } else {
            weightChange = 0
        }

        let daysOnTrack = validLogs.filter {
            $0.isOnTrack(targetCalories: calorieTarget, proteinTarget: proteinTarget)
        }.count

        return WeeklySummary(
            avgCaloriesConsumed: avgCal,
            avgProteinG: avgProt,
            avgCarbsG: avgCarbs,
            avgFatG: avgFat,
            totalCaloriesBurned: totalBurned,
            weightChange: weightChange,
            workoutsCompleted: workouts,
            daysOnTrack: daysOnTrack,
            calorieAdherencePercent: min((avgCal / calorieTarget) * 100, 150),
            proteinAdherencePercent: min((avgProt / proteinTarget) * 100, 150)
        )
    }

    // MARK: - Deficit Streak

    /// Count of consecutive days (most recent first) where calories consumed stayed
    /// within the effective target (calorie target + 50% of burned calories).
    ///
    /// The 50% burn credit prevents penalising users who earned extra calories through exercise.
    ///
    /// - Parameters:
    ///   - logs: All `DailyLog` records for the user.
    ///   - calorieTarget: The user's daily calorie target.
    /// - Returns: Number of consecutive on-target days.
    static func currentDeficitStreak(logs: [DailyLog], calorieTarget: Double) -> Int {
        let sortedLogs = logs.sorted { $0.date > $1.date }  // newest first
        var streak = 0
        for log in sortedLogs {
            if log.totalCaloriesConsumed < (calorieTarget + log.totalCaloriesBurned * 0.5) {
                streak += 1
            } else {
                break  // streak ends at the first non-compliant day
            }
        }
        return streak
    }

    // MARK: - Body Fat Estimation (US Navy Formula)

    /// Estimate body fat percentage from circumference measurements using the US Navy formula.
    ///
    /// Reasonably accurate (±3–4% error) without requiring a DEXA scan. Results are clamped
    /// to physiologically plausible ranges.
    ///
    /// Male formula:   BF% = 86.010 × log10(waist − neck) − 70.041 × log10(height) + 36.76
    /// Female formula: BF% = 163.205 × log10(waist + hips − neck) − 97.684 × log10(height) − 78.387
    ///
    /// - Parameters:
    ///   - weightKg: Body weight in kilograms (not used in the formula, reserved for future LBM calc).
    ///   - heightCm: Height in centimetres.
    ///   - waistCm: Waist circumference at the narrowest point (male) or navel (female), in cm.
    ///   - neckCm: Neck circumference at its narrowest point, in cm.
    ///   - hipsCm: Hip circumference at the widest point — required for females, ignored for males.
    ///   - isMale: Determines which formula variant to apply.
    /// - Returns: Body fat percentage, or nil if the input values are physiologically invalid.
    static func navyBodyFat(
        weightKg: Double,
        heightCm: Double,
        waistCm: Double,
        neckCm: Double,
        hipsCm: Double?,
        isMale: Bool
    ) -> Double? {
        if isMale {
            // waist must be larger than neck for a valid log10 argument
            guard waistCm > neckCm else { return nil }
            let bf = 86.010 * log10(waistCm - neckCm) - 70.041 * log10(heightCm) + 36.76
            return max(min(bf, 50), 3)  // clamp: 3% (elite athlete) to 50% (obese)
        } else {
            guard let hips = hipsCm, waistCm + hips > neckCm else { return nil }
            let bf = 163.205 * log10(waistCm + hips - neckCm) - 97.684 * log10(heightCm) - 78.387
            return max(min(bf, 60), 5)  // clamp: 5% to 60%
        }
    }
}
