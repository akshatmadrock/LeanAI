import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var currentStep = 0
    @State private var name = ""
    @State private var dateOfBirth = Calendar.current.date(byAdding: .year, value: -28, to: Date()) ?? Date()
    @State private var biologicalSex = "male"
    @State private var heightCm: Double = 175
    @State private var currentWeightKg: Double = 85
    @State private var targetWeightKg: Double = 75
    @State private var activityLevel = 1
    @State private var groqAPIKey = ""

    let onComplete: () -> Void

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            TabView(selection: $currentStep) {
                WelcomeStep(onNext: { withAnimation { currentStep = 1 } })
                    .tag(0)

                PersonalInfoStep(
                    name: $name,
                    dateOfBirth: $dateOfBirth,
                    biologicalSex: $biologicalSex,
                    onNext: { withAnimation { currentStep = 2 } }
                )
                .tag(1)

                BodyMetricsStep(
                    heightCm: $heightCm,
                    currentWeightKg: $currentWeightKg,
                    targetWeightKg: $targetWeightKg,
                    onNext: { withAnimation { currentStep = 3 } }
                )
                .tag(2)

                ActivityLevelStep(
                    activityLevel: $activityLevel,
                    onNext: { withAnimation { currentStep = 4 } }
                )
                .tag(3)

                APIKeyStep(
                    groqAPIKey: $groqAPIKey,
                    onComplete: saveProfileAndComplete
                )
                .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentStep)

            // Progress dots
            VStack {
                Spacer()
                HStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { i in
                        Circle()
                            .fill(i == currentStep ? Color.leanGreen : Color.leanGray.opacity(0.4))
                            .frame(width: 8, height: 8)
                            .animation(.spring(), value: currentStep)
                    }
                }
                .padding(.bottom, 32)
            }
        }
    }

    private func saveProfileAndComplete() {
        let profile = UserProfile(
            name: name.isEmpty ? "You" : name,
            dateOfBirth: dateOfBirth,
            biologicalSex: biologicalSex,
            heightCm: heightCm,
            currentWeightKg: currentWeightKg,
            targetWeightKg: targetWeightKg,
            activityLevel: activityLevel,
            groqAPIKey: groqAPIKey
        )
        modelContext.insert(profile)

        // Save initial body measurement
        let measurement = BodyMeasurement(weightKg: currentWeightKg)
        profile.measurements.append(measurement)

        try? modelContext.save()
        UserDefaults.standard.set(true, forKey: Constants.onboardingCompleteKey)
        onComplete()
    }
}

// MARK: - Step 0: Welcome

private struct WelcomeStep: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "flame.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.leanOrange, .leanRed],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(spacing: 12) {
                Text("LeanAI")
                    .font(.system(size: 44, weight: .black))
                    .foregroundColor(.white)

                Text("Science-backed fat loss\nwith AI-powered tracking")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "brain.head.profile", color: .leanBlue, text: "AI food logging — just describe what you ate")
                FeatureRow(icon: "chart.line.uptrend.xyaxis", color: .leanGreen, text: "Adaptive calorie & macro targets")
                FeatureRow(icon: "dumbbell.fill", color: .leanOrange, text: "Strength testing to protect your muscle")
                FeatureRow(icon: "figure.2", color: .leanPurple, text: "Track progress together with a partner")
            }
            .padding(.horizontal, 24)

            Spacer()

            Button(action: onNext) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.leanGreen)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 60)
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 30)

            Text(text)
                .foregroundColor(.white.opacity(0.85))
                .font(.subheadline)
        }
    }
}

// MARK: - Step 1: Personal Info

private struct PersonalInfoStep: View {
    @Binding var name: String
    @Binding var dateOfBirth: Date
    @Binding var biologicalSex: String
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(step: "1 of 4", title: "About You", subtitle: "This helps calculate your BMR accurately")

            Form {
                Section("Name") {
                    TextField("Your name", text: $name)
                }

                Section("Date of Birth") {
                    DatePicker("Birthday", selection: $dateOfBirth, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }

                Section("Biological Sex") {
                    Picker("Sex", selection: $biologicalSex) {
                        Text("Male").tag("male")
                        Text("Female").tag("female")
                    }
                    .pickerStyle(.segmented)
                    Text("Used only for BMR calculation")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)

            OnboardingNextButton(label: "Next", action: onNext, disabled: name.isEmpty)
        }
        .background(Color.appBackground)
    }
}

// MARK: - Step 2: Body Metrics

private struct BodyMetricsStep: View {
    @Binding var heightCm: Double
    @Binding var currentWeightKg: Double
    @Binding var targetWeightKg: Double
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(step: "2 of 4", title: "Body Metrics", subtitle: "Be honest — accuracy matters for your calorie targets")

