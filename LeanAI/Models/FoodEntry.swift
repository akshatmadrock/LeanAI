// LeanAI
// FoodEntry.swift
//
// A single food item logged for a meal, populated by the Groq/LLaMA AI parser.
// Author: Akshat Gupta

import Foundation
import SwiftData

// MARK: - FoodEntry

/// Represents one food item within a meal. Typically created from the structured JSON
/// returned by `GroqService.parseFoodDescription(_:apiKey:mealType:)`.
///
/// All macro values are clamped to ≥ 0 at init time to guard against unexpected AI output.
/// The `rawDescription` preserves the user's original natural-language input for reference.
@Model
final class FoodEntry {

    // MARK: - Identity

    var id: UUID

    /// Specific food name as identified by the AI (e.g. "White basmati rice", "Dal makhani").
    var name: String

    // MARK: - Macros

    /// Total calories for this item/serving.
    var calories: Double

    /// Protein content in grams.
    var proteinG: Double

    /// Carbohydrate content in grams.
    var carbsG: Double

    /// Fat content in grams.
    var fatG: Double

    /// Dietary fiber in grams. Defaults to 0 when not provided by AI.
    var fiberG: Double

    // MARK: - Metadata

    /// Meal category: "breakfast" | "lunch" | "dinner" | "snack".
    var mealType: String

    var timestamp: Date

    /// The original natural-language description the user typed, kept for audit/reference.
    var rawDescription: String

    /// Human-readable serving size returned by the AI (e.g. "2 eggs", "1 cup", "100g").
    var servingSize: String

    // MARK: - Initialiser

    /// Creates a new food entry. All macro values are clamped to ≥ 0.
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

    // MARK: - Display Helpers

    /// Human-readable label for the meal type.
    var mealTypeLabel: String {
        switch mealType {
        case "breakfast": return "Breakfast"
        case "lunch": return "Lunch"
        case "dinner": return "Dinner"
        case "snack": return "Snack"
        default: return "Other"
        }
    }

    /// SF Symbol name for the meal type, used in list rows and cards.
    var mealTypeIcon: String {
        switch mealType {
        case "breakfast": return "sunrise.fill"
        case "lunch": return "sun.max.fill"
        case "dinner": return "moon.fill"
        case "snack": return "apple.logo"
        default: return "fork.knife"
        }
    }

    // MARK: - Macro Percentages

    /// Protein as a fraction of total calories. Protein contributes 4 kcal/g.
    var proteinPercent: Double {
        guard calories > 0 else { return 0 }
        return (proteinG * 4) / calories
    }

    /// Carbohydrates as a fraction of total calories. Carbs contribute 4 kcal/g.
    var carbsPercent: Double {
        guard calories > 0 else { return 0 }
        return (carbsG * 4) / calories
    }

    /// Fat as a fraction of total calories. Fat contributes 9 kcal/g.
    var fatPercent: Double {
        guard calories > 0 else { return 0 }
        return (fatG * 9) / calories
    }
}
