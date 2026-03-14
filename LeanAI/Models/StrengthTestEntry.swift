// LeanAI
// StrengthTestEntry.swift
//
// Strength test records with Epley 1RM estimation and Symmetric Strength classification.
// Author: Akshat Gupta

import Foundation
import SwiftData

// MARK: - StrengthTestEntry

/// A single strength test record. The Epley formula is applied at init time to compute
/// `estimated1RMKg` and `strengthToBodyWeight`, so these fields are stored (not recomputed)
/// even if `currentWeightKg` changes later.
///
/// For pull-ups, total load = bodyweight + any added weight, since the user is lifting
/// their own body. For all barbell lifts, `weightKg` is the total barbell load.
@Model
final class StrengthTestEntry {

    // MARK: - Identity

    var id: UUID

    // MARK: - Test Data

    /// Exercise key matching an `ExerciseInfo.key` (e.g. "bench_press", "squat", "pullup").
    var exercise: String

    /// Total weight lifted in kg. For pure bodyweight exercises (no added weight), this is 0.
    var weightKg: Double

    /// Number of reps performed in the measured set.
    var reps: Int

    /// Number of sets performed (informational; 1RM uses the reps from `reps`).
    var sets: Int

    /// User's body weight on the day of the test — used for strength-to-bodyweight ratio.
    var bodyweightKg: Double

    // MARK: - Computed Results (stored at init)

    /// Estimated one-rep max calculated via the Epley formula at the time of the test.
    var estimated1RMKg: Double

    /// Strength-to-bodyweight ratio: `estimated1RMKg / bodyweightKg`. Used for classification.
    var strengthToBodyWeight: Double

    var date: Date
    var notes: String

    // MARK: - Initialiser

    /// Creates a strength test entry and immediately computes `estimated1RMKg` using Epley.
    ///
    /// **Epley formula:** 1RM = weight × (1 + reps / 30)
    ///
    /// For pull-ups, total load is `bodyweightKg + weightKg` (added weight via belt/vest).
    /// For all other exercises, `weightKg` is used directly.
    init(
        exercise: String,
        weightKg: Double,
        reps: Int,
        sets: Int = 1,
        bodyweightKg: Double,
        notes: String = ""
    ) {
        self.id = UUID()
        self.exercise = exercise
        self.weightKg = weightKg
        self.reps = reps
        self.sets = sets
        self.bodyweightKg = bodyweightKg
        self.date = Date()
        self.notes = notes

        // Epley 1RM formula: weight × (1 + reps/30)
        // For bodyweight exercises (pull-up), total weight = bodyweightKg + added weightKg
        let totalWeight = exercise == "pullup" ? bodyweightKg + weightKg : weightKg
        let one_rm = totalWeight * (1.0 + Double(reps) / 30.0)
        self.estimated1RMKg = one_rm
        // Ratio of 1RM to bodyweight — the primary strength classification metric
        self.strengthToBodyWeight = bodyweightKg > 0 ? one_rm / bodyweightKg : 0
    }

    // MARK: - Display Helpers

    /// Human-readable exercise name (e.g. "Bench Press") from `ExerciseInfo`.
    var exerciseLabel: String {
        ExerciseInfo.label(for: exercise)
    }

    /// SF Symbol name for the exercise from `ExerciseInfo`.
    var exerciseIcon: String {
        ExerciseInfo.icon(for: exercise)
    }
}

// MARK: - ExerciseInfo

/// Static catalogue of supported exercises with Symmetric Strength classification standards.
///
/// Strength levels are represented as strength-to-bodyweight ratios for six tiers:
/// Untrained → Beginner → Novice → Intermediate → Advanced → Elite.
/// Female standards are approximately 60–70% of male standards.
struct ExerciseInfo {
    let key: String
    let label: String
    let icon: String

    /// Strength-to-bodyweight ratio thresholds for males: [untrained, beginner, novice, intermediate, advanced, elite].
    let maleLevels: [Double]

    /// Strength-to-bodyweight ratio thresholds for females (typically 60–70% of male values).
    let femaleLevels: [Double]

