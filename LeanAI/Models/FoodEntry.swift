import Foundation
import SwiftData

@Model
final class FoodEntry {
    var id: UUID
    var name: String
    var calories: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var fiberG: Double
    var mealType: String                // "breakfast" | "lunch" | "dinner" | "snack"
    var timestamp: Date
    var rawDescription: String          // original AI prompt kept for reference
    var servingSize: String             // e.g. "2 eggs", "1 cup", "100g"

    init(
        name: String,
        calories: Double,
        proteinG: Double,
        carbsG: Double,
        fatG: Double,
        fiberG: Double = 0,
        mealType: String,
        rawDescription: String = "",
        servingSize: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.calories = max(calories, 0)
        self.proteinG = max(proteinG, 0)
        self.carbsG = max(carbsG, 0)
        self.fatG = max(fatG, 0)
        self.fiberG = max(fiberG, 0)
        self.mealType = mealType
        self.timestamp = Date()
        self.rawDescription = rawDescription
        self.servingSize = servingSize
    }

    var mealTypeLabel: String {
        switch mealType {
        case "breakfast": return "Breakfast"
        case "lunch": return "Lunch"
        case "dinner": return "Dinner"
        case "snack": return "Snack"
        default: return "Other"
        }
    }

    var mealTypeIcon: String {
        switch mealType {
        case "breakfast": return "sunrise.fill"
        case "lunch": return "sun.max.fill"
        case "dinner": return "moon.fill"
        case "snack": return "apple.logo"
        default: return "fork.knife"
        }
    }

    // Macros as percentages of total calories
    var proteinPercent: Double {
        guard calories > 0 else { return 0 }
        return (proteinG * 4) / calories
    }

    var carbsPercent: Double {
        guard calories > 0 else { return 0 }
        return (carbsG * 4) / calories
    }

    var fatPercent: Double {
        guard calories > 0 else { return 0 }
        return (fatG * 9) / calories
    }
}
