import SwiftUI
import SwiftData

// MARK: - StatCard
// A compact stat tile used in DashboardView, ProgressView, etc.

struct StatCard: View {
    let icon: String
    let color: Color
    let label: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.headline.bold())
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - ActivityStat
// Three-column stat used inside the Activity summary card.

struct ActivityStat: View {
    let icon: String
    let color: Color
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.title3.bold())
                .foregroundColor(.white)
            if !unit.isEmpty {
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - WeeklyStat
// A small label+value stack used in the activity weekly chart card.

struct WeeklyStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - PartnerStat
// A three-column stat used in the partner summary card.

struct PartnerStat: View {
    let label: String
    let value: String
    let target: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.headline.bold())
                .foregroundColor(.white)
            Text("/ \(target)")
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(label)
                .font(.caption2)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - MacroBar
// A horizontal progress bar row used in NutritionView.

struct MacroBar: View {
    let label: String
    let consumed: Double
    let target: Double
    let color: Color
    let unit: String

    private var progress: Double { min(consumed / max(target, 1), 1.2) }
    private var isOver: Bool { consumed > target * 1.05 }

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.white)
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

// MARK: - ActivityEntryRow
// A single row representing one logged workout/activity. Used in Dashboard and Activity tabs.

struct ActivityEntryRow: View {
    let entry: ActivityEntry
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Image(systemName: activityIcon(entry.activityName))
                .foregroundColor(.leanOrange)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.activityName)
                    .foregroundColor(.white)
                    .font(.subheadline)
                Text("\(Int(entry.durationMinutes)) min · \(intensityLabel(entry.intensityLevel))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("≈ \(Int(entry.caloriesBurned)) kcal")
                .font(.caption)
                .foregroundColor(.leanOrange)
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
    }

    private func activityIcon(_ name: String) -> String {
        let n = name.lowercased()
        if n.contains("run") { return "figure.run" }
        if n.contains("walk") { return "figure.walk" }
        if n.contains("cycle") || n.contains("bike") { return "figure.outdoor.cycle" }
        if n.contains("swim") { return "figure.pool.swim" }
        if n.contains("lift") || n.contains("weight") { return "dumbbell.fill" }
        if n.contains("pickleball") { return "tennis.racket" }
        if n.contains("yoga") { return "figure.mind.and.body" }
        return "figure.strengthtraining.traditional"
    }

    private func intensityLabel(_ level: Int) -> String {
        switch level {
        case 0: return "Light"
        case 1: return "Moderate"
        case 2: return "Intense"
        default: return "Moderate"
        }
    }
}

// MARK: - WeightEntrySheet
// A sheet for logging or updating today's morning weight.

struct WeightEntrySheet: View {
    @Binding var todayWeight: String
    let profile: UserProfile
    let log: DailyLog
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "scalemass.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.leanBlue)
                        Text("Log Your Weight")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        Text("Logging your weight keeps your calorie targets accurate as you lose weight")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 32)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        TextField("e.g. 82.5", text: $todayWeight)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .keyboardType(.decimalPad)
                            .foregroundColor(.white)
                            .focused($isFocused)
                        Text("kg")
                            .font(.title2.bold())
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.cardBackground)
                    .cornerRadius(16)
                    .padding(.horizontal)

                    if let last = log.morningWeightKg {
                        Text("Last logged: \(last.kgFormatted)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button(action: {
                        onSave()
                        dismiss()
                    }) {
                        Text("Save Weight")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(todayWeight.isEmpty ? Color.leanGray : Color.leanBlue)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal)
                    .disabled(todayWeight.isEmpty)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if let w = log.morningWeightKg {
                    todayWeight = String(format: "%.1f", w)
                }
                isFocused = true
            }
        }
    }
}