            ScrollView {
                VStack(spacing: 20) {
                    MetricSlider(
                        label: "Height",
                        value: $heightCm,
                        range: 140...220,
                        step: 1,
                        unit: "cm",
                        icon: "ruler"
                    )

                    MetricSlider(
                        label: "Current Weight",
                        value: $currentWeightKg,
                        range: 40...200,
                        step: 0.5,
                        unit: "kg",
                        icon: "scalemass.fill"
                    )

                    MetricSlider(
                        label: "Target Weight",
                        value: $targetWeightKg,
                        range: 40...200,
                        step: 0.5,
                        unit: "kg",
                        icon: "target"
                    )

                    // Show summary
                    if currentWeightKg > targetWeightKg {
                        VStack(spacing: 8) {
                            Text("Goal: Lose \(String(format: "%.1f", currentWeightKg - targetWeightKg)) kg")
                                .font(.headline)
                                .foregroundColor(.leanGreen)
                            Text("≈ \(Int(ceil((currentWeightKg - targetWeightKg) / 0.5))) weeks at 0.5 kg/week")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .cardStyle()
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 100)
            }

            OnboardingNextButton(
                label: "Next",
                action: onNext,
                disabled: targetWeightKg >= currentWeightKg
            )
        }
        .background(Color.appBackground)
    }
}

// MARK: - Step 3: Activity Level

private struct ActivityLevelStep: View {
    @Binding var activityLevel: Int
    let onNext: () -> Void

    let levels: [(title: String, subtitle: String, icon: String)] = [
        ("Sedentary", "Desk job, little to no exercise", "sofa.fill"),
        ("Lightly Active", "1-3 workouts per week", "figure.walk"),
        ("Moderately Active", "3-5 workouts per week", "figure.run"),
        ("Very Active", "6-7 workouts per week", "bolt.fill"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(step: "3 of 4", title: "Activity Level", subtitle: "Be honest — it's okay to say sedentary. We'll adjust over time.")

            VStack(spacing: 12) {
                ForEach(levels.indices, id: \.self) { i in
                    Button(action: { activityLevel = i }) {
                        HStack(spacing: 14) {
                            Image(systemName: levels[i].icon)
                                .font(.title2)
                                .foregroundColor(activityLevel == i ? .black : .leanGray)
                                .frame(width: 36)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(levels[i].title)
                                    .font(.headline)
                                    .foregroundColor(activityLevel == i ? .black : .white)
                                Text(levels[i].subtitle)
                                    .font(.caption)
                                    .foregroundColor(activityLevel == i ? .black.opacity(0.7) : .secondary)
                            }

                            Spacer()

                            if activityLevel == i {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.black)
                            }
                        }
                        .padding()
                        .background(activityLevel == i ? Color.leanGreen : Color.cardBackground)
                        .cornerRadius(14)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)

            Spacer()

            OnboardingNextButton(label: "Next", action: onNext, disabled: false)
        }
        .background(Color.appBackground)
    }
}

// MARK: - Step 4: API Key

private struct APIKeyStep: View {
    @Binding var groqAPIKey: String
    @State private var showKey = false
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(step: "4 of 4", title: "AI Setup", subtitle: "Groq powers food logging and calorie estimation")

            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("How to get your Groq API key:", systemImage: "info.circle")
                            .font(.subheadline)
                            .foregroundColor(.leanBlue)

                        Text("1. Go to console.groq.com\n2. Sign up (free)\n3. Create an API key\n4. Paste it below")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .cardStyle()
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Groq API Key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        HStack {
                            if showKey {
                                TextField("gsk_...", text: $groqAPIKey)
                            } else {
                                SecureField("gsk_...", text: $groqAPIKey)
                            }
                            Button(action: { showKey.toggle() }) {
                                Image(systemName: showKey ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.cardBackground)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    VStack(spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                            .font(.title)
                            .foregroundColor(.leanGreen)
                        Text("Your key is stored only on this device and never shared.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
                .padding(.top, 16)
            }

            VStack(spacing: 12) {
                Button(action: onComplete) {
                    Text("Start Tracking")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.leanGreen)
                        .cornerRadius(14)
                }

                if groqAPIKey.isEmpty {
                    Button(action: onComplete) {
                        Text("Skip for now (AI features disabled)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .background(Color.appBackground)
    }
}

// MARK: - Reusable Onboarding Components

private struct OnboardingHeader: View {
    let step: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Text(step)
                .font(.caption)
                .foregroundColor(.leanGreen)
                .fontWeight(.semibold)
                .padding(.top, 60)

            Text(title)
                .font(.largeTitle.bold())
                .foregroundColor(.white)

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
        }
    }
}

private struct OnboardingNextButton: View {
    let label: String
    let action: () -> Void
    let disabled: Bool

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(disabled ? Color.leanGray : Color.leanGreen)
                .cornerRadius(14)
        }
        .disabled(disabled)
        .padding(.horizontal, 24)
        .padding(.bottom, 48)
    }
}

private struct MetricSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(label, systemImage: icon)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(String(format: step < 1 ? "%.1f" : "%.0f", value)) \(unit)")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            Slider(value: $value, in: range, step: step)
                .tint(.leanGreen)
        }
        .cardStyle()
        .padding(.horizontal)
    }
}
