import Foundation
import HealthKit
import Combine

@MainActor
final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()
    @Published var isAuthorized = false
    @Published var authorizationStatus: HKAuthorizationStatus = .notDetermined

    private let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
    private let bodyFatType = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!

    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private init() {}

    func requestAuthorization() async throws {
        guard isHealthKitAvailable else {
            throw HealthKitError.notAvailable
        }

        let typesToRead: Set<HKObjectType> = [weightType, bodyFatType]
        let typesToWrite: Set<HKSampleType> = [weightType, bodyFatType]

        try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)

        await updateAuthorizationStatus()
    }

    func updateAuthorizationStatus() async {
        authorizationStatus = healthStore.authorizationStatus(for: weightType)
        isAuthorized = authorizationStatus == .sharingAuthorized
    }

    func saveWeight(
        weightInKg: Double,
        date: Date,
        bodyFatPercentage: Double? = nil
    ) async throws {
        guard isAuthorized else {
            throw HealthKitError.notAuthorized
        }

        let weightQuantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: weightInKg * 1000)
        let weightSample = HKQuantitySample(
            type: weightType,
            quantity: weightQuantity,
            start: date,
            end: date
        )

        var samples: [HKQuantitySample] = [weightSample]

        if let bodyFat = bodyFatPercentage {
            let bodyFatQuantity = HKQuantity(unit: .percent(), doubleValue: bodyFat / 100.0)
            let bodyFatSample = HKQuantitySample(
                type: bodyFatType,
                quantity: bodyFatQuantity,
                start: date,
                end: date
            )
            samples.append(bodyFatSample)
        }

        try await healthStore.save(samples)
    }

    func fetchWeightData(from startDate: Date, to endDate: Date = Date()) async throws -> [WeightDataPoint] {
        guard isHealthKitAvailable else {
            throw HealthKitError.notAvailable
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: weightType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let weightDataPoints = (samples as? [HKQuantitySample])?.map { sample in
                    WeightDataPoint(
                        date: sample.startDate,
                        weightInKg: sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                    )
                } ?? []

                continuation.resume(returning: weightDataPoints)
            }

            self.healthStore.execute(query)
        }
    }

    func fetchLatestWeight() async throws -> WeightDataPoint? {
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: weightType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }

                let dataPoint = WeightDataPoint(
                    date: sample.startDate,
                    weightInKg: sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                )

                continuation.resume(returning: dataPoint)
            }

            self.healthStore.execute(query)
        }
    }

    func deleteWeightData(from date: Date) async throws {
        let predicate = HKQuery.predicateForSamples(withStart: date, end: date, options: .strictStartDate)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let query = HKSampleQuery(
                sampleType: weightType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { [weak self] _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let samples = samples else {
                    continuation.resume()
                    return
                }

                Task {
                    do {
                        try await self?.healthStore.delete(samples)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            self.healthStore.execute(query)
        }
    }
}

struct WeightDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let weightInKg: Double
}

enum HealthKitError: LocalizedError {
    case notAvailable
    case notAuthorized
    case saveFailed
    case fetchFailed

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return NSLocalizedString("error.healthkit.not.available", comment: "")
        case .notAuthorized:
            return NSLocalizedString("error.healthkit.not.authorized", comment: "")
        case .saveFailed:
            return NSLocalizedString("error.healthkit.save.failed", comment: "")
        case .fetchFailed:
            return NSLocalizedString("error.healthkit.fetch.failed", comment: "")
        }
    }
}
