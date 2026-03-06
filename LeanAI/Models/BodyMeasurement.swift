import Foundation
import SwiftData

@Model
final class BodyMeasurement {
    var id: UUID
    var date: Date
    var weightKg: Double
    var waistCm: Double?
    var chestCm: Double?
    var hipsCm: Double?
    var neckCm: Double?
    var leftArmCm: Double?
    var rightArmCm: Double?
    var bodyFatPercentage: Double?       // optional — user may not have a smart scale
    var notes: String

    init(
        date: Date = Date(),
        weightKg: Double,
        waistCm: Double? = nil,
        chestCm: Double? = nil,
        hipsCm: Double? = nil,
        neckCm: Double? = nil,
        leftArmCm: Double? = nil,
        rightArmCm: Double? = nil,
        bodyFatPercentage: Double? = nil,
        notes: String = ""
    ) {
        self.id = UUID()
        self.date = date
        self.weightKg = weightKg
        self.waistCm = waistCm
        self.chestCm = chestCm
        self.hipsCm = hipsCm
        self.neckCm = neckCm
        self.leftArmCm = leftArmCm
        self.rightArmCm = rightArmCm
        self.bodyFatPercentage = bodyFatPercentage
        self.notes = notes
    }

    // Estimate lean mass and fat mass if body fat % is available
    var leanMassKg: Double? {
        guard let bf = bodyFatPercentage else { return nil }
        return weightKg * (1 - bf / 100)
    }

    var fatMassKg: Double? {
        guard let bf = bodyFatPercentage else { return nil }
        return weightKg * (bf / 100)
    }
}
