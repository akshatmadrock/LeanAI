import Foundation
import HealthKit
import SwiftUI

// MARK: - HealthKit Service
// Requires in Xcode: Target → Signing & Capabilities → + Capability → HealthKit
// Requires in Info.plist: NSHealthShareUsageDescription = "LeanAI reads your step count to automatically track your daily activity without manual entry."

@MainActor
final class HealthKitService: ObservableObject {

    private let healthStore = HKHealthStore()
    private let stepType = HKQuantityType(.stepCount)

    @Published var isAuthorized = false
    @Published var isAvailable = HKHealthStore.isHealthDataAvailable()
    @Published var todaySteps: Int = 0

    // MARK: - Authorization

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            isAvailable = false
            return
        }
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [stepType])
            isAuthorized = true
        } catch let error as NSError {
            // Missing entitlement (Personal Team) — hide HealthKit UI entirely
            if error.domain == "com.apple.healthkit" && error.code == 4 {
                isAvailable = false
            }
            isAuthorized = false
        }
    }

    // MARK: - Fetch today's steps

    func fetchTodaySteps() async -> Int {
        guard HKHealthStore.isHealthDataAvailable(), isAuthorized else { return 0 }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(steps))
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Sync steps into a DailyLog

    /// Fetches steps from HealthKit and updates the log if HealthKit has more steps.
    /// Always takes the higher value (user may have manually entered a number).
    func syncSteps(into log: inout Int) async {
        let hkSteps = await fetchTodaySteps()
        todaySteps = hkSteps
        if hkSteps > log {
            log = hkSteps
        }
    }

    // MARK: - Observe step changes (live updates as user walks)

    private var observerQuery: HKObserverQuery?

    func startObservingSteps(onChange: @escaping () async -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        observerQuery = HKObserverQuery(sampleType: stepType, predicate: nil) { _, _, error in
            guard error == nil else { return }
            Task { await onChange() }
        }
        if let q = observerQuery {
            healthStore.execute(q)
        }
    }

    func stopObservingSteps() {
        if let q = observerQuery {
            healthStore.stop(q)
            observerQuery = nil
        }
    }

    // MARK: - Step history (last N days for charts)

    struct DaySteps: Identifiable {
        let id = UUID()
        let date: Date
        let steps: Int
    }

    func fetchStepHistory(days: Int = 14) async -> [DaySteps] {
        guard HKHealthStore.isHealthDataAvailable() else { return [] }

        let calendar = Calendar.current
        let now = Date()
        var results: [DaySteps] = []

        for i in 0..<days {
            guard let start = calendar.date(byAdding: .day, value: -i, to: calendar.startOfDay(for: now)),
                  let end = calendar.date(byAdding: .day, value: 1, to: start) else { continue }

            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let steps = await withCheckedContinuation { (continuation: CheckedContinuation<Int, Never>) in
                let q = HKStatisticsQuery(
                    quantityType: stepType,
                    quantitySamplePredicate: predicate,
                    options: .cumulativeSum
                ) { _, result, _ in
                    continuation.resume(returning: Int(result?.sumQuantity()?.doubleValue(for: .count()) ?? 0))
                }
                healthStore.execute(q)
            }
            results.append(DaySteps(date: start, steps: steps))
        }

        return results.reversed()
    }
}
