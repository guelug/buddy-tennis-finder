import Foundation
import HealthKit

/// Reads body metrics from Apple Health to pre-fill the styling profile (height, weight, waist, age).
@MainActor
final class HealthKitService {
    private let store = HKHealthStore()

    struct ImportedMetrics {
        var heightCm: Double?
        var weightKg: Double?
        var waistCm: Double?
        var age: Int?

        var hasAnyValue: Bool {
            heightCm != nil || weightKg != nil || waistCm != nil || age != nil
        }
    }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Requests read access and returns the latest available metrics. Missing/denied values are nil.
    func requestAndImport() async throws -> ImportedMetrics {
        guard isAvailable else { return ImportedMetrics() }

        let height = HKQuantityType(.height)
        let weight = HKQuantityType(.bodyMass)
        let waist = HKQuantityType(.waistCircumference)
        let dateOfBirth = HKCharacteristicType(.dateOfBirth)

        let readTypes: Set<HKObjectType> = [height, weight, waist, dateOfBirth]
        try await store.requestAuthorization(toShare: [], read: readTypes)

        var metrics = ImportedMetrics()
        metrics.heightCm = await latestQuantity(height, unit: .meterUnit(with: .centi))
        metrics.weightKg = await latestQuantity(weight, unit: .gramUnit(with: .kilo))
        metrics.waistCm = await latestQuantity(waist, unit: .meterUnit(with: .centi))
        metrics.age = currentAge()
        return metrics
    }

    private func currentAge() -> Int? {
        guard let components = try? store.dateOfBirthComponents(),
              let birthDate = Calendar.current.date(from: components) else {
            return nil
        }
        return Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year
    }

    private func latestQuantity(_ type: HKQuantityType, unit: HKUnit) async -> Double? {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )

        guard let sample = try? await descriptor.result(for: store).first else {
            return nil
        }
        return sample.quantity.doubleValue(for: unit)
    }
}
