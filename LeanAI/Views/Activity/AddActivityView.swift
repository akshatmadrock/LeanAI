import SwiftUI
import SwiftData

struct AddActivityView: View {
    let profile: UserProfile
    let todayLog: DailyLog

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var groq = GroqService()

    @State private var selectedPreset: ActivityPreset? = ActivityPreset.presets.first
    @State private var intensityLevel = 1
    @State private var durationMinutes: Double = 30
    @State private var useAI = false
    @State private var customDescription = ""
    @State private var estimatedCalories: Double = 0
    @State private var estimatedMET: Double = 0
    @State private var aiReasoning = ""
    @State private var isEstimating = false
    @State private var errorMessage: String?
    @State private var notes = ""

    private var calculatedCalories: Double {
        guard let preset = selectedPreset else { return 0 }
        return ActivityCalculator.caloriesForPreset(
            preset: preset,
            intensityLevel: intensityLevel,
            durationMinutes: durationMinutes,
            weightKg: profile.currentWeightKg
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Mode toggle
                        modeToggle

                        if useAI {
                            aiModeSection
                        } else {
                            presetModeSection
                        }

                        // Duration
                        durationSection

                        // Calorie preview
                        caloriePreview

                        // Notes
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes (optional)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("e.g. morning run around the park", text: $notes)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.cardBackground)
                                .cornerRadius(10)
                                .foregroundColor(.white)
                        }

                        if let error = errorMessage {
                            ErrorBanner(message: error)
                        }
                    }
                    .padding()
                    .padding(.bottom, 100)
                }

                // Save button
                VStack {
                    Spacer()
                    Button(action: saveActivity) {
                        Text("Add Activity")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.leanOrange)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle("Add Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Mode Toggle

    private var modeToggle: some View {
        HStack(spacing: 0) {
            ForEach([(false, "Preset", "list.bullet"), (true, "AI Estimate", "sparkles")], id: \.0) { isAI, label, icon in
                Button(action: { withAnimation { useAI = isAI } }) {
                    Label(label, systemImage: icon)
                        .font(.subheadline)
                        .fontWeight(useAI == isAI ? .semibold : .regular)
                        .foregroundColor(useAI == isAI ? .black : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(useAI == isAI ? Color.leanOrange : Color.clear)
                        .cornerRadius(10)
                }
            }
        }
        .padding(4)
        .background(Color.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Preset Mode

    private var presetModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity")
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ActivityPreset.presets.filter { $0.name != "Custom (AI)" }) { preset in
                        Button(action: { selectedPreset = preset }) {
                            VStack(spacing: 4) {
                                Image(systemName: categoryIcon(preset.category))
                                    .font(.title3)
                                    .foregroundColor(selectedPreset?.id == preset.id ? .black : .leanOrange)
                                Text(preset.name)
                                    .font(.caption)
                                    .foregroundColor(selectedPreset?.id == preset.id ? .black : .white)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(width: 80, height: 70)
                            .background(selectedPreset?.id == preset.id ? Color.leanOrange : Color.cardBackground)
                            .cornerRadius(12)
                        }
                    }
                }
            }

            // Intensity
            Text("Intensity")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                ForEach([(0, "Light", "tortoise.fill"), (1, "Moderate", "hare.fill"), (2, "Intense", "bolt.fill")], id: \.0) { level, label, icon in
                    Button(action: { intensityLevel = level }) {
                        VStack(spacing: 4) {
                            Image(systemName: icon)
                                .font(.body)
                            Text(label)
                                .font(.caption)
                        }
                        .foregroundColor(intensityLevel == level ? .black : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(intensityLevel == level ? Color.leanOrange : Color.cardBackground)
                        .cornerRadius(10)
                    }
                }
            }
        }
    }

    // MARK: - AI Mode

    private var aiModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Describe your activity")
                .font(.caption)
                .foregroundColor(.secondary)

            ZStack(alignment: .topLeading) {
                if customDescription.isEmpty {
                    Text("e.g. Played competitive pickleball for 45 minutes, pretty intense rally")
                        .font(.body)
                        .foregroundColor(.secondary.opacity(0.5))
                        .padding(4)
                }
                TextEditor(text: $customDescription)
                    .font(.body)
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80, maxHeight: 120)
            }
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(14)

            Button(action: estimateWithAI) {
                HStack {
                    if isEstimating {
                        ProgressView().tint(.black).padding(.trailing, 4)
                        Text("Estimating...")
                    } else {
                        Image(systemName: "sparkles")
                        Text("Estimate Calories")
                    }
                }
                .font(.subheadline.bold())
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(profile.groqAPIKey.isEmpty ? Color.leanGray : Color.leanBlue)
                .cornerRadius(10)
            }
            .disabled(isEstimating || customDescription.isEmpty || profile.groqAPIKey.isEmpty)

            if !aiReasoning.isEmpty {
                Text(aiReasoning)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color.cardBackground)
                    .cornerRadius(10)
            }
        }
    }

    // MARK: - Duration

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Duration")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(durationMinutes)) minutes")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Slider(value: $durationMinutes, in: 5...180, step: 5)
                .tint(.leanOrange)

            HStack {
                Text("5 min")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("3 hours")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .cardStyle()
    }

    // MARK: - Calorie Preview

    private var caloriePreview: some View {
        let cals = useAI ? estimatedCalories : calculatedCalories
        let metValue = useAI ? estimatedMET : (selectedPreset?.met(for: intensityLevel) ?? 0)

        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Estimated Burn")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(Int(cals)) kcal")
                    .font(.title.bold())
                    .foregroundColor(.leanOrange)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("MET Value")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: "%.1f", metValue))
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
        }
        .cardStyle()
    }

    // MARK: - Actions

    private func estimateWithAI() {
        guard !customDescription.isEmpty, !profile.groqAPIKey.isEmpty else { return }
        isEstimating = true
        errorMessage = nil

        Task {
            do {
                let result = try await groq.estimateActivityCalories(
                    activityDescription: customDescription,
                    durationMinutes: durationMinutes,
                    bodyWeightKg: profile.currentWeightKg,
                    apiKey: profile.groqAPIKey
                )
                estimatedCalories = result.calories_burned
                estimatedMET = result.met
                aiReasoning = result.reasoning
            } catch let error as GroqError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = error.localizedDescription
            }
            isEstimating = false
        }
    }

    private func saveActivity() {
        let activityName: String
        let category: String
        let met: Double
        let calories: Double

        if useAI {
            activityName = customDescription.isEmpty ? "Custom Activity" : String(customDescription.prefix(40))
            category = "cardio"
            met = estimatedMET
            calories = estimatedCalories > 0 ? estimatedCalories : calculatedCalories
        } else {
            guard let preset = selectedPreset else { return }
            activityName = preset.name
            category = preset.category
            met = preset.met(for: intensityLevel)
            calories = calculatedCalories
        }

        let entry = ActivityEntry(
            activityName: activityName,
            activityCategory: category,
            durationMinutes: durationMinutes,
            caloriesBurned: calories,
            intensityLevel: intensityLevel,
            met: met,
            notes: notes,
            aiEstimated: useAI
        )
        todayLog.activityEntries.append(entry)
        try? modelContext.save()
        dismiss()
    }

    private func categoryIcon(_ category: String) -> String {
        switch category {
        case "cardio": return "heart.fill"
        case "strength": return "dumbbell.fill"
        case "sport": return "sportscourt.fill"
        case "steps": return "figure.walk"
        default: return "flame.fill"
        }
    }
}
