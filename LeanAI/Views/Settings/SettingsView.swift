import SwiftUI
import SwiftData

struct SettingsView: View {
    let profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    @State private var showAPIKeyEdit = false
    @State private var showProfileEdit = false
    @State private var showDeleteConfirm = false
    @State private var showAlgorithmDetails = false

    var body: some View {
        // NOTE: No NavigationStack here — MeTabView already provides one.
        // No ScrollView here — MeTabView's ScrollView wraps this.
        VStack(spacing: 12) {
            profileHeaderCard
            bodyGoalsCard
            targetsCard
            aiCard
            algorithmCard
            editProfileButton
            dangerZoneCard
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
        .sheet(isPresented: $showAPIKeyEdit) {
            APIKeyEditView(profile: profile)
        }
        .sheet(isPresented: $showProfileEdit) {
            ProfileEditView(profile: profile)
        }
        .confirmationDialog(
            "Reset All Data",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Everything", role: .destructive) { resetAllData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all your logs, measurements, and strength tests. Your profile will also be reset.")
        }
    }

    // MARK: - Profile Header

    private var profileHeaderCard: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(LinearGradient(colors: [.leanGreen, .leanBlue],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 56, height: 56)
                .overlay(
                    Text(String(profile.name.prefix(1)).uppercased())
                        .font(.title.bold()).foregroundColor(.white)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name).font(.title3.bold()).foregroundColor(.white)
                Text("\(profile.ageYears) yo · \(Int(profile.heightCm)) cm · \(profile.biologicalSex.capitalized)")
                    .font(.caption).foregroundColor(.secondary)
                Text("\(profile.currentWeightKg.kgFormatted) → \(profile.targetWeightKg.kgFormatted)")
                    .font(.caption).foregroundColor(.leanGreen)
            }
            Spacer()
            Button(action: { showProfileEdit = true }) {
                Image(systemName: "pencil.circle.fill")
                    .font(.title2).foregroundColor(.leanBlue)
            }
        }
        .cardStyle()
    }

    // MARK: - Body & Goals

    private var bodyGoalsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Body & Goals").font(.caption).foregroundColor(.secondary)
                .padding(.bottom, 2)
            SettingsRow(icon: "scalemass.fill",  color: .leanBlue,   label: "Current Weight", value: profile.currentWeightKg.kgFormatted)
            Divider().background(Color.white.opacity(0.08))
            SettingsRow(icon: "target",           color: .leanGreen,  label: "Target Weight",  value: profile.targetWeightKg.kgFormatted)
            Divider().background(Color.white.opacity(0.08))
            SettingsRow(icon: "ruler",            color: .leanOrange, label: "Height",         value: "\(Int(profile.heightCm)) cm")
            Divider().background(Color.white.opacity(0.08))
            SettingsRow(icon: "figure.run",       color: .leanPurple, label: "Activity Level", value: profile.activityLevelLabel)
            Divider().background(Color.white.opacity(0.08))
            SettingsRow(icon: "calendar",         color: .leanYellow, label: "Started",        value: profile.startDate.dateFormatted)
        }
        .cardStyle()
    }

    // MARK: - Daily Targets

    private var targetsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your Daily Targets").font(.caption).foregroundColor(.secondary)
                .padding(.bottom, 2)
            SettingsRow(icon: "flame.fill",   color: .leanRed,    label: "BMR",            value: "\(Int(profile.bmr)) kcal")
            Divider().background(Color.white.opacity(0.08))
            SettingsRow(icon: "bolt.fill",    color: .leanOrange, label: "TDEE",           value: "\(Int(profile.tdee)) kcal")
            Divider().background(Color.white.opacity(0.08))
            SettingsRow(icon: "fork.knife",   color: .leanGreen,  label: "Calorie Target", value: "\(Int(profile.dailyCalorieTarget)) kcal")
            Divider().background(Color.white.opacity(0.08))
            SettingsRow(icon: "circle.fill",  color: .leanOrange, label: "Protein Target", value: profile.dailyProteinGrams.gramsFormatted)
            Divider().background(Color.white.opacity(0.08))
            SettingsRow(icon: "circle.fill",  color: .leanPurple, label: "Carbs Target",   value: profile.dailyCarbsGrams.gramsFormatted)
            Divider().background(Color.white.opacity(0.08))
            SettingsRow(icon: "circle.fill",  color: .leanYellow, label: "Fat Target",     value: profile.dailyFatGrams.gramsFormatted)
        }
        .cardStyle()
    }

    // MARK: - AI Section

    private var aiCard: some View {
        let aiSucceeded = UserDefaults.standard.object(forKey: "aiLastCallSucceeded") as? Bool

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("AI (Groq)").font(.caption).foregroundColor(.secondary)
                Spacer()
                // AI status dot — only shows after first AI call
                if let succeeded = aiSucceeded {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(succeeded ? Color.leanGreen : Color.leanRed)
                            .frame(width: 8, height: 8)
                        Text(succeeded ? "AI Ready" : "AI Offline")
                            .font(.caption2)
                            .foregroundColor(succeeded ? .leanGreen : .leanRed)
                    }
                }
            }
            .padding(.bottom, 2)

            Button(action: { showAPIKeyEdit = true }) {
                HStack {
                    Label("API Key", systemImage: "key.fill").foregroundColor(.white)
                    Spacer()
                    Text(profile.groqAPIKey.isEmpty
                         ? "Using built-in key"
                         : "Custom ••••\(profile.groqAPIKey.suffix(4))")
                        .font(.caption)
                        .foregroundColor(profile.groqAPIKey.isEmpty ? .secondary : .leanGreen)
                    Image(systemName: "chevron.right")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            Divider().background(Color.white.opacity(0.08))
            VStack(alignment: .leading, spacing: 4) {
                Text("What AI can do")
                    .font(.subheadline).foregroundColor(.secondary)
                Text("• Understand food in plain English\n• Estimate workout calories\n• Give weekly coaching tips")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .cardStyle()
    }

    // MARK: - Algorithm Details

    private var algorithmCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureGroup(
                isExpanded: $showAlgorithmDetails,
                content: {
                    VStack(alignment: .leading, spacing: 10) {
                        Divider().background(Color.white.opacity(0.08)).padding(.top, 8)
                        AlgorithmInfoRow(label: "BMR Formula",  detail: "Mifflin-St Jeor (standard)")
                        AlgorithmInfoRow(label: "Deficit",      detail: "500 kcal/day → ~0.5 kg/week fat loss")
                        AlgorithmInfoRow(label: "Protein",      detail: "2.2 g/kg body weight (muscle preservation)")
                        AlgorithmInfoRow(label: "1RM Formula",  detail: "Epley: weight × (1 + reps/30)")
                        AlgorithmInfoRow(label: "Calorie Burn", detail: "MET × weight × hours (Compendium values)")
                    }
                },
                label: {
                    Label("Science Details", systemImage: "flask.fill")
                        .foregroundColor(.secondary).font(.subheadline)
                }
            )
            .tint(.secondary)
        }
        .cardStyle()
    }

    // MARK: - Edit Profile Button

    private var editProfileButton: some View {
        Button(action: { showProfileEdit = true }) {
            HStack {
                Label("Edit Profile & Goals", systemImage: "pencil.circle.fill")
                    .foregroundColor(.leanBlue)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .cardStyle()
    }

    // MARK: - Danger Zone

    private var dangerZoneCard: some View {
        Button(action: { showDeleteConfirm = true }) {
            HStack {
                Label("Reset All Data", systemImage: "trash.fill")
                    .foregroundColor(.leanRed)
                Spacer()
            }
        }
        .cardStyle()
    }

    // MARK: - Reset

    private func resetAllData() {
        for log in profile.dailyLogs { modelContext.delete(log) }
        for test in profile.strengthTests { modelContext.delete(test) }
        for m in profile.measurements { modelContext.delete(m) }
        profile.currentWeightKg = profile.startWeightKg
        UserDefaults.standard.set(false, forKey: Constants.onboardingCompleteKey)
        try? modelContext.save()
    }
}

// MARK: - API Key Edit

struct APIKeyEditView: View {
    let profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var keyInput = ""
    @State private var showKey = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Groq API Key", systemImage: "key.fill")
                            .font(.headline).foregroundColor(.white)
                        Text("Get a free key at console.groq.com")
                            .font(.caption).foregroundColor(.secondary)
                        Text("A built-in key is already active — you only need your own if you use the app heavily.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal).padding(.top, 32)

                    HStack {
                        if showKey {
                            TextField("gsk_...", text: $keyInput)
                                .font(.body).foregroundColor(.white)
                        } else {
                            SecureField("gsk_...", text: $keyInput)
                                .font(.body).foregroundColor(.white)
                        }
                        Button(action: { showKey.toggle() }) {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.cardBackground).cornerRadius(12)
                    .padding(.horizontal)

                    Button(action: saveKey) {
                        Text("Save Key")
                            .font(.headline).foregroundColor(.black)
                            .frame(maxWidth: .infinity).padding()
                            .background(keyInput.isEmpty ? Color.leanGray : Color.leanGreen)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal).disabled(keyInput.isEmpty)

                    if !profile.groqAPIKey.isEmpty {
                        Button(action: clearKey) {
                            Text("Remove Key (use built-in)").foregroundColor(.leanRed)
                        }
                    }

                    Spacer()
                }
            }
            .navigationTitle("Groq API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { keyInput = profile.groqAPIKey }
        }
    }

    private func saveKey() {
        profile.groqAPIKey = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        try? modelContext.save()
        dismiss()
    }

    private func clearKey() {
        profile.groqAPIKey = ""
        keyInput = ""
        try? modelContext.save()
    }
}

