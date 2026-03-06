import SwiftUI
import SwiftData
import Charts

struct StrengthView: View {
    let profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    @State private var showAddTest = false
    @State private var selectedExercise: String? = nil

    private var sortedTests: [StrengthTestEntry] {
        profile.strengthTests.sorted { $0.date > $1.date }
    }

    private var exercisesLogged: [String] {
        Array(Set(profile.strengthTests.map(\.exercise))).sorted()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Muscle risk alert if needed
                        muscleRiskCard

                        // Exercise overview cards
                        ForEach(ExerciseInfo.all, id: \.key) { info in
                            let exerciseTests = sortedTests.filter { $0.exercise == info.key }
                            StrengthExerciseCard(
                                info: info,
                                tests: exerciseTests,
                                isMale: profile.biologicalSex == "male",
                                onAddTest: {
                                    selectedExercise = info.key
                                    showAddTest = true
                                }
                            )
                        }
                    }
                    .padding()
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Strength")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAddTest = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.leanPurple)
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showAddTest) {
                AddStrengthTestView(
                    profile: profile,
                    preselectedExercise: selectedExercise
                )
                .onDisappear { selectedExercise = nil }
            }
        }
    }

    // MARK: - Muscle Risk Alert

    @ViewBuilder
    private var muscleRiskCard: some View {
        if let risk = detectMuscleRisk() {
            VStack(alignment: .leading, spacing: 8) {
                Label("Muscle Risk Detected", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundColor(.leanRed)
                Text(risk)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
                Text("Action: Increase protein to \(Int(profile.dailyProteinGrams))g/day and reduce deficit by 100-200 kcal.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .cardStyle()
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.leanRed.opacity(0.4), lineWidth: 1)
            )
        }
    }

    private func detectMuscleRisk() -> String? {
        let twoWeeksAgo = Date().daysAgo(14)

        for exercise in exercisesLogged {
            let tests = sortedTests.filter { $0.exercise == exercise && $0.date >= twoWeeksAgo }
            guard tests.count >= 2 else { continue }

            let oldest = tests.min(by: { $0.date < $1.date })!
            let newest = tests.max(by: { $0.date < $1.date })!

            let drop = (oldest.estimated1RMKg - newest.estimated1RMKg) / oldest.estimated1RMKg
            if drop >= Constants.strengthLossAlertThreshold {
                let exerciseLabel = ExerciseInfo.label(for: exercise)
                return "\(exerciseLabel) 1RM dropped \(String(format: "%.0f", drop * 100))% in 2 weeks — you may be losing muscle."
            }
        }
        return nil
    }
}

// MARK: - Strength Exercise Card

struct StrengthExerciseCard: View {
    let info: ExerciseInfo
    let tests: [StrengthTestEntry]
    let isMale: Bool
    let onAddTest: () -> Void

    private var latestTest: StrengthTestEntry? { tests.first }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: info.icon)
                    .foregroundColor(.leanPurple)
                    .font(.title3)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(info.label)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(info.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: onAddTest) {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.leanPurple)
                        .font(.title3)
                }
            }

            if let latest = latestTest {
                // Latest 1RM + level
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Best 1RM")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(String(format: "%.1f", latest.estimated1RMKg)) kg")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        Text("@ \(String(format: "%.2f", latest.strengthToBodyWeight))× bodyweight")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Level")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(info.strengthLevel(ratio: latest.strengthToBodyWeight, isMale: isMale))
                            .font(.headline)
                            .foregroundColor(levelColor(ratio: latest.strengthToBodyWeight, isMale: isMale))
                    }
                }

                // Strength bar
                let levels = isMale ? info.maleLevels : info.femaleLevels
                let maxLevel = levels.last ?? 3.0
                let progress = (latest.strengthToBodyWeight / maxLevel).clamped(to: 0...1)
                let levelLabels = ["Untrained", "Beginner", "Novice", "Intermediate", "Advanced", "Elite"]

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.leanPurple.opacity(0.2))
                            .frame(height: 10)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.leanBlue, .leanPurple, .leanRed],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * progress, height: 10)
                            .animation(.spring(duration: 0.7), value: progress)
                    }
                }
                .frame(height: 10)

                HStack {
                    Text(levelLabels.first ?? "")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(levelLabels.last ?? "")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Mini trend chart if multiple tests
                if tests.count >= 2 {
                    let chartTests = Array(tests.suffix(6).reversed())
                    Chart(chartTests) { test in
                        LineMark(
                            x: .value("Date", test.date),
                            y: .value("1RM", test.estimated1RMKg)
                        )
                        .foregroundStyle(Color.leanPurple)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", test.date),
                            y: .value("1RM", test.estimated1RMKg)
                        )
                        .foregroundStyle(Color.leanPurple)
                    }
                    .frame(height: 80)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .weekOfYear)) {
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    .chartYAxis {
                        AxisMarks {
                            AxisValueLabel()
                                .foregroundStyle(Color.secondary)
                        }
                    }
                }

                // Last tested
                Text("Last tested: \(latest.date.dateFormatted)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                // No tests yet
                Button(action: onAddTest) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.leanPurple)
                        Text("Log first test")
                            .foregroundColor(.leanPurple)
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.leanPurple.opacity(0.1))
                    .cornerRadius(10)
                }
            }
        }
        .cardStyle()
    }

    private func levelColor(ratio: Double, isMale: Bool) -> Color {
        let level = info.strengthLevel(ratio: ratio, isMale: isMale)
        switch level {
        case "Elite", "Advanced": return .leanGreen
        case "Intermediate": return .leanBlue
        case "Novice": return .leanYellow
        case "Beginner": return .leanOrange
        default: return .leanGray
        }
    }
}
