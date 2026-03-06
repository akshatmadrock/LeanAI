# LeanAI — AI-Powered Fat Loss & Muscle Preservation

> **iOS App · 2025**

LeanAI is a full-featured iOS nutrition and fitness tracking app built around one goal: losing fat while preserving muscle. It combines AI-driven food logging, adaptive calorie/macro targets, HealthKit integration, strength testing, and CloudKit-based partner sharing into a cohesive training companion.

---

## Features

### Nutrition & Calories
- **AI Food Log** — Describe what you ate in plain English; LLaMA 3.3 extracts macros automatically via Groq API
- **Adaptive Targets** — Calorie and macro goals calculated from body metrics, activity level, and cut rate
- **Daily Logging** — Track meals, protein, carbs, fat, and fiber with persistent SwiftData storage

### Body & Progress
- **Body Measurements** — Log weight, body fat %, and muscle mass over time
- **Progress Charts** — Visual trends for weight, body composition, and macros
- **Strength Testing** — Log 1RM estimates and track strength preservation across a cut

### Activity & Health
- **HealthKit Integration** — Pulls step count, active energy, and workout data automatically
- **Activity Logging** — Manual cardio and workout entries with calorie burn estimates
- **TDEE Calculation** — Dynamic total daily energy expenditure based on actual movement data

### Social & Sync
- **Partner View** — Share progress and accountability with a training partner via CloudKit
- **iCloud Sync** — Data syncs across devices automatically

### AI Insights
- **Weekly Summaries** — AI-generated analysis of your nutrition and training week
- **Adaptive Recommendations** — Adjustments based on weekly weigh-in and adherence data

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| UI | SwiftUI |
| Persistence | SwiftData |
| Cloud Sync | CloudKit |
| Health Data | HealthKit |
| AI (Food Log + Insights) | Groq API (LLaMA 3.3-70b) |
| Platform | iOS 17+ |
| Language | Swift 5.9 |

---

## Architecture

```
LeanAI/
├── Models/           # SwiftData models (UserProfile, DailyLog, FoodEntry, BodyMeasurement, ActivityEntry, StrengthTestEntry)
├── Views/
│   ├── Dashboard/    # Home screen — calorie rings, macro summary
│   ├── Nutrition/    # Food log, AI food entry
│   ├── Activity/     # Workout + cardio tracking
│   ├── Progress/     # Body composition charts
│   ├── Strength/     # 1RM tracking and trends
│   ├── Insights/     # AI weekly analysis
│   ├── Partner/      # CloudKit sharing
│   ├── Settings/     # Goals, profile, API config
│   └── Onboarding/   # Initial setup flow
├── Services/         # GroqService, HealthKitService, CloudKitSharingService, NutritionCalculator, ActivityCalculator
└── Utilities/        # Extensions, SharedComponents
```

---

## Setup

1. Clone the repo
2. Open `LeanAI.xcodeproj` in Xcode 15+
3. Create a `Constants.swift` (excluded from git) with your API keys:

```swift
// Constants.swift — DO NOT COMMIT
enum Constants {
    static let defaultGroqAPIKey = "YOUR_GROQ_API_KEY"
}
```

4. In Xcode, set your Apple Developer Team for HealthKit + CloudKit entitlements
5. Select your target device (iPhone, iOS 17+)
6. Build & Run (`⌘R`)

> **Note:** A Groq API key is required for AI food logging and insights. The app will run without it, but AI features will be unavailable.

---

## Screenshots

*Coming soon*

---

## Built By

**Akshat Gupta** — Incoming Apple SWE Intern (Summer 2026) · MS Computer Engineering, UCSD · ex-Arista Networks

[LinkedIn](https://linkedin.com/in/akshatmadrock) · [Portfolio](https://akshatmadrock.github.io)
