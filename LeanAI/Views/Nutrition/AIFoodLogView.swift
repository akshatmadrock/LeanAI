import SwiftUI
import SwiftData

struct AIFoodLogView: View {
    let profile: UserProfile
    let todayLog: DailyLog
    let initialMealType: String
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @StateObject private var groq = GroqService()
    @State private var inputText = ""
    @State private var selectedMealType: String
    @State private var parsedItems: [ParsedFoodItem] = []
    @State private var showParsed = false
    @State private var errorMessage: String?
    @State private var editingCalories: [String] = []

    init(profile: UserProfile, todayLog: DailyLog, initialMealType: String, onDismiss: @escaping () -> Void) {
        self.profile = profile
        self.todayLog = todayLog
        self.initialMealType = initialMealType
        self.onDismiss = onDismiss
        _selectedMealType = State(initialValue: initialMealType)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Meal type picker
                        mealTypePicker

                        // AI input area
                        aiInputSection

                        // Parse button
                        if !inputText.isEmpty && !showParsed {
                            parseButton
                        }

                        // Parsed results
                        if showParsed && !parsedItems.isEmpty {
                            parsedResultsSection
                        }

                        // Error
                        if let error = errorMessage {
                            ErrorBanner(message: error)
                        }

                        // Example prompts
                        if !showParsed && !groq.isLoading {
                            examplePromptsSection
                        }
                    }
                    .padding()
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Log Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
                if showParsed && !parsedItems.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Add All") {
                            saveAllItems()
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.leanGreen)
                    }
                }
            }
        }
    }

    // MARK: - Meal Type Picker

    private var mealTypePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Constants.mealTypes, id: \.self) { type in
                    Button(action: { selectedMealType = type }) {
                        Text(Constants.mealTypeLabel(type))
                            .font(.subheadline)
                            .fontWeight(selectedMealType == type ? .semibold : .regular)
                            .foregroundColor(selectedMealType == type ? .black : .secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedMealType == type ? Color.leanGreen : Color.cardBackground)
                            .cornerRadius(20)
                    }
                }
            }
        }
    }

    // MARK: - AI Input

    private var aiInputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("What did you eat?", systemImage: "brain.head.profile")
                .font(.headline)
                .foregroundColor(.leanBlue)

            ZStack(alignment: .topLeading) {
                if inputText.isEmpty {
                    Text("e.g. 2 scrambled eggs, 1 slice whole wheat toast with butter, black coffee")
                        .font(.body)
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }

                TextEditor(text: $inputText)
                    .font(.body)
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 100, maxHeight: 160)
            }
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(14)

            Text("AI will look up calories and macros from nutritional databases")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Parse Button

    private var parseButton: some View {
        Button(action: parseFood) {
            HStack {
                if groq.isLoading {
                    ProgressView()
                        .tint(.black)
                        .padding(.trailing, 4)
                    Text("Analyzing...")
                } else {
                    Image(systemName: "sparkles")
                    Text("Analyze with AI")
                }
            }
            .font(.headline)
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding()
            .background(profile.groqAPIKey.isEmpty ? Color.leanGray : Color.leanGreen)
            .cornerRadius(14)
        }
        .disabled(groq.isLoading || profile.groqAPIKey.isEmpty)
        .overlay {
            if profile.groqAPIKey.isEmpty {
                VStack {
                    Spacer()
                    Text("Add Groq API key in Settings to enable AI")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 56)
                }
            }
        }
    }

    // MARK: - Parsed Results

    private var parsedResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Parsed Items")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button(action: { showParsed = false; inputText = "" }) {
                    Text("Edit")
                        .font(.caption)
                        .foregroundColor(.leanBlue)
                }
            }

            ForEach(parsedItems.indices, id: \.self) { i in
                ParsedFoodItemRow(
                    item: parsedItems[i],
                    onAdd: {
                        saveItem(parsedItems[i])
                    }
                )
            }

            // Totals
            Divider().background(Color.leanGray.opacity(0.3))

            let totalCal = parsedItems.reduce(0.0) { $0 + $1.calories }
            let totalProt = parsedItems.reduce(0.0) { $0 + $1.protein_g }
            let totalCarbs = parsedItems.reduce(0.0) { $0 + $1.carbs_g }
            let totalFat = parsedItems.reduce(0.0) { $0 + $1.fat_g }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    HStack(spacing: 8) {
                        Text("P: \(Int(totalProt))g").foregroundColor(.leanOrange).font(.caption)
                        Text("C: \(Int(totalCarbs))g").foregroundColor(.leanPurple).font(.caption)
                        Text("F: \(Int(totalFat))g").foregroundColor(.leanYellow).font(.caption)
                    }
                }
                Spacer()
                Text("\(Int(totalCal)) kcal")
                    .font(.title3.bold())
                    .foregroundColor(.leanBlue)
            }

            Button(action: saveAllItems) {
                Text("Add All to \(Constants.mealTypeLabel(selectedMealType))")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.leanGreen)
                    .cornerRadius(14)
            }
        }
        .cardStyle()
    }

    // MARK: - Examples

    private var examplePromptsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Examples")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            ForEach(examplePrompts, id: \.self) { example in
                Button(action: { inputText = example }) {
                    HStack {
                        Text(example)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "arrow.up.left")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.cardBackground)
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
            }
        }
    }

    private let examplePrompts = [
        "2 scrambled eggs with cheese, 2 slices multigrain toast, black coffee",
        "Grilled chicken breast 200g with brown rice 150g and broccoli",
        "Greek yogurt 150g, handful of almonds, 1 banana",
        "Protein shake with 2 scoops whey protein and almond milk",
        "Dal makhani 1 bowl, 2 chapatis, salad"
    ]

    // MARK: - Actions

    private func parseFood() {
        guard !inputText.isEmpty else { return }
        errorMessage = nil

        Task {
            do {
                let result = try await groq.parseFoodDescription(
                    inputText,
                    apiKey: profile.groqAPIKey,
                    mealType: selectedMealType
                )
                parsedItems = result.items
                showParsed = true
            } catch let error as GroqError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func saveItem(_ item: ParsedFoodItem) {
        let entry = FoodEntry(
            name: item.name,
            calories: item.calories,
            proteinG: item.protein_g,
            carbsG: item.carbs_g,
            fatG: item.fat_g,
            fiberG: item.fiber_g,
            mealType: selectedMealType,
            rawDescription: inputText,
            servingSize: item.serving_size ?? ""
        )
        todayLog.foodEntries.append(entry)
        try? modelContext.save()
    }

    private func saveAllItems() {
        parsedItems.forEach { saveItem($0) }
        onDismiss()
    }
}

// MARK: - Parsed Food Item Row

struct ParsedFoodItemRow: View {
    let item: ParsedFoodItem
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline)
                    .foregroundColor(.white)
                if let serving = item.serving_size, !serving.isEmpty {
                    Text(serving)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 8) {
                    MacroPill(label: "P", value: item.protein_g, color: .leanOrange)
                    MacroPill(label: "C", value: item.carbs_g, color: .leanPurple)
                    MacroPill(label: "F", value: item.fat_g, color: .leanYellow)
                }
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text("\(Int(item.calories))")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("kcal")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.appBackground.opacity(0.6))
        .cornerRadius(10)
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.leanRed)
            Text(message)
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.leanRed.opacity(0.15))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.leanRed.opacity(0.3), lineWidth: 1)
        )
    }
}
