import SwiftUI
import SwiftData
import Charts

struct ActivityView: View {
    let profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    @StateObject private var healthKit = HealthKitService()
    @State private var showAddActivity = false
    @State private var showStepEntry = false
    @State private var stepInput = ""

    private var todayLog: DailyLog { getOrCreateTodayLog() }

    private var weekLogs: [DailyLog] {
        profile.dailyLogs
            .filter { $0.date >= Date().daysAgo(7) }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        // HealthKit status banner — authorized = green, denied = orange prompt
                        if healthKit.isAvailable {
                            if healthKit.isAuthorized {
                                healthKitBanner
                            } else {
                                healthKitDeniedBanner
                            }
                        }
                        todaySummaryCard
                        stepsCard
                        todayActivitiesCard
                        weeklyChartCard
                    }
                    .padding()
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Move")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAddActivity = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.leanOrange).font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showAddActivity) {
                AddActivityView(profile: profile, todayLog: todayLog)
            }
            .task {
                await syncHealthKitSteps()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task { await syncHealthKitSteps() }
            }
            .alert("Steps Today", isPresented: $showStepEntry) {
                TextField("e.g. 8500", text: $stepInput)
                    .keyboardType(.numberPad)
                Button("Save") {
                    if let steps = Int(stepInput.trimmingCharacters(in: .whitespaces)), steps >= 0 {
                        todayLog.steps = steps
                        try? modelContext.save()
                    }
                    stepInput = ""
                }
                Button("Cancel", role: .cancel) { stepInput = "" }
            } message: {
                Text("Enter how many steps you've taken today.")
            }
        }
    }

    // MARK: - HealthKit Banners

    /// Shown when HealthKit is available AND authorized — green, all good
    private var healthKitBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "heart.fill").foregroundColor(.pink)
            VStack(alignment: .leading, spacing: 2) {
                Text("Steps auto-synced from Apple Health")
                    .font(.caption.bold()).foregroundColor(.white)
                Text("You don't need to enter steps manually")
                    .font(.caption2).foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.leanGreen).font(.title3)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.pink.opacity(0.1)).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.pink.opacity(0.25), lineWidth: 1))
    }

    /// Shown when HealthKit is available but NOT authorized — orange, prompt to grant
    private var healthKitDeniedBanner: some View {
        Button(action: openHealthSettings) {
            HStack(spacing: 10) {
                Image(systemName: "heart.slash.fill").foregroundColor(.leanOrange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Health access needed for steps")
                        .font(.caption.bold()).foregroundColor(.white)
                    Text("Tap to open Settings and grant access")
                        .font(.caption2).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(.leanOrange).font(.title3)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color.leanOrange.opacity(0.12)).cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.leanOrange.opacity(0.3), lineWidth: 1))
        }
    }

    private func openHealthSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Today Summary

    private var todaySummaryCard: some View {
        HStack(spacing: 0) {
            ActivityStat(icon: "flame.fill", color: .leanOrange, label: "Burned",
                         value: "\(Int(todayLog.totalCaloriesBurned))", unit: "kcal")
            Divider().frame(height: 50).background(Color.leanGray.opacity(0.3))
            ActivityStat(icon: healthKit.isAvailable ? "heart.fill" : "figure.walk",
                         color: healthKit.isAvailable ? .pink : .leanGreen,
                         label: "Steps", value: todayLog.steps.stepsFormatted, unit: "")
            Divider().frame(height: 50).background(Color.leanGray.opacity(0.3))
            ActivityStat(icon: "clock.fill", color: .leanBlue, label: "Active",
                         value: "\(Int(todayLog.activityEntries.reduce(0) { $0 + $1.durationMinutes }))", unit: "min")
        }
        .cardStyle()
    }

    // MARK: - Steps Card

    private var stepsCard: some View {
        VStack(spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: healthKit.isAvailable ? "heart.fill" : "figure.walk")
                        .foregroundColor(healthKit.isAvailable ? .pink : .leanGreen)
                    Text(healthKit.isAvailable ? "Steps — Auto from Apple Health" : "Steps Today")
                        .font(.headline).foregroundColor(.white)
                }
                Spacer()
                if !healthKit.isAvailable {
                    Button(todayLog.steps > 0 ? "Edit" : "Add manually") {
                        stepInput = todayLog.steps > 0 ? "\(todayLog.steps)" : ""
                        showStepEntry = true
                    }
                    .font(.caption).foregroundColor(.leanBlue)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.leanGreen.opacity(0.2)).frame(height: 12)
                    Capsule()
                        .fill(healthKit.isAvailable ? Color.pink : Color.leanGreen)
                        .frame(width: geo.size.width * min(Double(todayLog.steps) / 10000.0, 1.0), height: 12)
                        .animation(.spring(duration: 0.6), value: todayLog.steps)
                }
            }
            .frame(height: 12)

            HStack {
                Text("\(todayLog.steps.stepsFormatted) / 10,000 steps")
                    .font(.subheadline.bold()).foregroundColor(.white)
                Spacer()
                Text("≈ \(Int(ActivityCalculator.stepsToCalories(steps: todayLog.steps, weightKg: profile.currentWeightKg, heightCm: profile.heightCm))) kcal")
                    .font(.caption).foregroundColor(.leanGreen)
            }

            if healthKit.isAvailable {
                Text("Refreshes automatically as you move")
                    .font(.caption2).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .cardStyle()
    }

    // MARK: - Today Activities

    private var todayActivitiesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Workouts & Sports")
                    .font(.headline).foregroundColor(.white)
                Spacer()
                Button(action: { showAddActivity = true }) {
                    Label("Add", systemImage: "plus")
                        .font(.caption).foregroundColor(.leanOrange)
                }
            }

            if todayLog.activityEntries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "figure.run.circle")
                        .font(.largeTitle).foregroundColor(.secondary)
                    Text("No workouts yet today")
                        .font(.subheadline).foregroundColor(.secondary)
                    Text("Pickleball, weights, a run — add it!")
                        .font(.caption).foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 20)
            } else {
                ForEach(todayLog.activityEntries) { entry in
                    ActivityEntryRow(entry: entry) {
                        modelContext.delete(entry)
                        try? modelContext.save()
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Weekly Chart

    private var weeklyChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.headline).foregroundColor(.white)

            if weekLogs.isEmpty {
                Text("Keep moving — your weekly chart will appear here")
                    .foregroundColor(.secondary).font(.subheadline)
            } else {
                Chart(weekLogs) { log in
                    BarMark(x: .value("Day", log.date, unit: .day),
                            y: .value("Burned", log.totalCaloriesBurned))
                        .foregroundStyle(Color.leanOrange.gradient).cornerRadius(4)
                }
                .frame(height: 140)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                            .foregroundStyle(Color.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks { AxisValueLabel().foregroundStyle(Color.secondary) }
                }
            }

            let weekSummary = ActivityCalculator.weeklyActivitySummary(entries: weekLogs.flatMap(\.activityEntries))
            HStack {
                WeeklyStat(label: "Total Burned", value: "\(Int(weekSummary.totalCaloriesBurned)) kcal")
                WeeklyStat(label: "Workout Days", value: "\(weekSummary.workoutDays)")
                WeeklyStat(label: "Active Time",
                           value: "\(Int(weekSummary.totalDurationMinutes / 60))h \(Int(weekSummary.totalDurationMinutes.truncatingRemainder(dividingBy: 60)))m")
            }
        }
        .cardStyle()
    }

    // MARK: - Helpers

    private func getOrCreateTodayLog() -> DailyLog {
        let today = Calendar.current.startOfDay(for: Date())
        if let existing = profile.dailyLogs.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) { return existing }
        let log = DailyLog(date: today)
        profile.dailyLogs.append(log)
        try? modelContext.save()
        return log
    }

    private func syncHealthKitSteps() async {
        await healthKit.requestAuthorization()
        var steps = todayLog.steps
        await healthKit.syncSteps(into: &steps)
        if steps != todayLog.steps {
            todayLog.steps = steps
            try? modelContext.save()
        }
    }
}
