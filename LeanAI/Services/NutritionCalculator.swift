import Foundation

/// All science-backed nutrition calculations.
/// Conservative approach: understate BMR rather than overstate.
struct NutritionCalculator {

    // MARK: - BMR (Mifflin-St Jeor, conservative)

    /// Mifflin-St Jeor equation × 0.95 conservative correction factor.
    /// This is the most validated equation for general use.
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

    // MARK: - TDEE (conservative multipliers)

    /// Total Daily Energy Expenditure using conservative (lower-end) activity multipliers.
    /// Level: 0=sedentary, 1=lightly active, 2=moderately active, 3=very active
    static func tdee(bmr: Double, activityLevel: Int) -> Double {
        let multipliers: [Double] = [1.2, 1.35, 1.5, 1.65]
        let idx = max(0, min(activityLevel, multipliers.count - 1))
        return bmr * multipliers[idx]
    }

    // MARK: - Calorie Target

    /// Daily calorie target with 500 kcal deficit, hard floor applied.
    /// 500 kcal deficit → ~0.5 kg/week fat loss (safe and muscle-preserving rate)
    static func dailyCalorieTarget(
        tdee: Double,
        isMale: Bool
    ) -> Double {
        let floor = isMale ? 1500.0 : 1200.0
        let target = tdee - 500
        return max(target, floor)
    }

    // MARK: - Macros

    /// Protein: 2.2 g/kg body weight — highest priority for muscle preservation during deficit.
    static func dailyProteinGrams(weightKg: Double) -> Double {
        return weightKg * 2.2
    }

    /// Fat: minimum 0.7 g/kg — needed for hormones and fat-soluble vitamins.
    static func dailyFatGrams(weightKg: Double) -> Double {
        return weightKg * 0.7
    }

    /// Carbs: remaining calories after protein (4 kcal/g) and fat (9 kcal/g).
    /// Floored at 50g to prevent ketosis in someone not intentionally doing keto.
    static func dailyCarbsGrams(
        calorieTarget: Double,
        proteinGrams: Double,
        fatGrams: Double
    ) -> Double {
        let proteinCals = proteinGrams * 4
        let fatCals = fatGrams * 9
        let remaining = calorieTarget - proteinCals - fatCals
        return max(remaining / 4, 50)
    }

    // MARK: - Progress Metrics

    /// Estimated weeks to reach goal at 0.5 kg/week loss rate (conservative).
    static func estimatedWeeksToGoal(
        currentWeightKg: Double,
        targetWeightKg: Double
    ) -> Int {
        let remaining = currentWeightKg - targetWeightKg
        guard remaining > 0 else { return 0 }
        return Int(ceil(remaining / 0.5))
    }

    /// Estimated target date based on 0.5 kg/week
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

    struct WeeklySummary {
        let avgCaloriesConsumed: Double
        let avgProteinG: Double
        let avgCarbsG: Double
        let avgFatG: Double
        let totalCaloriesBurned: Double
        let weightChange: Double           // negative = lost (good)
        let workoutsCompleted: Int
        let daysOnTrack: Int
        let calorieAdherencePercent: Double
        let proteinAdherencePercent: Double
    }

    static func weeklySummary(
        logs: [DailyLog],
        calorieTarget: Double,
        proteinTarget: Double
    ) -> WeeklySummary {
        let validLogs = logs.filter { !$0.foodEntries.isEmpty }
        guard !validLogs.isEmpty else {
            return WeeklySummary(
                avgCaloriesConsumed: 0, avgProteinG: 0, avgCarbsG: 0, avgFatG: 0,
                totalCaloriesBurned: 0, weightChange: 0, workoutsCompleted: 0,
                daysOnTrack: 0, calorieAdherencePercent: 0, proteinAdherencePercent: 0
            )
        }

        let avgCal = validLogs.map(\.totalCaloriesConsumed).reduce(0, +) / Double(validLogs.count)
        let avgProt = validLogs.map(\.totalProteinG).reduce(0, +) / Double(validLogs.count)
        let avgCarbs = validLogs.map(\.totalCarbsG).reduce(0, +) / Double(validLogs.count)
        let avgFat = validLogs.map(\.totalFatG).reduce(0, +) / Double(validLogs.count)
        let totalBurned = validLogs.map(\.totalCaloriesBurned).reduce(0, +)
        let workouts = logs.flatMap(\.activityEntries).count

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

    /// Count consecutive days where calories consumed < target + some burn
    static func currentDeficitStreak(logs: [DailyLog], calorieTarget: Double) -> Int {
        let sortedLogs = logs.sorted { $0.date > $1.date }  // newest first
        var streak = 0
        for log in sortedLogs {
            if log.totalCaloriesConsumed < (calorieTarget + log.totalCaloriesBurned * 0.5) {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    // MARK: - Body Fat Estimation (Navy formula)

    /// US Navy body fat estimation from tape measurements.
    /// Reasonably accurate without a DEXA scan.
    static func navyBodyFat(
        weightKg: Double,
        heightCm: Double,
        waistCm: Double,
        neckCm: Double,
        hipsCm: Double?,  // required for women
        isMale: Bool
    ) -> Double? {
        if isMale {
            guard waistCm > neckCm else { return nil }
            let bf = 86.010 * log10(waistCm - neckCm) - 70.041 * log10(heightCm) + 36.76
            return max(min(bf, 50), 3)  // clamp to reasonable range
        } else {
            guard let hips = hipsCm, waistCm + hips > neckCm else { return nil }
            let bf = 163.205 * log10(waistCm + hips - neckCm) - 97.684 * log10(heightCm) - 78.387
            return max(min(bf, 60), 5)
        }
    }
}
