# LeanAI

**AI-powered nutrition tracker built for fat loss without losing muscle.**

LeanAI lets you log meals in plain English and get accurate macro breakdowns in seconds, powered by LLaMA 3.3 70B via the Groq API. It combines adaptive calorie targeting, HealthKit activity sync, strength tracking with Epley 1RM estimation, and CloudKit-based partner accountability — all in a clean SwiftUI interface with full offline-first SwiftData persistence.

---

## Features

- **Natural-language food logging** — describe a meal in plain English ("2 chapatis, dal makhani, raita") and LLaMA 3.3 70B extracts per-item macros with cultural food awareness (Indian, Mediterranean, Asian, Western cuisines)
- **Photo food logging** — snap a photo of your meal; a two-step AI pipeline (LLaMA 4 Scout vision → LLaMA 3.3 text) identifies items and estimates macros
- **Full-day parsing** — log an entire day's meals in one message; AI assigns meal types from time cues automatically
- **Adaptive calorie targets** — Mifflin-St Jeor BMR with conservative TDEE multipliers; goal-specific macro ratios for cut / maintain / bulk
- **Activity calorie estimation** — describe any activity in natural language; the AI selects an appropriate MET value from the Compendium of Physical Activities (Ainsworth et al.) and applies `Calories = MET × kg × hours`
- **HealthKit step sync** — converts step count to calories using height-adjusted stride estimation at MET 3.5 (brisk walk)
- **Strength testing with 1RM estimation** — log any set and the Epley formula (`weight × (1 + reps/30)`) calculates your estimated one-rep max; results are classified against Symmetric Strength standards across 6 tiers (Untrained → Elite) for Bench, Squat, Deadlift, OHP, Pull-up, and RDL
- **Muscle-loss monitoring** — alerts when estimated 1RM drops >5% over two weeks while in a deficit
- **AI weekly summaries** — adaptive coaching that adjusts calorie targets based on 7-day adherence, weight change, and protein compliance; flags muscle risk as low / medium / high
- **US Navy body fat estimation** — tape-measurement-based body fat % using circumference measurements, no DEXA required
- **CloudKit partner sharing** — 6-character pair codes to share weekly progress with an accountability partner; read-only summary view of partner data
- **Insights dashboard** — calorie adherence trends, macro split breakdown, strength progression, and deficit streak tracking

---

## Screenshots

> Screenshots coming soon. The app targets iOS 17+ with a dark-themed SwiftUI design.

| Dashboard | Food Log | Strength |
|-----------|----------|----------|
| _(placeholder)_ | _(placeholder)_ | _(placeholder)_ |

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI |
| Persistence | SwiftData (offline-first, on-device) |
| Cloud sync | CloudKit (partner sharing via custom pair codes) |
| AI / LLM | Groq API — LLaMA 3.3 70B (text), LLaMA 4 Scout 17B (vision) |
| Health data | HealthKit (steps, active energy) |
| Language | Swift 5.9+ |
| Minimum target | iOS 17, Xcode 15 |

---

## Architecture

```
LeanAI/
├── Models/                      # SwiftData @Model classes (offline-first)
│   ├── UserProfile.swift        # Biometrics, goals, BMR/TDEE/macro targets, pair codes
│   ├── DailyLog.swift           # One record per calendar day; food + activity aggregation
│   ├── FoodEntry.swift          # Per-item macro data from AI parser
│   ├── StrengthTestEntry.swift  # Epley 1RM + Symmetric Strength classification
│   ├── ActivityEntry.swift      # MET-based calorie burn records
│   ├── BodyMeasurement.swift    # Tape measurements for Navy body fat estimation
│   └── SavedFood.swift          # Favourited foods for quick re-logging
│
├── Services/                    # Business logic (stateless utilities + async AI service)
│   ├── GroqService.swift        # All Groq API calls (text + vision); ObservableObject
│   ├── NutritionCalculator.swift    # BMR, TDEE, macros, Navy body fat, weekly summary
│   ├── ActivityCalculator.swift     # MET formula, step calories, preset + strength estimation
│   ├── HealthKitService.swift       # HealthKit authorisation and step/energy fetching
│   └── CloudKitSharingService.swift # Partner pair code sync and read
│
├── Views/                       # SwiftUI view hierarchy
│   ├── Dashboard/               # Home screen with daily ring, macro bar, and quick log
│   ├── Nutrition/               # Food log, AI input sheet, per-meal breakdown
│   ├── Activity/                # Activity log, AI estimator, preset selector
│   ├── Strength/                # Strength test log, 1RM history, level badges
│   ├── Progress/                # Weight chart, body fat trend, weekly summary
│   ├── Insights/                # Calorie adherence, macro trends, deficit streak
│   ├── Partner/                 # CloudKit pair code entry and partner summary view
│   ├── Settings/                # API key input, profile edit, goal selection
│   └── Onboarding/              # First-launch profile creation flow
│
└── Utilities/
    ├── Constants.swift          # All magic numbers and configuration strings
    ├── Extensions.swift         # Swift/Foundation extensions (date formatting, etc.)
    └── SharedComponents.swift   # Reusable SwiftUI components (macro ring, stat card, etc.)
```

