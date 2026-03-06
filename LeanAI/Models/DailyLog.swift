import Foundation
import SwiftData

@Model
final class DailyLog {
    var id: UUID
    var date: Date
    var morningWeightKg: Double?        // optional — user may not log every day
    var steps: Int
    var notes: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade) var foodEntries: [FoodEntry]
    @Relationship(deleteRule: .cascade) var activityEntries: [ActivityEntry]

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

    // MARK: - Computed nutrition totals

    var totalCaloriesConsumed: Double {
        foodEntries.reduce(0) { $0 + $1.calories }
    }

    var totalProteinG: Double {
        foodEntries.reduce(0) { $0 + $1.proteinG }
    }

    var totalCarbsG: Double {
        foodEntries.reduce(0) { $0 + $1.carbsG }
    }

    var totalFatG: Double {
        foodEntries.reduce(0) { $0 + $1.fatG }
    }

    var totalFiberG: Double {
        foodEntries.reduce(0) { $0 + $1.fiberG }
    }

    // MARK: - Activity totals

    var totalCaloriesBurned: Double {
        let activityBurn = activityEntries.reduce(0.0) { $0 + $1.caloriesBurned }
        return activityBurn + stepCaloriesBurned
    }

    // Steps → calories using MET 3.5 walk formula
    // Approximate: steps / 1312 ≈ km walked; then MET × weight × hours
    // Simplified: steps × 0.04 (rough 80kg person baseline, weight-adjusted by caller)
    var stepCaloriesBurned: Double {
        // Each step ≈ 0.04 kcal for a ~75kg person (rough avg)
        return Double(steps) * 0.04
    }

    // MARK: - Deficit (negative = under target = good for fat loss)

    func netBalance(targetCalories: Double) -> Double {
        return totalCaloriesConsumed - (targetCalories + totalCaloriesBurned)
    }

    func isOnTrack(targetCalories: Double, proteinTarget: Double) -> Bool {
        let balanceOK = totalCaloriesConsumed <= targetCalories + (totalCaloriesBurned * 0.5)
        let proteinOK = totalProteinG >= proteinTarget * 0.85
        return balanceOK && proteinOK
    }
}
