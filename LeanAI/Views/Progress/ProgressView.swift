import SwiftUI
import SwiftData
import Charts

struct WeightProgressView: View {
    let profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    @State private var showAddMeasurement = false
    @State private var timeRange: TimeRange = .month

    enum TimeRange: String, CaseIterable {
        case week = "1W"
        case month = "1M"
        case threeMonths = "3M"
        case all = "All"

        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .threeMonths: return 90
            case .all: return 3650
            }
        }
    }

    private var filteredMeasurements: [BodyMeasurement] {
        profile.measurements
            .filter { $0.date >= Date().daysAgo(timeRange.days) }
            .sorted { $0.date < $1.date }
    }

    private var weightDataPoints: [(date: Date, weight: Double)] {
        filteredMeasurements.map { ($0.date, $0.weightKg) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Overall progress card
                        overallProgressCard

                        // Time range selector
                        timeRangePicker

                        // Weight chart
                        weightChartCard

                        // Stats summary
                        statsSummaryCard

                        // Measurements list
                        measurementsCard

                        // Weekly summary for last week
                        weeklyRecapCard
                    }
                    .padding()
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAddMeasurement = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.leanBlue)
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showAddMeasurement) {
                AddMeasurementView(profile: profile)
            }
        }
    }

    // MARK: - Overall Progress

    private var overallProgressCard: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Your Journey")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("Started \(profile.startDate.dateFormatted)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 20) {
                ProgressStat(
                    label: "Start",
                    value: profile.startWeightKg.kgFormatted,
                    color: .secondary
                )

                // Progress bar
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.leanGray.opacity(0.3)).frame(height: 8)
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [.leanOrange, .leanGreen],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .frame(width: geo.size.width * profile.progressPercent, height: 8)
                                .animation(.spring(duration: 0.8), value: profile.progressPercent)
                        }
                    }
                    .frame(height: 8)
                    Text("\(Int(profile.progressPercent * 100))% complete")
                        .font(.caption2)
                        .foregroundColor(.leanGreen)
                }

                ProgressStat(
                    label: "Goal",
                    value: profile.targetWeightKg.kgFormatted,
                    color: .leanGreen
                )
            }

            Divider().background(Color.leanGray.opacity(0.3))

            HStack {
                ProgressStat(label: "Lost", value: "\(String(format: "%.1f", profile.weightLostSoFarKg)) kg", color: .leanBlue)
                ProgressStat(label: "Remaining", value: "\(String(format: "%.1f", max(profile.currentWeightKg - profile.targetWeightKg, 0))) kg", color: .leanOrange)
                ProgressStat(label: "Est. weeks left", value: "\(profile.estimatedWeeksToGoal)", color: .leanYellow)
            }
        }
        .cardStyle()
    }

    // MARK: - Time Range Picker

    private var timeRangePicker: some View {
        HStack(spacing: 0) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button(action: { withAnimation { timeRange = range } }) {
                    Text(range.rawValue)
                        .font(.subheadline)
                        .fontWeight(timeRange == range ? .semibold : .regular)
                        .foregroundColor(timeRange == range ? .black : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(timeRange == range ? Color.leanBlue : Color.clear)
                        .cornerRadius(8)
                }
            }
        }
        .padding(4)
        .background(Color.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Weight Chart

    @ViewBuilder
    private var weightChartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Weight")
                .font(.headline)
                .foregroundColor(.white)

            if weightDataPoints.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Log your weight daily to see your trend")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 140)
            } else {
                Chart {
                    // Target weight rule
                    RuleMark(y: .value("Target", profile.targetWeightKg))
                        .foregroundStyle(Color.leanGreen.opacity(0.5))
                        .lineStyle(StrokeStyle(dash: [5, 3]))
                        .annotation(position: .trailing) {
                            Text("Goal")
                                .font(.caption2)
                                .foregroundColor(.leanGreen)
                        }

                    ForEach(weightDataPoints, id: \.date) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", point.weight)
                        )
                        .foregroundStyle(Color.leanBlue)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", point.weight)
                        )
                        .foregroundStyle(Color.leanBlue.gradient.opacity(0.2))
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", point.weight)
                        )
                        .foregroundStyle(Color.leanBlue)
                        .symbolSize(20)
                    }
                }
                .frame(height: 160)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: timeRange == .week ? 1 : 7)) { value in
                        AxisValueLabel(
                            format: timeRange == .week ? .dateTime.weekday(.abbreviated) : .dateTime.month(.abbreviated).day()
                        )
                        .foregroundStyle(Color.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                            .foregroundStyle(Color.secondary)
                        AxisGridLine()
                            .foregroundStyle(Color.leanGray.opacity(0.2))
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Stats Summary

    private var statsSummaryCard: some View {
        let measurements = filteredMeasurements
        let first = measurements.first
        let last = measurements.last
        let change = (last?.weightKg ?? 0) - (first?.weightKg ?? 0)

        return VStack(spacing: 12) {
            HStack {
                Text("Stats (\(timeRange.rawValue))")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }

            HStack {
                StatCard(
                    icon: "scalemass.fill",
                    color: .leanBlue,
                    label: "Current",
                    value: profile.currentWeightKg.kgFormatted,
                    subtitle: ""
                )
                StatCard(
                    icon: "arrow.down.circle.fill",
                    color: change <= 0 ? .leanGreen : .leanRed,
                    label: "Change",
                    value: "\(change <= 0 ? "-" : "+")\(String(format: "%.1f", abs(change))) kg",
                    subtitle: ""
                )
                StatCard(
                    icon: "flame.fill",
                    color: .leanOrange,
                    label: "Avg. Burn",
                    value: avgDailyBurn,
                    subtitle: "kcal/day"
                )
            }
        }
        .cardStyle()
    }

    private var avgDailyBurn: String {
        let logs = profile.dailyLogs.filter { $0.date >= Date().daysAgo(timeRange.days) }
        guard !logs.isEmpty else { return "—" }
        let avg = logs.map(\.totalCaloriesBurned).reduce(0, +) / Double(logs.count)
        return "\(Int(avg))"
    }

    // MARK: - Measurements Log

    private var measurementsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Measurements")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button(action: { showAddMeasurement = true }) {
                    Label("Add", systemImage: "plus")
                        .font(.caption)
                        .foregroundColor(.leanBlue)
                }
            }

            if filteredMeasurements.isEmpty {
                Text("No measurements logged yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(filteredMeasurements.reversed()) { measurement in
                    MeasurementRow(measurement: measurement)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Weekly Recap

    private var weeklyRecapCard: some View {
        let logs7 = profile.dailyLogs.filter { $0.date >= Date().daysAgo(7) }
        let summary = NutritionCalculator.weeklySummary(
            logs: logs7,
            calorieTarget: profile.dailyCalorieTarget,
            proteinTarget: profile.dailyProteinGrams
        )

        return VStack(alignment: .leading, spacing: 12) {
            Text("Last 7 Days")
                .font(.headline)
                .foregroundColor(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                RecapStat(label: "Avg Calories", value: "\(Int(summary.avgCaloriesConsumed))", unit: "kcal", target: "\(Int(profile.dailyCalorieTarget))")
                RecapStat(label: "Avg Protein", value: "\(Int(summary.avgProteinG))", unit: "g", target: "\(Int(profile.dailyProteinGrams))")
                RecapStat(label: "Workouts", value: "\(summary.workoutsCompleted)", unit: "", target: "")
                RecapStat(label: "Days on Track", value: "\(summary.daysOnTrack)", unit: "/7", target: "")
            }

            // Calorie adherence bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Calorie Adherence")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(summary.calorieAdherencePercent))%")
                        .font(.caption.bold())
                        .foregroundColor(summary.calorieAdherencePercent <= 100 ? .leanGreen : .leanRed)
                }
                ProgressBarView(
                    value: min(summary.calorieAdherencePercent / 100, 1.2),
                    color: summary.calorieAdherencePercent <= 105 ? .leanGreen : .leanRed
                )
            }

            // Protein adherence bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Protein Adherence")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(summary.proteinAdherencePercent))%")
                        .font(.caption.bold())
                        .foregroundColor(summary.proteinAdherencePercent >= 85 ? .leanGreen : .leanOrange)
                }
                ProgressBarView(
                    value: min(summary.proteinAdherencePercent / 100, 1.2),
                    color: summary.proteinAdherencePercent >= 85 ? .leanGreen : .leanOrange
                )
            }
        }
        .cardStyle()
    }
}

