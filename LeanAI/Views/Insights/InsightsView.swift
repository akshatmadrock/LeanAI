import SwiftUI
import SwiftData
import Charts

struct InsightsView: View {
    let profile: UserProfile
    @StateObject private var groq = GroqService()
    @State private var aiSummary: String = ""
    @State private var aiTips: [String] = []
    @State private var loadingAI = false

    private var last14Logs: [DailyLog] {
        profile.dailyLogs
            .filter { $0.date >= Date().daysAgo(14) }
            .sorted { $0.date < $1.date }
    }

    private var last7Logs: [DailyLog] {
        Array(last14Logs.suffix(7))
    }

    private var prevWeekLogs: [DailyLog] {
        profile.dailyLogs
            .filter { $0.date >= Date().daysAgo(14) && $0.date < Date().daysAgo(7) }
            .sorted { $0.date < $1.date }
    }

    private var thisWeekSummary: NutritionCalculator.WeeklySummary {
        NutritionCalculator.weeklySummary(
            logs: last7Logs,
            calorieTarget: profile.dailyCalorieTarget,
            proteinTarget: profile.dailyProteinGrams
        )
    }

    private var prevWeekSummary: NutritionCalculator.WeeklySummary {
        NutritionCalculator.weeklySummary(
            logs: prevWeekLogs,
            calorieTarget: profile.dailyCalorieTarget,
            proteinTarget: profile.dailyProteinGrams
        )
    }

