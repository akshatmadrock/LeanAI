import SwiftUI
import SwiftData

struct AddStrengthTestView: View {
    let profile: UserProfile
    let preselectedExercise: String?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedExercise: String
    @State private var weightKg: Double = 60
    @State private var reps: Int = 5
    @State private var sets: Int = 3
    @State private var notes = ""
    @State private var isBodyweightOnly = false  // e.g. pull-ups with no added weight

    init(profile: UserProfile, preselectedExercise: String? = nil) {
        self.profile = profile
        self.preselectedExercise = preselectedExercise
        _selectedExercise = State(initialValue: preselectedExercise ?? ExerciseInfo.all.first?.key ?? "bench_press")
    }

    private var selectedInfo: ExerciseInfo? {
        ExerciseInfo.info(for: selectedExercise)
    }

    // Epley 1RM preview
    private var estimated1RM: Double {
        let totalWeight: Double
        if selectedExercise == "pullup" {
            totalWeight = isBodyweightOnly ? profile.currentWeightKg : profile.currentWeightKg + weightKg
        } else {
            totalWeight = weightKg
        }
        return totalWeight * (1.0 + Double(reps) / 30.0)
    }

    private var strengthToBodyWeight: Double {
        guard profile.currentWeightKg > 0 else { return 0 }
        return estimated1RM / profile.currentWeightKg
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Exercise picker
                        exercisePicker

                        // Lift details
                        liftDetailsSection

                        // 1RM Preview
                        oneRMPreview

                        // Notes
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes (optional)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("e.g. paused reps, slight discomfort", text: $notes)
                                .padding()
                                .background(Color.cardBackground)
                                .cornerRadius(10)
                                .foregroundColor(.white)
                        }

                        // How 1RM is calculated
                        explanationCard
                    }
                    .padding()
                    .padding(.bottom, 100)
                }

                // Save button
                VStack {
                    Spacer()
                    Button(action: saveTest) {
                        Text("Log Strength Test")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.leanPurple)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle("Log Strength")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Exercise Picker

    private var exercisePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Exercise")
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ExerciseInfo.all, id: \.key) { info in
                        Button(action: { selectedExercise = info.key }) {
                            VStack(spacing: 4) {
                                Image(systemName: info.icon)
                                    .font(.title3)
                                    .foregroundColor(selectedExercise == info.key ? .black : .leanPurple)
                                Text(info.label)
                                    .font(.caption)
                                    .foregroundColor(selectedExercise == info.key ? .black : .white)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .frame(width: 90, height: 70)
                            .background(selectedExercise == info.key ? Color.leanPurple : Color.cardBackground)
                            .cornerRadius(12)
                        }
                    }
                }
            }

            if let info = selectedInfo {
                Text(info.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Lift Details

    private var liftDetailsSection: some View {
        VStack(spacing: 16) {
            if selectedExercise == "pullup" {
                Toggle(isOn: $isBodyweightOnly) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bodyweight only")
                            .foregroundColor(.white)
                        Text("Turn off if using a weight belt or vest")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.leanPurple)
                .cardStyle()

                if !isBodyweightOnly {
                    StepperCard(
                        label: "Added Weight",
                        value: $weightKg,
                        step: 2.5,
                        range: 0...100,
                        unit: "kg"
                    )
                }
            } else {
                StepperCard(
                    label: "Weight Lifted",
                    value: $weightKg,
                    step: 2.5,
                    range: 0...400,
                    unit: "kg"
                )
            }

            // Reps stepper
            HStack {
                Text("Reps")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Stepper("\(reps) reps", value: $reps, in: 1...30)
                    .foregroundColor(.white)
            }
            .cardStyle()

            // Sets stepper
            HStack {
                Text("Sets")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Stepper("\(sets) sets", value: $sets, in: 1...10)
                    .foregroundColor(.white)
            }
            .cardStyle()
        }
    }

    // MARK: - 1RM Preview

    private var oneRMPreview: some View {
        VStack(spacing: 12) {
            Text("Estimated 1RM")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: "%.1f kg", estimated1RM))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.leanPurple)
                    Text(String(format: "%.2f× bodyweight", strengthToBodyWeight))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let info = selectedInfo {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Level")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(info.strengthLevel(
                            ratio: strengthToBodyWeight,
                            isMale: profile.biologicalSex == "male"
                        ))
                        .font(.headline)
                        .foregroundColor(.leanPurple)
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Explanation

    private var explanationCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("How is 1RM calculated?", systemImage: "info.circle")
                .font(.subheadline)
                .foregroundColor(.leanBlue)

            Text("Uses the **Epley formula**: 1RM = Weight × (1 + Reps / 30). This is the most widely used 1RM estimation formula and is validated for compound lifts. Best accuracy with 3-10 reps.")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("Use a weight where you leave 1-2 reps in reserve (RIR) for the most accurate estimate.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .cardStyle()
    }

    // MARK: - Save

    private func saveTest() {
        let test = StrengthTestEntry(
            exercise: selectedExercise,
            weightKg: selectedExercise == "pullup" && isBodyweightOnly ? 0 : weightKg,
            reps: reps,
            sets: sets,
            bodyweightKg: profile.currentWeightKg,
            notes: notes
        )
        profile.strengthTests.append(test)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Stepper Card

struct StepperCard: View {
    let label: String
    @Binding var value: Double
    let step: Double
    let range: ClosedRange<Double>
    let unit: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("\(String(format: step < 1 ? "%.1f" : "%.1f", value)) \(unit)")
                    .font(.title3.bold())
                    .foregroundColor(.white)
            }

            Spacer()

            HStack(spacing: 0) {
                Button(action: {
                    if value - step >= range.lowerBound {
                        value -= step
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(value <= range.lowerBound ? .leanGray : .leanPurple)
                }
                .disabled(value <= range.lowerBound)

                Text(String(format: " %.1f ", value))
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(minWidth: 60)

                Button(action: {
                    if value + step <= range.upperBound {
                        value += step
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(value >= range.upperBound ? .leanGray : .leanPurple)
                }
                .disabled(value >= range.upperBound)
            }
        }
        .cardStyle()
    }
}
