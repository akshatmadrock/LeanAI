// LeanAI
// GroqService.swift
//
// All communication with the Groq API (LLaMA 3.3 70B text + LLaMA 4 Scout vision).
// Author: Akshat Gupta

import Foundation

// MARK: - Response Types

/// Structured representation of a single parsed food item returned by the AI.
struct ParsedFoodItem: Codable {
    var name: String
    var calories: Double
    var protein_g: Double
    var carbs_g: Double
    var fat_g: Double
    var fiber_g: Double
    /// Human-readable serving size (e.g. "1 cup ~150g", "2 pieces").
    var serving_size: String?
    /// Meal type string — present only in full-day parse mode ("breakfast", "lunch", etc.).
    var meal_type: String?
}

/// Top-level response for food parsing requests. Contains individual items and optional totals.
struct FoodParseResponse: Codable {
    let items: [ParsedFoodItem]
    let total_calories: Double?
    let total_protein_g: Double?
    let total_carbs_g: Double?
    let total_fat_g: Double?
}

/// Response for activity calorie estimation. Includes MET value and AI reasoning.
struct ActivityEstimateResponse: Codable {
    let activity_name: String
    /// Metabolic Equivalent of Task value used for the calculation.
    let met: Double
    let calories_burned: Double
    /// Brief explanation of why this MET value was chosen.
    let reasoning: String
    let duration_minutes: Double
}

/// Response from the weekly advisor prompt. Drives the adaptive coaching UI.
struct AdvisorResponse: Codable {
    let summary: String
    /// One of: "maintain" | "reduce_100" | "reduce_200" | "increase_100".
    let calorie_adjustment: String
    let protein_note: String
    let key_advice: [String]
    /// Muscle-loss risk assessment: "low" | "medium" | "high".
    let muscle_risk: String
}

// MARK: - GroqService

/// The central AI service. Wraps all Groq API calls behind async throwing functions.
///
/// Two underlying transport methods handle all requests:
/// - `rawTextCall` — sends a system + user message to LLaMA 3.3 70B and returns JSON string.
/// - `rawVisionCall` — sends a base64 image to LLaMA 4 Scout vision and returns a text description.
///
/// Public methods (`parseFoodDescription`, `parseDayDescription`, `estimateActivityCalories`,
/// `getWeeklyAdvice`, `parseFoodFromPhoto`) manage `isLoading` and `lastCallSucceeded` state
/// for SwiftUI binding.
@MainActor
final class GroqService: ObservableObject {

    private let baseURL = "https://api.groq.com/openai/v1/chat/completions"

    /// Text model used for all non-vision requests.
    private let model = "llama-3.3-70b-versatile"

    // MARK: - Published State

    /// nil = no call made yet; true = last call succeeded; false = last call failed.
    @Published var lastCallSucceeded: Bool? = nil

    /// True while any async API call is in flight.
    @Published var isLoading = false

    /// Human-readable error from the most recent failed call, or nil if last call succeeded.
    @Published var lastError: String?

    // MARK: - Food Parser (single meal)

