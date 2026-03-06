import Foundation
import SwiftData

@Model
final class StrengthTestEntry {
    var id: UUID
    var exercise: String               // see Exercise enum keys below
    var weightKg: Double               // weight lifted (0 for pure bodyweight)
    var reps: Int
    var sets: Int
    var bodyweightKg: Double           // user's weight on test day (for ratio)
    var estimated1RMKg: Double         // Epley formula result
    var strengthToBodyWeight: Double   // 1RM / bodyweight ratio
    var date: Date
    var notes: String

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
        // For bodyweight exercises, total weight = weightKg + bodyweightKg
        let totalWeight = exercise == "pullup" ? bodyweightKg + weightKg : weightKg
        let one_rm = totalWeight * (1.0 + Double(reps) / 30.0)
        self.estimated1RMKg = one_rm
        self.strengthToBodyWeight = bodyweightKg > 0 ? one_rm / bodyweightKg : 0
    }

    var exerciseLabel: String {
        ExerciseInfo.label(for: exercise)
    }

    var exerciseIcon: String {
        ExerciseInfo.icon(for: exercise)
    }
}

// MARK: - Exercise definitions with Symmetric Strength standards (men, novice → elite)
struct ExerciseInfo {
    let key: String
    let label: String
    let icon: String
    // Strength-to-bodyweight ratios for male: [untrained, beginner, novice, intermediate, advanced, elite]
    let maleLevels: [Double]
    // Female ratios are typically ~60-70% of male
    let femaleLevels: [Double]
    let description: String

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

    static func label(for key: String) -> String {
        all.first(where: { $0.key == key })?.label ?? key.capitalized
    }

    static func icon(for key: String) -> String {
        all.first(where: { $0.key == key })?.icon ?? "dumbbell.fill"
    }

    static func info(for key: String) -> ExerciseInfo? {
        all.first(where: { $0.key == key })
    }

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