    private var streak: Int {
        NutritionCalculator.currentDeficitStreak(
            logs: profile.dailyLogs,
            calorieTarget: profile.dailyCalorieTarget
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        weeklyScoreCard
                        aiSummaryCard
                        calorieAdherenceChart
                        weightTrendCard
                        macroAveragesCard
                        streakCalendarCard
                        weeklyComparisonCard
                    }
                    .padding()
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
            .task { await loadAISummary() }
        }
    }

    // MARK: - Weekly Score Card

    private var weeklyScoreCard: some View {
        let days = thisWeekSummary.daysOnTrack
        let emoji: String
        let message: String
        let color: Color

        switch days {
        case 7:
            emoji = "🏆"; message = "Perfect week! Absolutely crushing it."; color = .leanGreen
        case 5...6:
            emoji = "🔥"; message = "Great week — almost perfect!"; color = .leanGreen
        case 3...4:
            emoji = "👍"; message = "Solid progress. A few tweaks and you'll nail it."; color = .leanYellow
        case 1...2:
            emoji = "💪"; message = "Tough week. Every day is a fresh start."; color = .leanOrange
        default:
            emoji = "📝"; message = "Log your food to see your score here."; color = .leanGray
        }

        return VStack(spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This Week")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(days)")
                            .font(.system(size: 56, weight: .black, design: .rounded))
                            .foregroundColor(color)
                        Text("/ 7 days on track")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .padding(.top, 12)
                    }
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                }
                Spacer()
                Text(emoji)
                    .font(.system(size: 52))
            }

            // Mini day dots
            HStack(spacing: 8) {
                ForEach(last7Logs) { log in
                    let on = log.isOnTrack(
                        targetCalories: profile.dailyCalorieTarget,
                        proteinTarget: profile.dailyProteinGrams
                    )
                    VStack(spacing: 4) {
                        Circle()
                            .fill(log.foodEntries.isEmpty ? Color.leanGray.opacity(0.3) : (on ? Color.leanGreen : Color.leanRed))
                            .frame(width: 14, height: 14)
                        Text(log.date.dayOfWeekShort)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
                // Pad remaining days if < 7 logs
                if last7Logs.count < 7 {
                    ForEach(0..<(7 - last7Logs.count), id: \.self) { _ in
                        VStack(spacing: 4) {
                            Circle()
                                .fill(Color.leanGray.opacity(0.15))
                                .frame(width: 14, height: 14)
                            Text("·")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - AI Summary Card

    private var aiSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("AI Coach", systemImage: "brain.head.profile")
                    .font(.headline)
                    .foregroundColor(.leanBlue)
                Spacer()
                if loadingAI {
                    ProgressView().tint(.leanBlue).scaleEffect(0.8)
                }
            }

            if aiSummary.isEmpty && !loadingAI {
                Text(profile.groqAPIKey.isEmpty && Constants.defaultGroqAPIKey.isEmpty
                     ? "Add your Groq API key in Settings to enable AI coaching."
                     : "Log at least a few days to get personalised advice.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else if !aiSummary.isEmpty {
                Text(aiSummary)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))

                if !aiTips.isEmpty {
                    Divider().background(Color.leanGray.opacity(0.3))
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(aiTips, id: \.self) { tip in
                            HStack(alignment: .top, spacing: 8) {
                                Text("→")
                                    .foregroundColor(.leanBlue)
                                    .font(.caption)
                                Text(tip)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            } else {
                Text("Analysing your week…")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .cardStyle()
    }

    // MARK: - Calorie Adherence Chart (14 days)

    private var calorieAdherenceChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Calorie Adherence — Last 14 Days")
                .font(.headline)
                .foregroundColor(.white)

            Text("Green = under budget  ·  Red = over budget")
                .font(.caption)
                .foregroundColor(.secondary)

            if last14Logs.isEmpty {
                emptyChartPlaceholder(icon: "chart.bar.fill", message: "Log food to see adherence")
            } else {
                Chart(last14Logs) { log in
                    let target = profile.dailyCalorieTarget + log.totalCaloriesBurned * 0.5
                    let consumed = log.totalCaloriesConsumed
                    let isOver = consumed > target && consumed > 100

                    BarMark(
                        x: .value("Day", log.date, unit: .day),
                        y: .value("Calories", consumed > 0 ? consumed : 0)
                    )
                    .foregroundStyle(consumed < 100 ? AnyShapeStyle(Color.leanGray.opacity(0.3)) : AnyShapeStyle(isOver ? Color.leanRed.gradient : Color.leanGreen.gradient))
                    .cornerRadius(4)
                }
                // Target rule line
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.leanYellow.opacity(0.6))
                            .frame(width: geo.size.width, height: 1.5)
                            .position(x: geo.size.width / 2, y: proxy.position(forY: profile.dailyCalorieTarget) ?? geo.size.height / 2)
                    }
                }
                .frame(height: 150)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 2)) { value in
                        AxisValueLabel(format: .dateTime.day())
                            .foregroundStyle(Color.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                            .foregroundStyle(Color.secondary)
                        AxisGridLine().foregroundStyle(Color.leanGray.opacity(0.15))
                    }
                }

                HStack(spacing: 4) {
                    Rectangle().fill(Color.leanYellow.opacity(0.6)).frame(width: 20, height: 1.5)
                    Text("Daily target")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Weight Trend

    private var weightTrendCard: some View {
        let measurements = profile.measurements
            .filter { $0.date >= Date().daysAgo(30) }
            .sorted { $0.date < $1.date }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weight Trend — 30 Days")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if let first = measurements.first, let last = measurements.last {
                    let change = last.weightKg - first.weightKg
                    Text("\(change <= 0 ? "▼" : "▲") \(String(format: "%.1f", abs(change))) kg")
                        .font(.subheadline.bold())
                        .foregroundColor(change <= 0 ? .leanGreen : .leanRed)
                }
            }

            if measurements.count < 2 {
                emptyChartPlaceholder(icon: "chart.line.uptrend.xyaxis", message: "Log your weight daily to see your trend")
            } else {
                Chart {
                    RuleMark(y: .value("Goal", profile.targetWeightKg))
                        .foregroundStyle(Color.leanGreen.opacity(0.5))
                        .lineStyle(StrokeStyle(dash: [5, 3]))
                        .annotation(position: .trailing) {
                            Text("Goal").font(.caption2).foregroundColor(.leanGreen)
                        }

                    ForEach(measurements) { m in
                        LineMark(
                            x: .value("Date", m.date),
                            y: .value("Weight", m.weightKg)
                        )
                        .foregroundStyle(Color.leanBlue)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Date", m.date),
                            y: .value("Weight", m.weightKg)
                        )
                        .foregroundStyle(Color.leanBlue.opacity(0.15))
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", m.date),
                            y: .value("Weight", m.weightKg)
                        )
                        .foregroundStyle(Color.leanBlue)
                        .symbolSize(25)
                    }
                }
                .frame(height: 150)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear)) {
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(Color.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks {
                        AxisValueLabel().foregroundStyle(Color.secondary)
                        AxisGridLine().foregroundStyle(Color.leanGray.opacity(0.15))
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Macro Averages (this week vs target)

    private var macroAveragesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Weekly Macro Averages")
                .font(.headline)
                .foregroundColor(.white)

            if last7Logs.filter({ !$0.foodEntries.isEmpty }).isEmpty {
                Text("Log your meals to see macro averages")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                MacroAvgRow(
                    label: "Protein",
                    avg: thisWeekSummary.avgProteinG,
                    target: profile.dailyProteinGrams,
                    color: .leanOrange,
                    unit: "g",
                    note: "Most important — protects your muscle"
                )
                MacroAvgRow(
                    label: "Carbs",
                    avg: thisWeekSummary.avgCarbsG,
                    target: profile.dailyCarbsGrams,
                    color: .leanPurple,
                    unit: "g",
                    note: "Energy for workouts"
                )
                MacroAvgRow(
                    label: "Fat",
                    avg: thisWeekSummary.avgFatG,
                    target: profile.dailyFatGrams,
                    color: .leanYellow,
                    unit: "g",
                    note: "Needed for hormones"
                )
                MacroAvgRow(
                    label: "Calories",
                    avg: thisWeekSummary.avgCaloriesConsumed,
                    target: profile.dailyCalorieTarget,
                    color: .leanBlue,
                    unit: "kcal",
                    note: nil
                )
            }
        }
        .cardStyle()
    }

    // MARK: - Streak Calendar (last 35 days as 5×7 grid)

    private var streakCalendarCard: some View {
        let last35 = (0..<35).map { i -> (date: Date, status: DayStatus) in
            let date = Date().daysAgo(34 - i)
            let log = profile.dailyLogs.first(where: {
                Calendar.current.isDate($0.date, inSameDayAs: date)
            })
            if let log = log {
                if log.foodEntries.isEmpty {
                    return (date, .noData)
                }
                return (date, log.isOnTrack(
                    targetCalories: profile.dailyCalorieTarget,
                    proteinTarget: profile.dailyProteinGrams
                ) ? .onTrack : .offTrack)
            }
            return (date, .future)
        }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("35-Day Calendar")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("🔥 \(streak) day streak")
                    .font(.subheadline.bold())
                    .foregroundColor(.leanYellow)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(["M","T","W","Th","F","Sa","Su"], id: \.self) { d in
                    Text(d).font(.system(size: 9)).foregroundColor(.secondary)
                }
                ForEach(last35.indices, id: \.self) { i in
                    let day = last35[i]
                    Circle()
                        .fill(day.status.color)
                        .frame(height: 28)
                        .overlay(
                            Text(Calendar.current.component(.day, from: day.date) == 1
                                 ? "1" : "")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.6))
                        )
                }
            }

            HStack(spacing: 16) {
                LegendDot(color: .leanGreen, label: "On track")
                LegendDot(color: .leanRed, label: "Over budget")
                LegendDot(color: .leanGray.opacity(0.3), label: "Not logged")
            }
        }
        .cardStyle()
    }

    // MARK: - Weekly Comparison

    private var weeklyComparisonCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("This Week vs Last Week")
                .font(.headline)
                .foregroundColor(.white)

            if last7Logs.isEmpty && prevWeekLogs.isEmpty {
                Text("Keep logging to see weekly comparisons")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ComparisonRow(
                    label: "Avg Calories",
                    thisWeek: thisWeekSummary.avgCaloriesConsumed,
                    lastWeek: prevWeekSummary.avgCaloriesConsumed,
                    unit: "kcal",
                    lowerIsBetter: true
                )
                ComparisonRow(
                    label: "Avg Protein",
                    thisWeek: thisWeekSummary.avgProteinG,
                    lastWeek: prevWeekSummary.avgProteinG,
                    unit: "g",
                    lowerIsBetter: false
                )
                ComparisonRow(
                    label: "Workouts",
                    thisWeek: Double(thisWeekSummary.workoutsCompleted),
                    lastWeek: Double(prevWeekSummary.workoutsCompleted),
                    unit: "",
                    lowerIsBetter: false
                )
                ComparisonRow(
                    label: "Cal Burned",
                    thisWeek: thisWeekSummary.totalCaloriesBurned,
                    lastWeek: prevWeekSummary.totalCaloriesBurned,
                    unit: "kcal",
                    lowerIsBetter: false
                )
            }
        }
        .cardStyle()
    }

    // MARK: - Helpers

    private func emptyChartPlaceholder(icon: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(.secondary.opacity(0.5))
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
    }

    private func loadAISummary() async {
        guard last7Logs.filter({ !$0.foodEntries.isEmpty }).count >= 3 else { return }
        loadingAI = true
        defer { loadingAI = false }

        let apiKey = profile.groqAPIKey.isEmpty ? Constants.defaultGroqAPIKey : profile.groqAPIKey
        guard !apiKey.isEmpty else { return }

        do {
            let advice = try await groq.getWeeklyAdvice(
                userName: profile.name,
                avgCaloriesConsumed: thisWeekSummary.avgCaloriesConsumed,
                avgProteinG: thisWeekSummary.avgProteinG,
                calorieTarget: profile.dailyCalorieTarget,
                proteinTarget: profile.dailyProteinGrams,
                weightChangeKg: thisWeekSummary.weightChange,
                workoutsCompleted: thisWeekSummary.workoutsCompleted,
                currentWeightKg: profile.currentWeightKg,
                targetWeightKg: profile.targetWeightKg,
                apiKey: apiKey
            )
            aiSummary = advice.summary
            aiTips = advice.key_advice
        } catch {
            // AI summary is optional — fail silently
        }
    }
}

