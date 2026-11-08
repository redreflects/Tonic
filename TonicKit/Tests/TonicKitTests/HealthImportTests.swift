import Testing
@testable import TonicKit

@Suite("Apple Health import")
struct HealthImportTests {
    let sleep = PresetLibrary.core.first { $0.id == "sleep" }!
    let exercise = PresetLibrary.core.first { $0.id == "exercise" }!
    let hydration = PresetLibrary.core.first { $0.id == "hydration" }!
    let steps = PresetLibrary.library.first { $0.id == "steps" }!
    let meditate = PresetLibrary.library.first { $0.id == "meditate" }!

    @Test func mapsEachSupportedHabit() {
        let data = HealthDay(day: monday, sleepHours: 7.46, steps: 8_123.6, exerciseMinutes: 42, mindfulMinutes: 9.6, waterLiters: 1.8)
        #expect(HealthImport.value(for: sleep, from: data) == .amount(7.5))
        #expect(HealthImport.value(for: steps, from: data) == .amount(8_124))
        #expect(HealthImport.value(for: exercise, from: data) == .completed(true))
        #expect(HealthImport.value(for: meditate, from: data) == .amount(10))
        #expect(HealthImport.value(for: hydration, from: data) == .amount(7))
    }

    @Test func emptyOrTinyValuesLogNothing() {
        let data = HealthDay(day: monday, sleepHours: 0.2, steps: 0, exerciseMinutes: 12, mindfulMinutes: 0.4, waterLiters: 0.1)
        for b in [sleep, steps, exercise, meditate, hydration] {
            #expect(HealthImport.value(for: b, from: data) == nil)
        }
        #expect(HealthImport.value(for: sleep, from: HealthDay(day: monday)) == nil)
    }

    @Test func unsupportedHabitsAreIgnored() {
        let custom = check("guitar")
        #expect(HealthImport.value(for: custom, from: HealthDay(day: monday, steps: 10_000)) == nil)
        #expect(HealthImport.supportedBehaviorIDs.allSatisfy { id in PresetLibrary.all.contains { $0.id == id } })
    }

    @Test func overlappingSleepIsNotDoubleCounted() {
        // Watch: 23:00–07:00. Phone: 23:30–06:30 (inside). Nap: 13:00–14:00.
        let h = 3600.0
        let total = HealthImport.mergedDuration([(23 * h, 31 * h), (23.5 * h, 30.5 * h), (37 * h, 38 * h)])
        #expect(total == 9 * h)
        #expect(HealthImport.mergedDuration([]) == 0)
    }
}
