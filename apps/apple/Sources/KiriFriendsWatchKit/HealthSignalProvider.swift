import Foundation
import KiriFriendsCore

#if canImport(HealthKit)
import HealthKit

public final class HealthSignalProvider {
    private let healthStore: HKHealthStore

    public init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }

    public func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthSignalError.healthDataUnavailable
        }

        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.stepCount)
        ]

        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }

    public func currentSummary(now: Date = .now) async -> HealthSignalSummary {
        let heartRate = await latestQuantity(.heartRate, unit: HKUnit.count().unitDivided(by: .minute()))
        let restingHeartRate = await latestQuantity(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()))
        let hrv = await latestQuantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli))
        let steps = await todayStepCount()

        return HealthSignalClassifier.summary(
            heartRate: heartRate,
            restingHeartRate: restingHeartRate,
            hrv: hrv,
            steps: steps,
            capturedAt: now
        )
    }

    private func latestQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        let type = HKQuantityType(identifier)
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.date(byAdding: .hour, value: -2, to: .now),
            end: .now,
            options: .strictEndDate
        )
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )
        guard let sample = try? await descriptor.result(for: healthStore).first else { return nil }
        return sample.quantity.doubleValue(for: unit)
    }

    private func todayStepCount() async -> Double? {
        let type = HKQuantityType(.stepCount)
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.startOfDay(for: .now),
            end: .now,
            options: .strictStartDate
        )
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: .cumulativeSum
        )
        let result = try? await descriptor.result(for: healthStore)
        return result?.sumQuantity()?.doubleValue(for: .count())
    }
}

public enum HealthSignalError: Error, Hashable, Sendable {
    case healthDataUnavailable
}
#endif

public enum HealthSignalClassifier {
    public static func summary(
        heartRate: Double?,
        restingHeartRate: Double?,
        hrv: Double?,
        steps: Double?,
        capturedAt: Date
    ) -> HealthSignalSummary {
        let energyLevel = energy(from: steps)
        let stressLevel = stress(heartRate: heartRate, restingHeartRate: restingHeartRate, hrv: hrv)
        let activityState = activity(energyLevel: energyLevel, stressLevel: stressLevel)
        let confidence = confidence(heartRate: heartRate, restingHeartRate: restingHeartRate, hrv: hrv, steps: steps)

        return HealthSignalSummary(
            activityState: activityState,
            energyLevel: energyLevel,
            stressLevel: stressLevel,
            confidence: confidence,
            capturedAt: capturedAt
        )
    }

    private static func energy(from steps: Double?) -> Int {
        guard let steps else { return 2 }
        if steps < 1_000 { return 1 }
        if steps > 8_000 { return 4 }
        return 2
    }

    private static func stress(heartRate: Double?, restingHeartRate: Double?, hrv: Double?) -> Int {
        guard let heartRate, let restingHeartRate else { return 1 }
        let elevatedHeartRate = heartRate - restingHeartRate
        if elevatedHeartRate > 35 { return 4 }
        if elevatedHeartRate > 20 || (hrv ?? 100) < 25 { return 3 }
        return 1
    }

    private static func activity(energyLevel: Int, stressLevel: Int) -> HealthActivityState {
        if stressLevel >= 3 { return .stressed }
        if energyLevel >= 4 { return .active }
        if energyLevel <= 1 { return .resting }
        return .focused
    }

    private static func confidence(
        heartRate: Double?,
        restingHeartRate: Double?,
        hrv: Double?,
        steps: Double?
    ) -> Double {
        let observed = [heartRate, restingHeartRate, hrv, steps].compactMap { $0 }.count
        return Double(observed) / 4.0
    }
}
