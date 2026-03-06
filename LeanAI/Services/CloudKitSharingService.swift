import Foundation
import CloudKit

// MARK: - Partner Summary (lightweight — no raw food/weight data)

struct PartnerSummaryData: Codable {
    var name: String
    var currentWeightKg: Double
    var targetWeightKg: Double
    var startWeightKg: Double
    var todayCalories: Double
    var todayCalorieTarget: Double
    var todayProtein: Double
    var todayProteinTarget: Double
    var todayBurned: Double
    var streak: Int
    var progressPercent: Double
    var weightLostKg: Double
    var lastUpdated: Date
    var pairCode: String

    var caloriesRemaining: Double { todayCalorieTarget - todayCalories + todayBurned }
    var isOnTrackToday: Bool { todayCalories <= todayCalorieTarget && todayProtein >= todayProteinTarget * 0.85 }
}

// MARK: - CloudKit Sharing Service
// Requires: Target → Signing & Capabilities → iCloud → enable CloudKit checkbox
// Container: iCloud.$(PRODUCT_BUNDLE_IDENTIFIER)

@MainActor
final class CloudKitSharingService: ObservableObject {

    private let recordType = "PartnerSummary"
    private var database: CKDatabase {
        CKContainer.default().publicCloudDatabase
    }

    @Published var isSyncing = false
    @Published var lastError: String?
    @Published var partnerSummary: PartnerSummaryData?
    @Published var lastSyncDate: Date?

    // MARK: - iCloud availability check

    /// Returns true if the device has an iCloud account available.
    private func iCloudAvailable() async -> Bool {
        do {
            let status = try await CKContainer.default().accountStatus()
            return status == .available
        } catch {
            return false
        }
    }

    // MARK: - Publish my summary

    func publishSummary(_ summary: PartnerSummaryData) async {
        guard await iCloudAvailable() else {
            lastError = nil  // silent — iCloud optional feature
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        let recordID = CKRecord.ID(recordName: summary.pairCode)

        do {
            // Fetch existing record to update in place; create new if not found
            let recordToSave: CKRecord
            if let existing = try? await database.record(for: recordID) {
                recordToSave = existing
            } else {
                recordToSave = CKRecord(recordType: recordType, recordID: recordID)
            }

            recordToSave["name"]               = summary.name as CKRecordValue
            recordToSave["currentWeightKg"]    = summary.currentWeightKg as CKRecordValue
            recordToSave["targetWeightKg"]     = summary.targetWeightKg as CKRecordValue
            recordToSave["startWeightKg"]      = summary.startWeightKg as CKRecordValue
            recordToSave["todayCalories"]      = summary.todayCalories as CKRecordValue
            recordToSave["todayCalorieTarget"] = summary.todayCalorieTarget as CKRecordValue
            recordToSave["todayProtein"]       = summary.todayProtein as CKRecordValue
            recordToSave["todayProteinTarget"] = summary.todayProteinTarget as CKRecordValue
            recordToSave["todayBurned"]        = summary.todayBurned as CKRecordValue
            recordToSave["streak"]             = summary.streak as CKRecordValue
            recordToSave["progressPercent"]    = summary.progressPercent as CKRecordValue
            recordToSave["weightLostKg"]       = summary.weightLostKg as CKRecordValue
            recordToSave["lastUpdated"]        = summary.lastUpdated as CKRecordValue
            recordToSave["pairCode"]           = summary.pairCode as CKRecordValue

            _ = try await database.save(recordToSave)
            lastError = nil
        } catch {
            lastError = "Sync failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Fetch partner's summary

    func fetchPartnerSummary(pairCode: String) async -> PartnerSummaryData? {
        guard await iCloudAvailable() else {
            lastError = "iCloud is not available. Sign in to iCloud in Settings to use partner features."
            return loadCachedSummary(pairCode: pairCode)
        }

        isSyncing = true
        defer { isSyncing = false }

        let cleanCode = pairCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard cleanCode.count == 6 else {
            lastError = "Pair code must be 6 characters."
            return nil
        }

        let recordID = CKRecord.ID(recordName: cleanCode)
        do {
            let record = try await database.record(for: recordID)
            let summary = PartnerSummaryData(
                name:               record["name"]               as? String ?? "Partner",
                currentWeightKg:    record["currentWeightKg"]    as? Double ?? 0,
                targetWeightKg:     record["targetWeightKg"]     as? Double ?? 0,
                startWeightKg:      record["startWeightKg"]      as? Double ?? 0,
                todayCalories:      record["todayCalories"]      as? Double ?? 0,
                todayCalorieTarget: record["todayCalorieTarget"] as? Double ?? 0,
                todayProtein:       record["todayProtein"]       as? Double ?? 0,
                todayProteinTarget: record["todayProteinTarget"] as? Double ?? 0,
                todayBurned:        record["todayBurned"]        as? Double ?? 0,
                streak:             record["streak"]             as? Int    ?? 0,
                progressPercent:    record["progressPercent"]    as? Double ?? 0,
                weightLostKg:       record["weightLostKg"]       as? Double ?? 0,
                lastUpdated:        record["lastUpdated"]        as? Date   ?? Date(),
                pairCode:           cleanCode
            )
            partnerSummary = summary
            lastSyncDate = Date()
            lastError = nil
            // Cache for offline use
            if let encoded = try? JSONEncoder().encode(summary) {
                UserDefaults.standard.set(encoded, forKey: "cachedPartnerSummary_\(cleanCode)")
                UserDefaults.standard.set(Date(), forKey: "cachedPartnerSyncDate_\(cleanCode)")
            }
            return summary
        } catch CKError.unknownItem {
            lastError = "No one found with that code. Double-check it!"
            return nil
        } catch {
            lastError = "Couldn't reach iCloud: \(error.localizedDescription)"
            return loadCachedSummary(pairCode: cleanCode)
        }
    }

    // MARK: - Cache helpers

    func loadCachedSummary(pairCode: String) -> PartnerSummaryData? {
        let key = "cachedPartnerSummary_\(pairCode.uppercased())"
        guard let data = UserDefaults.standard.data(forKey: key),
              let summary = try? JSONDecoder().decode(PartnerSummaryData.self, from: data) else {
            return nil
        }
        return summary
    }

    func loadCachedSyncDate(pairCode: String) -> Date? {
        UserDefaults.standard.object(forKey: "cachedPartnerSyncDate_\(pairCode.uppercased())") as? Date
    }

    // MARK: - Build summary from profile

    static func buildSummary(profile: UserProfile, todayLog: DailyLog?, streak: Int) -> PartnerSummaryData {
        return PartnerSummaryData(
            name:               profile.name,
            currentWeightKg:    profile.currentWeightKg,
            targetWeightKg:     profile.targetWeightKg,
            startWeightKg:      profile.startWeightKg,
            todayCalories:      todayLog?.totalCaloriesConsumed ?? 0,
            todayCalorieTarget: profile.dailyCalorieTarget,
            todayProtein:       todayLog?.totalProteinG ?? 0,
            todayProteinTarget: profile.dailyProteinGrams,
            todayBurned:        todayLog?.totalCaloriesBurned ?? 0,
            streak:             streak,
            progressPercent:    profile.progressPercent,
            weightLostKg:       profile.weightLostSoFarKg,
            lastUpdated:        Date(),
            pairCode:           profile.pairCode
        )
    }
}
