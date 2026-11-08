import Foundation
import HealthKit
import SwiftData
import TonicKit

/// Reads Apple Health and fills in habits that Health can measure.
///
/// Data is only read on this phone and saved into Tonic's own database.
/// Anything you logged by hand is never overwritten.
@MainActor
final class HealthSync {
    static let shared = HealthSync()

    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var readTypes: Set<HKObjectType> {
        [
            HKCategoryType(.sleepAnalysis),
            HKQuantityType(.stepCount),
            HKQuantityType(.appleExerciseTime),
            HKQuantityType(.dietaryWater),
            HKCategoryType(.mindfulSession),
        ]
    }

    /// Release builds only read. Debug builds can also write sample data for testing.
    /// (Exercise minutes can't be written by apps, so sample exercise is saved as workouts.)
    private var shareTypes: Set<HKSampleType> {
        #if DEBUG
        [
            HKCategoryType(.sleepAnalysis),
            HKQuantityType(.stepCount),
            HKQuantityType(.dietaryWater),
            HKCategoryType(.mindfulSession),
            HKObjectType.workoutType(),
        ]
        #else
        []
        #endif
    }

    func requestAccess() async throws {
        try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    // MARK: Sync

    /// Fills in the last `lookbackDays` days (never before your start date).
    /// Returns how many habit logs were added or updated.
    @discardableResult
    func sync(context: ModelContext, lookbackDays: Int = 14) async -> Int {
        guard isAvailable else { return 0 }
        let supported = HealthImport.supportedBehaviorIDs
        let tracked = ((try? context.fetch(FetchDescriptor<TrackedBehavior>())) ?? [])
            .filter { $0.isEnabled && supported.contains($0.id) }
            .map(\.behavior)
        guard !tracked.isEmpty else { return 0 }

        let today = Day(.now)
        let journeyStart = UserDefaults.standard.integer(forKey: AppSettings.journeyStartDay)
        let first = Day(index: max(journeyStart, today.index - lookbackDays + 1))
        let days = (first...today).map { $0 }
        let healthDays = await fetch(days: days)

        let firstIndex = first.index
        let existing = (try? context.fetch(FetchDescriptor<DailyLog>(predicate: #Predicate { $0.dayIndex >= firstIndex }))) ?? []
        var changed = 0

        for data in healthDays {
            for behavior in tracked where behavior.isActive(on: data.day) {
                guard let value = HealthImport.value(for: behavior, from: data) else { continue }
                if let log = existing.first(where: { $0.behaviorID == behavior.id && $0.dayIndex == data.day.index }) {
                    guard log.isFromHealth, log.value != value else { continue } // manual entries win
                    log.value = value
                    changed += 1
                } else {
                    let log = DailyLog(LogEntry(behaviorID: behavior.id, day: data.day, value: value))
                    log.source = DailyLog.healthSource
                    context.insert(log)
                    changed += 1
                }
            }
        }
        if changed > 0 { try? context.save() }
        return changed
    }

    // MARK: Reading

    func fetch(days: [Day]) async -> [HealthDay] {
        var results: [HealthDay] = []
        for day in days {
            let start = day.startDate
            let end = day.advanced(by: 1).startDate
            var data = HealthDay(day: day)
            data.steps = await sum(.stepCount, unit: .count(), from: start, to: end)
            data.exerciseMinutes = await sum(.appleExerciseTime, unit: .minute(), from: start, to: end)
            data.waterLiters = await sum(.dietaryWater, unit: .liter(), from: start, to: end)
            data.mindfulMinutes = await duration(.mindfulSession, from: start, to: end, asleepOnly: false).map { $0 / 60 }
            // A night counts toward the morning you wake up: 6 pm the evening before until noon.
            data.sleepHours = await duration(
                .sleepAnalysis,
                from: start.addingTimeInterval(-6 * 3600),
                to: start.addingTimeInterval(12 * 3600),
                asleepOnly: true
            ).map { $0 / 3600 }
            results.append(data)
        }
        return results
    }

    private func sum(_ id: HKQuantityTypeIdentifier, unit: HKUnit, from start: Date, to end: Date) async -> Double? {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let query = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(id), predicate: predicate),
            options: .cumulativeSum
        )
        let stats = try? await query.result(for: store)
        return stats?.sumQuantity()?.doubleValue(for: unit)
    }

    /// Total time covered by category samples in the window, merging overlaps. Seconds.
    private func duration(_ id: HKCategoryTypeIdentifier, from start: Date, to end: Date, asleepOnly: Bool) async -> Double? {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let query = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(id), predicate: predicate)],
            sortDescriptors: []
        )
        guard let samples = try? await query.result(for: store), !samples.isEmpty else { return nil }
        let asleep = HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue)
        let intervals = samples
            .filter { !asleepOnly || asleep.contains($0.value) }
            .map { (start: max($0.startDate, start).timeIntervalSince1970, end: min($0.endDate, end).timeIntervalSince1970) }
        let total = HealthImport.mergedDuration(intervals)
        return total > 0 ? total : nil
    }

    // MARK: Sample data (debug builds)

    #if DEBUG
    /// Writes a week of realistic Health data so sync can be tested in the simulator.
    func writeSampleData(days: Int = 7) async throws {
        var samples: [HKSample] = []
        let today = Day(.now)
        for offset in 0..<days {
            let day = today.advanced(by: -offset)
            let start = day.startDate
            // Bedtime around 11 pm the night before, 6.5–8.5 hours asleep.
            let bed = start.addingTimeInterval(-3600 + Double.random(in: -1800...1800))
            let wake = bed.addingTimeInterval(Double.random(in: 6.5...8.5) * 3600)
            samples.append(HKCategorySample(
                type: HKCategoryType(.sleepAnalysis),
                value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                start: bed, end: wake
            ))
            guard offset > 0 || Date.now > start.addingTimeInterval(9 * 3600) else { continue }
            let noon = start.addingTimeInterval(12 * 3600)
            samples.append(quantity(.stepCount, .count(), Double.random(in: 5_000...12_000), at: noon))
            samples.append(HKWorkout(
                activityType: .running,
                start: noon, end: noon.addingTimeInterval(Double.random(in: 15...55) * 60)
            ))
            samples.append(quantity(.dietaryWater, .liter(), Double.random(in: 1.2...2.6), at: noon))
            let calm = start.addingTimeInterval(8 * 3600)
            samples.append(HKCategorySample(
                type: HKCategoryType(.mindfulSession),
                value: HKCategoryValue.notApplicable.rawValue,
                start: calm, end: calm.addingTimeInterval(Double.random(in: 5...15) * 60)
            ))
        }
        try await store.save(samples)
    }

    private func quantity(_ id: HKQuantityTypeIdentifier, _ unit: HKUnit, _ value: Double, at date: Date) -> HKQuantitySample {
        HKQuantitySample(type: HKQuantityType(id), quantity: HKQuantity(unit: unit, doubleValue: value), start: date, end: date.addingTimeInterval(60))
    }
    #endif
}

extension Day {
    /// Midnight at the start of this day in the user's calendar.
    var startDate: Date {
        let c = components
        return Calendar.current.date(from: DateComponents(year: c.year, month: c.month, day: c.day)) ?? .now
    }
}
