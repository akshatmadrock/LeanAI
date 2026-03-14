import Foundation
import SwiftData

/// A personal food library entry. Auto-populated whenever a user logs a food item.
/// Macros are kept up-to-date so manual adjustments persist for future quick-adds.
@Model
final class SavedFood {
    var id: UUID
    var name: String
    var calories: Double
    var protein_g: Double
    var carbs_g: Double
    var fat_g: Double
    var fiber_g: Double
    var serving_size: String
    var useCount: Int       // how many times logged — used for sort order
    var lastUsed: Date

    init(
        name: String,
        calories: Double,
        protein_g: Double,
        carbs_g: Double,
        fat_g: Double,
        fiber_g: Double,
        serving_size: String
    ) {
        self.id = UUID()
        self.name = name
        self.calories = calories
        self.protein_g = protein_g
        self.carbs_g = carbs_g
        self.fat_g = fat_g
        self.fiber_g = fiber_g
        self.serving_size = serving_size
        self.useCount = 1
        self.lastUsed = Date()
    }
}
