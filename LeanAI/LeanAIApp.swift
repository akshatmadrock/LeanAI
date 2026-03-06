import SwiftUI
import SwiftData

@main
struct LeanAIApp: App {

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            DailyLog.self,
            FoodEntry.self,
            ActivityEntry.self,
            StrengthTestEntry.self,
            BodyMeasurement.self,
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
