import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    let profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    @StateObject private var healthKit = HealthKitService()
    @StateObject private var groq = GroqService()
    @State private var showWeightEntry = false
    @State private var todayWeight = ""
    @State private var advisorText = ""

    private var today: DailyLog { getOrCreateTodayLog() }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        headerView
                        calorieStatusCard
                        macrosCard
                        statsRow
                        activityCard
                        if !advisorText.isEmpty { advisorCard }
                        weightLogCard
                    }
                    .padding()
                    .padding(.bottom, 100)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showWeightEntry) {
                WeightEntrySheet(todayWeight: $todayWeight, profile: profile, log: today, onSave: saveWeight)
            }
            .task {
                await healthKit.requestAuthorization()
                var steps = today.steps
                await healthKit.syncSteps(into: &steps)
                if steps != today.steps { today.steps = steps; try? modelContext.save() }
                if profile.dailyLogs.count >= 5 { await fetchAdvisor() }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task {
                    var steps = today.steps
                    await healthKit.syncSteps(into: &steps)
                    if steps != today.steps { today.steps = steps; try? modelContext.save() }
                }
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(greetingText), \(profile.name.components(separatedBy: " ").first ?? profile.name) 👋")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                if profile.currentWeightKg > profile.targetWeightKg {
                    Text("\(String(format: "%.1f", profile.currentWeightKg - profile.targetWeightKg)) kg to go · ~\(profile.estimatedWeeksToGoal) weeks")
                        .font(.caption).foregroundColor(.secondary)
                } else {
                    Text("🎉 Goal reached! Amazing work.")
                        .font(.caption).foregroundColor(.leanGreen)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Date().dayOfWeekFull).font(.caption).foregroundColor(.secondary)
                Text(Date().dateFormatted).font(.caption2).foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Calorie Status Card (plain language)

    private var calorieStatusCard: some View {
        let target = profile.dailyCalorieTarget
        let consumed = today.totalCaloriesConsumed
        let burned = today.totalCaloriesBurned
        let remaining = target - consumed + burned * 0.5
        let isOver = remaining < 0
        let progress = min(consumed / max(target + burned * 0.5, 1), 1.2)

        return VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.leanBlue.opacity(0.18), lineWidth: 22)
                    .frame(width: 176, height: 176)
                Circle()
                    .trim(from: 0, to: min(progress, 1.0))
                    .stroke(isOver ? Color.leanRed : Color.leanBlue,
                            style: StrokeStyle(lineWidth: 22, lineCap: .round))
                    .frame(width: 176, height: 176)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 0.8), value: consumed)
                VStack(spacing: 2) {
                    Text("\(Int(consumed))")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("calories eaten")
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            VStack(spacing: 6) {
                if isOver {
                    Label("\(Int(abs(remaining))) kcal over today's budget", systemImage: "exclamationmark.circle.fill")
                        .font(.subheadline.bold()).foregroundColor(.leanRed)
                } else {
                    Label("\(Int(remaining)) kcal left for today", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.bold()).foregroundColor(.leanGreen)
                }
                Text("Budget: \(Int(target)) kcal  ·  Activities: +\(Int(burned)) kcal")
                    .font(.caption).foregroundColor(.secondary)
            }

            let streak = NutritionCalculator.currentDeficitStreak(logs: profile.dailyLogs, calorieTarget: target)
            if streak > 0 {
                HStack(spacing: 6) {
                    Text("🔥")
                    Text("\(streak) day\(streak == 1 ? "" : "s") on track — keep it up!")
                        .font(.subheadline.bold()).foregroundColor(.leanYellow)
                }
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(Color.leanYellow.opacity(0.12)).cornerRadius(20)
            }
        }
        .cardStyle()
    }

    // MARK: - Macros Card

    private var macrosCard: some View {
        VStack(spacing: 14) {
            HStack {
                Text("What you've eaten")
                    .font(.headline).foregroundColor(.white)
                Spacer()
                let pct = today.totalProteinG / profile.dailyProteinGrams
                if pct >= 0.85 {
                    Label("Protein ✓", systemImage: "checkmark.seal.fill")
                        .font(.caption).foregroundColor(.leanGreen)
                } else {
                    Label("Eat more protein", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundColor(.leanOrange)
                }
            }
            FriendlyMacroBar(icon: "🥩", label: "Protein", sublabel: "Protects muscle",
                             consumed: today.totalProteinG, target: profile.dailyProteinGrams, color: .leanOrange, unit: "g")
            FriendlyMacroBar(icon: "🍚", label: "Carbs", sublabel: "Energy fuel",
                             consumed: today.totalCarbsG, target: profile.dailyCarbsGrams, color: .leanPurple, unit: "g")
            FriendlyMacroBar(icon: "🥑", label: "Fat", sublabel: "For hormones",
                             consumed: today.totalFatG, target: profile.dailyFatGrams, color: .leanYellow, unit: "g")
        }
        .cardStyle()
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatCard(icon: "scalemass.fill", color: .leanBlue, label: "Weight",
                     value: today.morningWeightKg?.kgFormatted ?? "—", subtitle: "")
                .onTapGesture { showWeightEntry = true }
            StatCard(icon: healthKit.isAvailable ? "heart.fill" : "figure.walk", color: .leanGreen,
                     label: "Steps", value: today.steps.stepsFormatted,
                     subtitle: healthKit.isAvailable ? "Apple Health" : "manual")
            StatCard(icon: "flame.fill", color: .leanOrange, label: "Burned",
                     value: "\(Int(today.totalCaloriesBurned))", subtitle: "kcal")
        }
    }

    // MARK: - Activity Card

    private var activityCard: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Activities Today")
                    .font(.headline).foregroundColor(.white)
                Spacer()
            }

            if today.activityEntries.isEmpty && today.steps < 500 {
                HStack(spacing: 10) {
                    Image(systemName: "figure.run").foregroundColor(.secondary)
                    Text("No workouts yet — tap Move to add one")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                if today.steps > 0 {
                    HStack {
                        Image(systemName: healthKit.isAvailable ? "heart.fill" : "figure.walk")
                            .foregroundColor(.leanGreen).frame(width: 24)
                        Text(healthKit.isAvailable ? "Steps (Apple Health)" : "Steps")
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(today.steps.stepsFormatted)")
                            .foregroundColor(.secondary).font(.caption)
                        Text("≈ \(Int(ActivityCalculator.stepsToCalories(steps: today.steps, weightKg: profile.currentWeightKg, heightCm: profile.heightCm))) kcal")
                            .foregroundColor(.leanGreen).font(.caption)
                    }
                }
                ForEach(today.activityEntries) { entry in
                    ActivityEntryRow(entry: entry) {
                        modelContext.delete(entry)
                        try? modelContext.save()
                    }
                }
            }

            Divider().background(Color.leanGray.opacity(0.3))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your body burns ~\(Int(profile.bmr)) kcal at rest")
                        .font(.caption).foregroundColor(.secondary)
                    Text("With your lifestyle: ~\(Int(profile.tdee)) kcal/day")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Your daily budget").font(.caption2).foregroundColor(.secondary)
                    Text("\(Int(profile.dailyCalorieTarget)) kcal")
                        .font(.caption.bold()).foregroundColor(.leanGreen)
                }
            }
        }
        .cardStyle()
    }

    private var advisorCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Your AI Coach says:", systemImage: "brain.head.profile")
                .font(.subheadline.bold()).foregroundColor(.leanBlue)
            Text(advisorText)
                .font(.subheadline).foregroundColor(.white.opacity(0.85))
        }
        .cardStyle()
    }

    private var weightLogCard: some View {
        Button(action: { showWeightEntry = true }) {
            HStack {
                Image(systemName: "scalemass.fill").foregroundColor(.leanBlue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(today.morningWeightKg == nil ? "Log your weight today" : "Update weight")
                        .foregroundColor(.white)
                    Text("Keeps your calorie targets accurate as you lose weight")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.secondary).font(.caption)
            }
            .cardStyle()
        }
    }

    // MARK: - Helpers

    private var greetingText: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 12 { return "Good morning" }
        if h < 17 { return "Good afternoon" }
        if h < 21 { return "Good evening" }
        return "Hey"
    }

    private func getOrCreateTodayLog() -> DailyLog {
        let today = Calendar.current.startOfDay(for: Date())
        if let existing = profile.dailyLogs.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) { return existing }
        let log = DailyLog(date: today)
        profile.dailyLogs.append(log)
        try? modelContext.save()
        return log
    }

    private func saveWeight() {
        if let weight = Double(todayWeight.replacingOccurrences(of: ",", with: ".")) {
            today.morningWeightKg = weight
            profile.currentWeightKg = weight
            profile.measurements.append(BodyMeasurement(weightKg: weight))
            try? modelContext.save()
        }
        showWeightEntry = false
    }

    private func fetchAdvisor() async {
        let logs7 = profile.dailyLogs.filter { $0.date >= Date().daysAgo(7) }
        let summary = NutritionCalculator.weeklySummary(logs: logs7, calorieTarget: profile.dailyCalorieTarget, proteinTarget: profile.dailyProteinGrams)
        let apiKey = profile.groqAPIKey.isEmpty ? Constants.defaultGroqAPIKey : profile.groqAPIKey
        guard !apiKey.isEmpty else { return }
        if let advice = try? await groq.getWeeklyAdvice(
            userName: profile.name, avgCaloriesConsumed: summary.avgCaloriesConsumed,
            avgProteinG: summary.avgProteinG, calorieTarget: profile.dailyCalorieTarget,
            proteinTarget: profile.dailyProteinGrams, weightChangeKg: summary.weightChange,
            workoutsCompleted: summary.workoutsCompleted, currentWeightKg: profile.currentWeightKg,
            targetWeightKg: profile.targetWeightKg, apiKey: apiKey) {
            advisorText = advice.summary
        }
    }
}

// MARK: - Friendly Macro Bar

struct FriendlyMacroBar: View {
    let icon: String; let label: String; let sublabel: String
    let consumed: Double; let target: Double; let color: Color; let unit: String

    private var progress: Double { (consumed / max(target, 1)).clamped(to: 0...1.2) }
    private var isOver: Bool { consumed > target * 1.05 }

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text(icon)
                Text(label).font(.subheadline).foregroundColor(.white)
                Text("·").foregroundColor(.secondary)
                Text(sublabel).font(.caption).foregroundColor(.secondary)
                Spacer()
                Text("\(Int(consumed)) / \(Int(target))\(unit)")
                    .font(.caption.bold())
                    .foregroundColor(isOver ? .leanRed : .white)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.2)).frame(height: 9)
                    Capsule()
                        .fill(isOver ? Color.leanRed : color)
                        .frame(width: geo.size.width * min(progress, 1.0), height: 9)
                        .animation(.spring(duration: 0.6), value: progress)
                }
            }
            .frame(height: 9)
        }
    }
}