    /// Brief description of the exercise standard (form requirements, equipment).
    let description: String

    // MARK: - Exercise Catalogue

    /// All supported exercises with their Symmetric Strength classification thresholds.
    static let all: [ExerciseInfo] = [
        ExerciseInfo(
            key: "bench_press",
            label: "Bench Press",
            icon: "figure.strengthtraining.traditional",
            maleLevels: [0.5, 0.75, 1.0, 1.25, 1.5, 1.75],
            femaleLevels: [0.25, 0.5, 0.65, 0.85, 1.0, 1.2],
            description: "Flat barbell bench press, full range of motion"
        ),
        ExerciseInfo(
            key: "squat",
            label: "Squat",
            icon: "figure.strengthtraining.functional",
            maleLevels: [0.75, 1.0, 1.25, 1.5, 1.75, 2.0],
            femaleLevels: [0.5, 0.75, 1.0, 1.25, 1.5, 1.75],
            description: "Barbell back squat, below parallel"
        ),
        ExerciseInfo(
            key: "deadlift",
            label: "Deadlift",
            icon: "arrow.up.to.line",
            maleLevels: [1.0, 1.5, 2.0, 2.5, 3.0, 3.5],
            femaleLevels: [0.75, 1.0, 1.25, 1.5, 2.0, 2.5],
            description: "Conventional barbell deadlift from floor"
        ),
        ExerciseInfo(
            key: "ohp",
            label: "Overhead Press",
            icon: "arrow.up",
            maleLevels: [0.35, 0.5, 0.65, 0.8, 1.0, 1.2],
            femaleLevels: [0.2, 0.3, 0.4, 0.55, 0.7, 0.85],
            description: "Standing barbell overhead press"
        ),
        ExerciseInfo(
            key: "pullup",
            label: "Pull-up",
            icon: "figure.gymnastics",
            maleLevels: [0, 0.5, 0.75, 1.0, 1.25, 1.5],
            femaleLevels: [0, 0.25, 0.5, 0.75, 1.0, 1.2],
            description: "Dead hang pull-up, chin over bar (bodyweight + added weight)"
        ),
        ExerciseInfo(
            key: "romanian_deadlift",
            label: "Romanian Deadlift",
            icon: "figure.walk",
            maleLevels: [0.75, 1.0, 1.25, 1.5, 1.75, 2.0],
            femaleLevels: [0.5, 0.75, 1.0, 1.25, 1.5, 1.75],
            description: "RDL with barbell, slight knee bend"
        ),
    ]

    // MARK: - Lookup Helpers

    /// Returns the human-readable label for an exercise key, or a capitalised fallback.
    static func label(for key: String) -> String {
        all.first(where: { $0.key == key })?.label ?? key.capitalized
    }

    /// Returns the SF Symbol name for an exercise key, falling back to "dumbbell.fill".
    static func icon(for key: String) -> String {
        all.first(where: { $0.key == key })?.icon ?? "dumbbell.fill"
    }

    /// Returns the full `ExerciseInfo` for an exercise key, or nil if not found.
    static func info(for key: String) -> ExerciseInfo? {
        all.first(where: { $0.key == key })
    }

    // MARK: - Classification

    /// Maps a strength-to-bodyweight ratio to a Symmetric Strength level label.
    ///
    /// Iterates the thresholds from highest to lowest and returns the first label
    /// whose threshold the ratio meets or exceeds.
    /// - Parameters:
    ///   - ratio: The user's `strengthToBodyWeight` value for this exercise.
    ///   - isMale: Whether to use male or female classification thresholds.
    /// - Returns: One of "Untrained", "Beginner", "Novice", "Intermediate", "Advanced", "Elite".
    func strengthLevel(ratio: Double, isMale: Bool) -> String {
        let levels = isMale ? maleLevels : femaleLevels
        let labels = ["Untrained", "Beginner", "Novice", "Intermediate", "Advanced", "Elite"]
        for (i, level) in levels.enumerated().reversed() {
            if ratio >= level {
                return labels[min(i, labels.count - 1)]
            }
        }
        return "Untrained"
    }
}
