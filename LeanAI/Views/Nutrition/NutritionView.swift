import SwiftUI
import SwiftData

struct NutritionView: View {
    let profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    @State private var showAILogger = false
    @State private var selectedMealType = "breakfast"

    private var todayLog: DailyLog {
        getOrCreateTodayLog()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Daily summary header
                        dailySummaryCard

                        // Meal sections
                        ForEach(Constants.mealTypes, id: \.self) { mealType in
                            MealSection(
                                mealType: mealType,
                                entries: todayLog.foodEntries.filter { $0.mealType == mealType },
                                onAddTapped: {
                                    selectedMealType = mealType
                                    showAILogger = true
                                },
                                onDelete: { entry in deleteEntry(entry) }
                            )
                        }
                    }
                    .padding()
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Nutrition")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAILogger = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.leanGreen)
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showAILogger) {
                AIFoodLogView(
                    profile: profile,
                    todayLog: todayLog,
                    initialMealType: selectedMealType,
                    onDismiss: { showAILogger = false }
                )
            }
        }
    }

    // MARK: - Daily Summary

    private var dailySummaryCard: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Today's Intake")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text(Date().dateFormatted)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Calorie summary
            HStack(spacing: 0) {
                CalorieStat(label: "Eaten", value: todayLog.totalCaloriesConsumed.kcalFormatted, color: .leanBlue)
                Divider().frame(height: 40).background(Color.leanGray.opacity(0.3))
                CalorieStat(label: "Target", value: profile.dailyCalorieTarget.kcalFormatted, color: .white)
                Divider().frame(height: 40).background(Color.leanGray.opacity(0.3))
                CalorieStat(
                    label: todayLog.totalCaloriesConsumed <= profile.dailyCalorieTarget ? "Remaining" : "Over",
                    value: abs(profile.dailyCalorieTarget - todayLog.totalCaloriesConsumed).kcalFormatted,
                    color: todayLog.totalCaloriesConsumed <= profile.dailyCalorieTarget ? .leanGreen : .leanRed
                )
            }

            // Macro bars
            MacroBar(label: "Protein", consumed: todayLog.totalProteinG, target: profile.dailyProteinGrams, color: .leanOrange, unit: "g")
            MacroBar(label: "Carbs", consumed: todayLog.totalCarbsG, target: profile.dailyCarbsGrams, color: .leanPurple, unit: "g")
            MacroBar(label: "Fat", consumed: todayLog.totalFatG, target: profile.dailyFatGrams, color: .leanYellow, unit: "g")
        }
        .cardStyle()
    }

    // MARK: - Helpers

    private func getOrCreateTodayLog() -> DailyLog {
        let today = Calendar.current.startOfDay(for: Date())
        if let existing = profile.dailyLogs.first(where: {
            Calendar.current.isDate($0.date, inSameDayAs: today)
        }) {
            return existing
        }
        let log = DailyLog(date: today)
        profile.dailyLogs.append(log)
        try? modelContext.save()
        return log
    }

    private func deleteEntry(_ entry: FoodEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
    }
}

// MARK: - Meal Section

struct MealSection: View {
    let mealType: String
    let entries: [FoodEntry]
    let onAddTapped: () -> Void
    let onDelete: (FoodEntry) -> Void

    private var mealTotalCalories: Double {
        entries.reduce(0) { $0 + $1.calories }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Image(systemName: mealTypeIcon(mealType))
                    .foregroundColor(.leanBlue)
                Text(Constants.mealTypeLabel(mealType))
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if mealTotalCalories > 0 {
                    Text("\(Int(mealTotalCalories)) kcal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Button(action: onAddTapped) {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.leanGreen)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color.cardBackground)
            .cornerRadius(12, corners: entries.isEmpty ? .allCorners : [.topLeft, .topRight])

            // Food entries
            ForEach(entries) { entry in
                FoodEntryRow(entry: entry, onDelete: { onDelete(entry) })

                if entry.id != entries.last?.id {
                    Divider()
                        .background(Color.leanGray.opacity(0.3))
                        .padding(.leading, 52)
                }
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(12)
    }

    private func mealTypeIcon(_ type: String) -> String {
        switch type {
        case "breakfast": return "sunrise.fill"
        case "lunch": return "sun.max.fill"
        case "dinner": return "moon.fill"
        case "snack": return "apple.logo"
        default: return "fork.knife"
        }
    }
}

// MARK: - Food Entry Row

struct FoodEntryRow: View {
    let entry: FoodEntry
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.subheadline)
                    .foregroundColor(.white)
                if !entry.servingSize.isEmpty {
                    Text(entry.servingSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 8) {
                    MacroPill(label: "P", value: entry.proteinG, color: .leanOrange)
                    MacroPill(label: "C", value: entry.carbsG, color: .leanPurple)
                    MacroPill(label: "F", value: entry.fatG, color: .leanYellow)
                }
            }

            Spacer()

            Text("\(Int(entry.calories))")
                .font(.headline)
                .foregroundColor(.white)
            Text("kcal")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Helpers

struct CalorieStat: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded).bold())
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MacroPill: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(color)
            Text("\(Int(value))g")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Corner radius helper

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