// MARK: - Supporting types & components

enum DayStatus {
    case onTrack, offTrack, noData, future

    var color: Color {
        switch self {
        case .onTrack:  return .leanGreen
        case .offTrack: return .leanRed.opacity(0.7)
        case .noData:   return Color.leanGray.opacity(0.25)
        case .future:   return Color.clear
        }
    }
}

struct MacroAvgRow: View {
    let label: String
    let avg: Double
    let target: Double
    let color: Color
    let unit: String
    let note: String?

    private var pct: Double { avg.progressFraction(of: target) }
    private var isGood: Bool {
        label == "Calories" ? avg <= target * 1.05 : avg >= target * 0.85
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.subheadline)
                        .foregroundColor(.white)
                    if let note = note {
                        Text(note)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(Int(avg))")
                        .font(.system(.callout, design: .rounded).bold())
                        .foregroundColor(isGood ? color : .leanRed)
                    Text("/ \(Int(target)) \(unit)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(isGood ? "✓" : "!")
                    .font(.caption.bold())
                    .foregroundColor(isGood ? .leanGreen : .leanRed)
                    .frame(width: 16)
            }
            ProgressBarView(value: pct, color: isGood ? color : .leanRed)
        }
    }
}

struct ComparisonRow: View {
    let label: String
    let thisWeek: Double
    let lastWeek: Double
    let unit: String
    let lowerIsBetter: Bool

    private var improved: Bool {
        lowerIsBetter ? thisWeek <= lastWeek : thisWeek >= lastWeek
    }
    private var change: Double { thisWeek - lastWeek }

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 110, alignment: .leading)

            Spacer()

            Text("\(Int(lastWeek))\(unit.isEmpty ? "" : " \(unit)")")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .trailing)

            Image(systemName: change == 0 ? "minus" : (change > 0 ? "arrow.up" : "arrow.down"))
                .font(.caption2)
                .foregroundColor(improved ? .leanGreen : .leanRed)
                .frame(width: 20)

            Text("\(Int(thisWeek))\(unit.isEmpty ? "" : " \(unit)")")
                .font(.subheadline.bold())
                .foregroundColor(improved ? .leanGreen : .leanRed)
                .frame(width: 70, alignment: .leading)
        }
    }
}

struct LegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
    }
}