// MARK: - Profile Edit View

struct ProfileEditView: View {
    let profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var heightCm: Double
    @State private var targetWeightKg: Double
    @State private var activityLevel: Int

    init(profile: UserProfile) {
        self.profile = profile
        _name = State(initialValue: profile.name)
        _heightCm = State(initialValue: profile.heightCm)
        _targetWeightKg = State(initialValue: profile.targetWeightKg)
        _activityLevel = State(initialValue: profile.activityLevel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                Form {
                    Section("Name") {
                        TextField("Name", text: $name)
                    }
                    Section("Height") {
                        HStack {
                            Text("Height"); Spacer()
                            Text("\(Int(heightCm)) cm")
                            Slider(value: $heightCm, in: 140...220, step: 1)
                                .frame(width: 120).tint(.leanGreen)
                        }
                    }
                    Section("Target Weight") {
                        HStack {
                            Text("Target"); Spacer()
                            Text("\(targetWeightKg.oneDecimal) kg")
                            Slider(value: $targetWeightKg, in: 40...150, step: 0.5)
                                .frame(width: 120).tint(.leanGreen)
                        }
                    }
                    Section("Activity Level") {
                        Picker("Activity Level", selection: $activityLevel) {
                            Text("Sedentary").tag(0)
                            Text("Lightly Active").tag(1)
                            Text("Moderately Active").tag(2)
                            Text("Very Active").tag(3)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.appBackground)
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") { saveProfile() }.fontWeight(.semibold)
                }
            }
        }
    }

    private func saveProfile() {
        profile.name = name
        profile.heightCm = heightCm
        profile.targetWeightKg = targetWeightKg
        profile.activityLevel = activityLevel
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Supporting Views

struct SettingsRow: View {
    let icon: String
    let color: Color
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(label).foregroundColor(.white)
            Spacer()
            Text(value).foregroundColor(.secondary).font(.subheadline)
        }
    }
}

struct AlgorithmInfoRow: View {
    let label: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.subheadline).foregroundColor(.white)
            Text(detail).font(.caption).foregroundColor(.secondary)
        }
    }
}
