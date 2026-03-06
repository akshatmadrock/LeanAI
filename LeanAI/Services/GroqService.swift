import Foundation

// MARK: - Response types

struct ParsedFoodItem: Codable {
    let name: String
    let calories: Double
    let protein_g: Double
    let carbs_g: Double
    let fat_g: Double
    let fiber_g: Double
    let serving_size: String?
}

struct FoodParseResponse: Codable {
    let items: [ParsedFoodItem]
    let total_calories: Double?
    let total_protein_g: Double?
    let total_carbs_g: Double?
    let total_fat_g: Double?
}

struct ActivityEstimateResponse: Codable {
    let activity_name: String
    let met: Double
    let calories_burned: Double
    let reasoning: String
    let duration_minutes: Double
}

struct AdvisorResponse: Codable {
    let summary: String
    let calorie_adjustment: String          // "maintain" | "reduce_100" | "reduce_200"
    let protein_note: String
    let key_advice: [String]
    let muscle_risk: String                 // "low" | "medium" | "high"
}

// MARK: - GroqService

@MainActor
final class GroqService: ObservableObject {
    private let baseURL = "https://api.groq.com/openai/v1/chat/completions"
    private let model = "llama-3.3-70b-versatile"

    /// nil = no call made yet; true = last call succeeded; false = last call failed
    @Published var lastCallSucceeded: Bool? = nil
    @Published var isLoading = false
    @Published var lastError: String?

    // MARK: - Food Parser

    /// Parse a plain-English food description into structured nutritional data.
    /// Example: "2 scrambled eggs, 1 slice whole wheat toast with butter, black coffee"
    func parseFoodDescription(
        _ description: String,
        apiKey: String,
        mealType: String = "meal"
    ) async throws -> FoodParseResponse {
        isLoading = true
        defer { isLoading = false }

        let systemPrompt = """
        You are a precise nutrition database expert. The user will describe what they ate.
        You MUST return a JSON object with this exact structure:
        {
          "items": [
            {
              "name": "item name",
              "calories": 123,
              "protein_g": 10.5,
              "carbs_g": 20.0,
              "fat_g": 5.0,
              "fiber_g": 2.0,
              "serving_size": "description of serving"
            }
          ],
          "total_calories": 123,
          "total_protein_g": 10.5,
          "total_carbs_g": 20.0,
          "total_fat_g": 5.0
        }

        Rules:
        - Use standard nutritional reference values (USDA database quality)
        - Be conservative — when uncertain, use the LOWER end of calorie estimates
        - Always return at least one item
        - All numeric values must be positive numbers
        - Be specific with serving sizes
        - Never return null for numeric fields — use 0 if truly unknown
        """

        let userMessage = "I ate this as my \(mealType): \(description)"

        let response = try await callGroq(
            systemPrompt: systemPrompt,
            userMessage: userMessage,
            apiKey: apiKey
        )

        guard let data = response.data(using: .utf8) else {
            throw GroqError.invalidResponse("Could not decode response string")
        }

        let decoded = try JSONDecoder().decode(FoodParseResponse.self, from: data)
        return decoded
    }

    // MARK: - Activity Calorie Estimator

    /// Estimate calories burned for any activity using AI + MET science
    func estimateActivityCalories(
        activityDescription: String,
        durationMinutes: Double,
        bodyWeightKg: Double,
        apiKey: String
    ) async throws -> ActivityEstimateResponse {
        isLoading = true
        defer { isLoading = false }

        let systemPrompt = """
        You are an exercise science expert specializing in metabolic equivalent (MET) calculations.
        Given an activity description, duration, and body weight, calculate calories burned.

        Formula: Calories = MET × body_weight_kg × (duration_minutes / 60)

        Return ONLY this JSON structure:
        {
          "activity_name": "cleaned activity name",
          "met": 6.5,
          "calories_burned": 342.5,
          "reasoning": "brief explanation of MET choice",
          "duration_minutes": 45
        }

        Rules:
        - Use published MET values from the Compendium of Physical Activities
        - Be conservative — when between two MET values, use the LOWER one
        - Common MET ranges: walking 2.5-4.5, running 8-12, cycling 4-10, pickleball 4.5-8, weightlifting 2.5-5.5
        - All numeric values must be positive numbers
        """

        let userMessage = """
        Activity: \(activityDescription)
        Duration: \(Int(durationMinutes)) minutes
        Body weight: \(String(format: "%.1f", bodyWeightKg)) kg
        """

        let response = try await callGroq(
            systemPrompt: systemPrompt,
            userMessage: userMessage,
            apiKey: apiKey
        )

        guard let data = response.data(using: .utf8) else {
            throw GroqError.invalidResponse("Could not decode response string")
        }

        return try JSONDecoder().decode(ActivityEstimateResponse.self, from: data)
    }

    // MARK: - Weekly Advisor