// MARK: - Add Measurement View

struct AddMeasurementView: View {
    let profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var weightKg: Double = 0
    @State private var waistCm: String = ""
    @State private var chestCm: String = ""
    @State private var hipsCm: String = ""
    @State private var neckCm: String = ""
    @State private var armCm: String = ""
    @State private var bodyFat: String = ""
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                Form {
                    Section("Weight (required)") {
                        HStack {
                            TextField("84.2", value: $weightKg, format: .number)
                                .keyboardType(.decimalPad)
                            Text("kg")
                                .foregroundColor(.secondary)
                        }
                    }

                    Section("Body Measurements (optional, cm)") {
                        MeasurementField(label: "Waist", value: $waistCm)
                        MeasurementField(label: "Chest", value: $chestCm)
                        MeasurementField(label: "Hips", value: $hipsCm)
                        MeasurementField(label: "Neck", value: $neckCm)
                        MeasurementField(label: "Arm", value: $armCm)
                    }

                    Section("Body Fat % (optional)") {
                        HStack {
                            TextField("e.g. 22", text: $bodyFat)
                                .keyboardType(.decimalPad)
                            Text("%")
                                .foregroundColor(.secondary)
                        }
                        Text("From smart scale or Navy formula")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Section("Notes") {
                        TextField("How are you feeling?", text: $notes)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.appBackground)
            }
            .navigationTitle("Log Measurement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") { saveMeasurement() }
                        .fontWeight(.semibold)
                        .disabled(weightKg <= 0)
                }
            }
            .onAppear {
                weightKg = profile.currentWeightKg
            }
        }
    }

    private func saveMeasurement() {
        let measurement = BodyMeasurement(
            weightKg: weightKg,
            waistCm: Double(waistCm),
            chestCm: Double(chestCm),
            hipsCm: Double(hipsCm),
            neckCm: Double(neckCm),
            leftArmCm: Double(armCm),
            bodyFatPercentage: Double(bodyFat),
            notes: notes
        )
        profile.measurements.append(measurement)
        profile.currentWeightKg = weightKg
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Supporting Views

struct MeasurementRow: View {
    let measurement: BodyMeasurement

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(measurement.date.dateFormatted)
                    .font(.subheadline)
                    .foregroundColor(.white)
                HStack(spacing: 8) {
                    if let w = measurement.waistCm { Text("W: \(w.zeroDecimals)cm").font(.caption).foregroundColor(.secondary) }
                    if let c = measurement.chestCm { Text("C: \(c.zeroDecimals)cm").font(.caption).foregroundColor(.secondary) }
                    if let bf = measurement.bodyFatPercentage { Text("BF: \(bf.oneDecimal)%").font(.caption).foregroundColor(.leanOrange) }
                }
            }
            Spacer()
            Text(measurement.weightKg.kgFormatted)
                .font(.headline)
                .foregroundColor(.leanBlue)
        }
    }
}

struct ProgressStat: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.callout, design: .rounded).bold())
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct RecapStat: View {
    let label: String
    let value: String
    let unit: String
    let target: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundColor(.white)
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if !target.isEmpty {
                Text("target: \(target)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appBackground.opacity(0.5))
        .cornerRadius(10)
    }
}

struct ProgressBarView: View {
    let value: Double   // 0.0 to 1.0+
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.2)).frame(height: 8)
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * min(value, 1.0), height: 8)
                    .animation(.spring(duration: 0.6), value: value)
            }
        }
        .frame(height: 8)
    }
}

struct MeasurementField: View {
    let label: String
    @Binding var value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("—", text: $value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text("cm")
                .foregroundColor(.secondary)
        }
    }
}