**Data flow:** SwiftData persists all models locally on-device (offline-first). CloudKit sync is scoped to partner summary reads/writes only — the full log stays on-device. All AI calls go directly from the device to the Groq API using the user's own API key; no LeanAI backend is involved.

---

## Setup & Configuration

### 1. Clone and open

```bash
git clone https://github.com/akshatmadrock/LeanAI.git
cd LeanAI
open LeanAI.xcodeproj
```

### 2. Get a Groq API key

1. Create a free account at [console.groq.com](https://console.groq.com)
2. Generate an API key — the free tier is sufficient; LLaMA 3.3 70B and LLaMA 4 Scout are both available at no cost

### 3. Add your API key in the app

Launch the app → **Settings** → **AI Configuration** → paste your Groq API key.

The key is stored in `UserProfile.groqAPIKey` via SwiftData (on-device only; never sent to any backend other than Groq).

### 4. HealthKit permissions

On first launch the app requests HealthKit read access for step count and active energy. Approve both for full activity sync.

### 5. CloudKit (optional — partner sharing only)

Add your own CloudKit container identifier in Xcode under **Signing & Capabilities → CloudKit** if you want partner sharing to work.

---

## Requirements

- iOS 17.0 or later
- Swift 5.9+
- Xcode 15+
- Groq API key (free at [console.groq.com](https://console.groq.com))
- HealthKit entitlement (pre-configured in the project)
- CloudKit entitlement (required only for partner sharing)

---

## How It Works

### Natural-Language Food Logging

1. User types a meal description, e.g. _"200g grilled chicken, 1 cup brown rice, salad with olive oil"_
2. `GroqService.parseFoodDescription` sends the text to LLaMA 3.3 70B with a structured system prompt enforcing JSON output (`response_format: json_object`, temperature 0.1)
3. The model reasons about preparation method, portion size, cultural context, and added fats before estimating macros
4. The JSON response is decoded into `[ParsedFoodItem]` and persisted as `FoodEntry` records in SwiftData

### Photo Food Logging (Two-Step Vision Pipeline)

1. User captures or selects a meal photo; it is base64-encoded as JPEG
2. **Step 1 — Vision:** LLaMA 4 Scout identifies food items, portion sizes, and preparation method from the image
3. **Step 2 — Text:** LLaMA 3.3 70B converts the vision description into structured macro JSON
4. Result is decoded and saved identically to text-based logging

### Calorie Target Calculation

```
BMR  = (10 × kg) + (6.25 × cm) − (5 × age) ± sex_adjustment   // Mifflin-St Jeor
TDEE = BMR × activity_multiplier   // [1.2, 1.35, 1.5, 1.65]

Cut target   = max(TDEE − 500, floor)   // floor: 1500 male / 1200 female
Bulk target  = TDEE + 300
Protein      = weight_kg × 1.8–2.0 g   // goal-dependent; high for muscle preservation
Fat          = weight_kg × 0.7–0.9 g   // hormonal health minimum
Carbs        = (target_kcal − protein_kcal − fat_kcal) / 4   // fills remaining budget
```

### Strength Classification

```
1RM   = weight × (1 + reps / 30)     // Epley formula
ratio = 1RM / bodyweight
level = Symmetric Strength lookup[ratio]   // Untrained → Beginner → Novice → Intermediate → Advanced → Elite
```

---

## Contributing

Pull requests are welcome. For significant changes please open an issue first to discuss what you'd like to change.

---

## Built By

**Akshat Gupta** — Incoming Apple SWE Intern (Summer 2026) · MS Computer Engineering, UCSD · ex-Arista Networks

[LinkedIn](https://linkedin.com/in/akshatmadrock) · [Portfolio](https://akshatmadrock.github.io)

---

## License

MIT