    /// Generate adaptive weekly advice based on the last 7 days of data
    func getWeeklyAdvice(
        userName: String,
        avgCaloriesConsumed: Double,
        avgProteinG: Double,
        calorieTarget: Double,
        proteinTarget: Double,
        weightChangeKg: Double,       // negative = lost weight (good)
        workoutsCompleted: Int,
        currentWeightKg: Double,
        targetWeightKg: Double,
        apiKey: String
    ) async throws -> AdvisorResponse {
        isLoading = true
        defer { isLoading = false }

        let systemPrompt = """
        You are a conservative, science-backed fat loss and muscle preservation coach.
        Analyze the user's last 7 days of data and give actionable advice.

        Philosophy:
        - Prioritize muscle preservation above all — losing muscle is BAD
        - A 500 kcal/day deficit is the sweet spot; going more aggressive risks muscle
        - Protein MUST be at least 85% of target to preserve muscle during a deficit
        - If weight is NOT decreasing: reduce carbs slightly, not protein or total calories drastically
        - If strength is declining: reduce deficit by 100-200 kcal, increase protein

        Return ONLY this JSON structure:
        {
          "summary": "2-3 sentence summary of the week",
          "calorie_adjustment": "maintain",
          "protein_note": "advice about protein intake",
          "key_advice": ["tip 1", "tip 2", "tip 3"],
          "muscle_risk": "low"
        }

        calorie_adjustment must be exactly one of: "maintain", "reduce_100", "reduce_200", "increase_100"
        muscle_risk must be exactly one of: "low", "medium", "high"
        key_advice must be an array of 2-4 short, specific actionable tips
        """

        let weightStatus = weightChangeKg < 0
            ? "Lost \(String(format: "%.1f", abs(weightChangeKg))) kg"
            : weightChangeKg > 0
                ? "Gained \(String(format: "%.1f", weightChangeKg)) kg"
                : "Weight unchanged"

        let userMessage = """
        User: \(userName)
        Current weight: \(String(format: "%.1f", currentWeightKg)) kg
        Target weight: \(String(format: "%.1f", targetWeightKg)) kg
        Remaining to lose: \(String(format: "%.1f", max(currentWeightKg - targetWeightKg, 0))) kg

        Last 7 days:
        - Avg calories consumed: \(Int(avgCaloriesConsumed)) kcal (target: \(Int(calorieTarget)) kcal)
        - Avg protein: \(Int(avgProteinG)) g (target: \(Int(proteinTarget)) g)
        - Weight change: \(weightStatus)
        - Workouts completed: \(workoutsCompleted)

        Protein adherence: \(Int((avgProteinG / proteinTarget) * 100))%
        Calorie adherence: \(Int((avgCaloriesConsumed / calorieTarget) * 100))%
        """

        let response = try await callGroq(
            systemPrompt: systemPrompt,
            userMessage: userMessage,
            apiKey: apiKey
        )

        guard let data = response.data(using: .utf8) else {
            throw GroqError.invalidResponse("Could not decode response string")
        }

        return try JSONDecoder().decode(AdvisorResponse.self, from: data)
    }

    // MARK: - Core API call

    private func callGroq(
        systemPrompt: String,
        userMessage: String,
        apiKey: String
    ) async throws -> String {
        // Default to failure; success path overrides before return
        lastCallSucceeded = false
        UserDefaults.standard.set(false, forKey: "aiLastCallSucceeded")

        // Use provided key, fall back to bundled default
        let resolvedKey = apiKey.isEmpty ? Constants.defaultGroqAPIKey : apiKey
        guard !resolvedKey.isEmpty else {
            throw GroqError.missingAPIKey
        }

        guard let url = URL(string: baseURL) else {
            throw GroqError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(resolvedKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userMessage]
            ],
            "response_format": ["type": "json_object"],
            "temperature": 0.1,         // low temp for more consistent structured output
            "max_tokens": 1024
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GroqError.invalidResponse("Non-HTTP response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            if httpResponse.statusCode == 401 {
                throw GroqError.invalidAPIKey
            }
            throw GroqError.apiError("HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        // Extract the content from the OpenAI-compatible response format
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw GroqError.invalidResponse("Unexpected response structure")
        }

        lastError = nil
        lastCallSucceeded = true
        // Persist status for display across views
        UserDefaults.standard.set(true, forKey: "aiLastCallSucceeded")
        return content
    }
}

// MARK: - Errors

enum GroqError: LocalizedError {
    case missingAPIKey
    case invalidAPIKey
    case invalidURL
    case invalidResponse(String)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Please add your Groq API key in Settings."
        case .invalidAPIKey:
            return "Invalid Groq API key. Check your key in Settings."
        case .invalidURL:
            return "Invalid API URL configuration."
        case .invalidResponse(let msg):
            return "AI returned an unexpected response: \(msg)"
        case .apiError(let msg):
            return "API error: \(msg)"
        }
    }
}