    /// Parse a plain-English meal description into structured per-item nutritional data.
    ///
    /// The system prompt instructs the model to reason carefully about preparation method,
    /// portion size, added fats (ghee, oil, butter), cultural context, and brand information
    /// before estimating macros.
    ///
    /// - Parameters:
    ///   - description: Natural-language description e.g. "2 scrambled eggs, toast with butter".
    ///   - apiKey: User's Groq API key (falls back to `Constants.defaultGroqAPIKey` if empty).
    ///   - mealType: Meal label passed to the AI for context (e.g. "breakfast").
    /// - Returns: A `FoodParseResponse` with one item per distinct food.
    /// - Throws: `GroqError` on network failure, auth error, or malformed JSON.
    func parseFoodDescription(
        _ description: String,
        apiKey: String,
        mealType: String = "meal"
    ) async throws -> FoodParseResponse {
        isLoading = true
        defer { isLoading = false }

        let systemPrompt = """
        You are an expert nutritionist with deep knowledge of foods from all cuisines worldwide — including Indian, Mediterranean, Asian, Western, and more.

        The user will describe what they ate. Reason carefully about the EXACT food described — consider:
        - Preparation method (fried vs grilled vs boiled — this changes calories significantly)
        - Portion size (grams stated, or common serving sizes like "1 bowl", "1 plate", "1 cup")
        - Added ingredients (butter, oil, ghee, sauces, cheese)
        - Cultural context (e.g., Indian home cooking uses ghee; restaurant portions are larger)
        - Brand/restaurant context if mentioned

        Examples of accurate reasoning:
        - "2 chapatis" ≈ 140-160 kcal (each ~70g, mostly carbs)
        - "1 bowl dal makhani" ≈ 350-400 kcal (cream and butter make it calorie-dense)
        - "200g grilled chicken breast" ≈ 330 kcal, ~62g protein
        - "1 tablespoon ghee" ≈ 112 kcal, ~12.7g fat
        - "1 scoop whey protein in 250ml milk" ≈ 250-300 kcal, ~35g protein

        Do NOT use generic placeholder values. Reason about the actual food, then estimate.

        Return ONLY this JSON:
        {
          "items": [
            {
              "name": "specific food name",
              "calories": 123,
              "protein_g": 10.5,
              "carbs_g": 20.0,
              "fat_g": 5.0,
              "fiber_g": 2.0,
              "serving_size": "e.g. 200g / 1 bowl (~300ml) / 2 pieces"
            }
          ],
          "total_calories": 123,
          "total_protein_g": 10.5,
          "total_carbs_g": 20.0,
          "total_fat_g": 5.0
        }

        Rules:
        - Always return at least one item; split compound dishes into logical components
        - All numeric values must be positive numbers, never null
        - Be specific with serving sizes — always state approximate grams or volume
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

    // MARK: - Full Day Food Parser

    /// Parse an entire day's meals described in one free-text message.
    ///
    /// The AI uses time cues ("morning", "lunch", "evening") to assign the correct
    /// `meal_type` to each item. Returns a single `FoodParseResponse` covering all meals.
    ///
    /// - Parameters:
    ///   - description: Free-text description of everything eaten today.
    ///   - apiKey: User's Groq API key.
    /// - Returns: `FoodParseResponse` with meal_type populated on each item.
    /// - Throws: `GroqError` on failure.
    func parseDayDescription(
        _ description: String,
        apiKey: String
    ) async throws -> FoodParseResponse {
        isLoading = true
        defer { isLoading = false }

        let systemPrompt = """
        You are an expert nutritionist. The user will describe everything they ate today in one message.
        Parse each food item, estimate its nutritional content accurately, and assign it to the correct meal type.

        Meal types (use exactly these strings): breakfast, lunch, dinner, snack

        Reason carefully about:
        - Preparation method and ingredients (fried vs grilled, added butter/oil/ghee, etc.)
        - Portion sizes from context ("1 bowl", "1 plate", "handful", stated grams)
        - Cultural/regional foods (Indian, Mediterranean, Asian, etc.)
        - Time cues in the text to assign the right meal type (morning = breakfast, midday = lunch, evening/night = dinner)

        Return ONLY this JSON:
        {
          "items": [
            {
              "name": "specific food name",
              "calories": 123,
              "protein_g": 10.5,
              "carbs_g": 20.0,
              "fat_g": 5.0,
              "fiber_g": 2.0,
              "serving_size": "e.g. 200g / 1 bowl (~300ml)",
              "meal_type": "breakfast"
            }
          ],
          "total_calories": 123,
          "total_protein_g": 10.5,
          "total_carbs_g": 20.0,
          "total_fat_g": 5.0
        }

        Rules:
        - meal_type must be one of: breakfast, lunch, dinner, snack
        - All numeric values must be positive, never null
        - Be specific with serving sizes
        - Split compound meals into individual items where logical
        """

        let userMessage = "Here's everything I ate today: \(description)"

        let response = try await callGroq(
            systemPrompt: systemPrompt,
            userMessage: userMessage,
            apiKey: apiKey
        )

        guard let data = response.data(using: .utf8) else {
            throw GroqError.invalidResponse("Could not decode response string")
        }

        return try JSONDecoder().decode(FoodParseResponse.self, from: data)
    }

    // MARK: - Activity Calorie Estimator

    /// Estimate calories burned for a described activity using AI-selected MET values.
    ///
    /// The AI selects a MET value from the Compendium of Physical Activities (Ainsworth et al.)
    /// and applies: Calories = MET × body_weight_kg × (duration_minutes / 60).
    /// Conservative (lower-end) MET values are preferred to avoid overestimation.
    ///
    /// - Parameters:
    ///   - activityDescription: Free-text activity (e.g. "pickleball", "uphill hiking").
    ///   - durationMinutes: Duration of the activity in minutes.
    ///   - bodyWeightKg: User's current body weight in kg.
    ///   - apiKey: User's Groq API key.
    /// - Returns: `ActivityEstimateResponse` including MET, burn, and AI reasoning.
    /// - Throws: `GroqError` on failure.
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

    /// Generate adaptive weekly coaching advice from 7 days of aggregated data.
    ///
    /// The system prompt encodes the coaching philosophy: prioritise muscle preservation,
    /// target a 500 kcal/day deficit, and flag when protein drops below 85% of target.
    /// Returns structured JSON with a `calorie_adjustment` directive and `muscle_risk` rating.
    ///
    /// - Parameters:
    ///   - userName: User's display name for personalised output.
    ///   - avgCaloriesConsumed: Average daily calories consumed over the past 7 days.
    ///   - avgProteinG: Average daily protein in grams over the past 7 days.
    ///   - calorieTarget: User's daily calorie target from `UserProfile`.
    ///   - proteinTarget: User's daily protein target in grams from `UserProfile`.
    ///   - weightChangeKg: Net weight change over the week (negative = lost weight, good for cut).
    ///   - workoutsCompleted: Number of workout sessions logged during the week.
    ///   - currentWeightKg: User's current weight in kg.
    ///   - targetWeightKg: User's goal weight in kg.
    ///   - apiKey: User's Groq API key.
    /// - Returns: `AdvisorResponse` with summary, adjustment directive, and muscle risk.
    /// - Throws: `GroqError` on failure.
    func getWeeklyAdvice(
        userName: String,
        avgCaloriesConsumed: Double,
        avgProteinG: Double,
        calorieTarget: Double,
        proteinTarget: Double,
        weightChangeKg: Double,
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

        // Format weight change as human-readable status for the prompt
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

    // MARK: - Photo Food Parser (Two-Step Vision Pipeline)

    /// Analyse a JPEG photo and return structured nutrition data using a two-step AI pipeline.
    ///
    /// **Step 1 — Vision (LLaMA 4 Scout):** Identifies food items and portions from the image.
    /// **Step 2 — Text (LLaMA 3.3 70B):** Converts the visual description into macro JSON.
    ///
    /// Both models are available on Groq's free tier. If no food is detected in step 1,
    /// a `GroqError.invalidResponse` is thrown with a user-friendly message.
    ///
    /// - Parameters:
    ///   - imageBase64: Base64-encoded JPEG string of the meal photo.
    ///   - apiKey: User's Groq API key.
    ///   - mealType: Label passed to the AI for context (e.g. "dinner").
    /// - Returns: `FoodParseResponse` with per-item macros.
    /// - Throws: `GroqError` if no food is detected, or on API/network failure.
    func parseFoodFromPhoto(
        imageBase64: String,
        apiKey: String,
        mealType: String = "meal"
    ) async throws -> FoodParseResponse {
        isLoading = true
        defer { isLoading = false }

        lastCallSucceeded = false
        UserDefaults.standard.set(false, forKey: "aiLastCallSucceeded")

        let resolvedKey = apiKey.isEmpty ? Constants.defaultGroqAPIKey : apiKey
        guard !resolvedKey.isEmpty else { throw GroqError.missingAPIKey }

        // STEP 1 — Vision: identify food items visible in the photo
        let visionPrompt = """
        Examine this food image carefully and list every distinct food item visible.
        For each item provide:
        - Specific food name (e.g. "white basmati rice", not just "rice")
        - Estimated portion size (e.g. "1 cup ~150g", "2 pieces", "1 bowl ~300ml")
        - Preparation method if visible (grilled, fried, steamed, raw, etc.)
        Only describe food items — ignore plates, cutlery, table, background.
        If no food is visible, respond with exactly: NO_FOOD_VISIBLE
        """

        let foodDescription = try await rawVisionCall(
            imageBase64: imageBase64,
            prompt: visionPrompt,
            resolvedKey: resolvedKey
        )

        guard !foodDescription.contains("NO_FOOD_VISIBLE") else {
            throw GroqError.invalidResponse("No food detected. Try a clearer, closer shot of your meal.")
        }

        // STEP 2 — Text: convert vision description into structured nutrition JSON
        let systemPrompt = """
        You are an expert nutritionist. A photo of a \(mealType) was visually analysed and the food items below were identified.
        Convert this description into accurate nutritional estimates.

        Reason carefully:
        - Use the exact portion sizes described
        - Adjust for preparation method (fried = more fat/calories, grilled = less, boiled = least)
        - Apply knowledge of regional foods (Indian, Asian, Mediterranean, Western, etc.)

        Return ONLY this JSON:
        {
          "items": [
            {
              "name": "specific food name",
              "calories": 123,
              "protein_g": 10.5,
              "carbs_g": 20.0,
              "fat_g": 5.0,
              "fiber_g": 2.0,
              "serving_size": "e.g. 200g / 1 bowl (~300ml)"
            }
          ],
          "total_calories": 123,
          "total_protein_g": 10.5,
          "total_carbs_g": 20.0,
          "total_fat_g": 5.0
        }

        All numeric values must be positive numbers, never null.
        """

        let userMessage = "Photo of my \(mealType) contained: \(foodDescription)"

        let nutritionJSON = try await rawTextCall(
            systemPrompt: systemPrompt,
            userMessage: userMessage,
            resolvedKey: resolvedKey
        )

        lastError = nil
        lastCallSucceeded = true
        UserDefaults.standard.set(true, forKey: "aiLastCallSucceeded")

        guard let data = nutritionJSON.data(using: .utf8) else {
            throw GroqError.invalidResponse("Could not decode nutrition response")
        }
        return try JSONDecoder().decode(FoodParseResponse.self, from: data)
    }

    // MARK: - Internal API Orchestration

    /// Orchestrates a standard text call: resolves the API key, delegates to `rawTextCall`,
    /// and updates `lastCallSucceeded` and `UserDefaults` for widget/indicator sync.
    private func callGroq(
        systemPrompt: String,
        userMessage: String,
        apiKey: String
    ) async throws -> String {
        lastCallSucceeded = false
        UserDefaults.standard.set(false, forKey: "aiLastCallSucceeded")

        let resolvedKey = apiKey.isEmpty ? Constants.defaultGroqAPIKey : apiKey
        guard !resolvedKey.isEmpty else { throw GroqError.missingAPIKey }

        let content = try await rawTextCall(
            systemPrompt: systemPrompt,
            userMessage: userMessage,
            resolvedKey: resolvedKey
        )

        lastError = nil
        lastCallSucceeded = true
        UserDefaults.standard.set(true, forKey: "aiLastCallSucceeded")
        return content
    }

    /// Raw text-only API call to LLaMA 3.3 70B. Does NOT modify `isLoading` or
    /// `lastCallSucceeded` — the caller is responsible for managing those.
    ///
    /// Uses `response_format: json_object` to guarantee structured JSON output.
    /// Temperature is set to 0.1 for deterministic, consistent macro estimates.
    private func rawTextCall(
        systemPrompt: String,
        userMessage: String,
        resolvedKey: String
    ) async throws -> String {
        guard let url = URL(string: baseURL) else { throw GroqError.invalidURL }

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
            "temperature": 0.1,
            "max_tokens": 1024
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GroqError.invalidResponse("Non-HTTP response")
        }
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            if httpResponse.statusCode == 401 { throw GroqError.invalidAPIKey }
            throw GroqError.apiError("HTTP \(httpResponse.statusCode): \(errorBody)")
        }
        // Traverse the standard OpenAI-compatible choices[0].message.content path
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw GroqError.invalidResponse("Unexpected response structure")
        }
        return content
    }

    /// Raw vision API call to LLaMA 4 Scout (multimodal). Does NOT modify `isLoading` or
    /// `lastCallSucceeded`. Encodes the image as a base64 data URL in the message payload.
    private func rawVisionCall(
        imageBase64: String,
        prompt: String,
        resolvedKey: String
    ) async throws -> String {
        guard let url = URL(string: baseURL) else { throw GroqError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(resolvedKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45  // vision calls are slower than text

        let body: [String: Any] = [
            "model": "meta-llama/llama-4-scout-17b-16e-instruct",
            "messages": [[
                "role": "user",
                "content": [
                    // Image part: inline base64 JPEG
                    ["type": "image_url",
                     "image_url": ["url": "data:image/jpeg;base64,\(imageBase64)"]],
                    // Text part: the vision prompt
                    ["type": "text", "text": prompt]
                ]
            ]],
            "temperature": 0.1,
            "max_tokens": 512
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GroqError.invalidResponse("Non-HTTP response from vision model")
        }
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            if httpResponse.statusCode == 401 { throw GroqError.invalidAPIKey }
            throw GroqError.apiError("Vision HTTP \(httpResponse.statusCode): \(errorBody)")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw GroqError.invalidResponse("Unexpected vision response structure")
        }
        return content
    }
}

// MARK: - GroqError

/// Typed errors for all Groq API failure modes.
enum GroqError: LocalizedError {
    /// No API key is configured in Settings.
    case missingAPIKey
    /// The API key was rejected by Groq (HTTP 401).
    case invalidAPIKey
    /// The base URL constant could not be parsed (should never happen in production).
    case invalidURL
    /// The model returned a response that couldn't be parsed or contained no food.
    case invalidResponse(String)
    /// A non-401 HTTP error was returned by the API.
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
