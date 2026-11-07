import Testing
@testable import TonicKit

@Suite("Days")
struct DayTests {
    @Test func knownDates() {
        #expect(Day(year: 1970, month: 1, day: 1).index == 0)
        #expect(Day(year: 2026, month: 1, day: 5).weekday == 0) // Monday
        #expect(Day(year: 2026, month: 1, day: 11).isLastDayOfWeek) // Sunday
        #expect(Day(year: 2024, month: 3, day: 1).index - Day(year: 2024, month: 2, day: 28).index == 2) // leap year
    }

    @Test func weekBoundaries() {
        #expect(monday.weekIndex == monday.advanced(by: 6).weekIndex)
        #expect(monday.weekIndex + 1 == monday.advanced(by: 7).weekIndex)
    }
}

@Suite("Quality")
struct QualityTests {
    @Test func checkBehavior() {
        let b = check("meditate")
        #expect(Quality.evaluate(b, .completed(true)).quality == 1)
        #expect(Quality.evaluate(b, .completed(true)).hit)
        #expect(Quality.evaluate(b, .completed(false)).quality == 0)
        #expect(!Quality.evaluate(b, nil).logged)
    }

    @Test func avoidSlipIsDoublePenalty() {
        let b = avoid("alcohol")
        let clean = Quality.evaluate(b, .slipped(false))
        let slip = Quality.evaluate(b, .slipped(true))
        #expect(clean.quality == 1 && clean.hit)
        #expect(slip.quality == -2 && slip.slipped && !slip.hit)
    }

    @Test func targetGivesPartialCredit() {
        let water = target("water", 8)
        #expect(Quality.evaluate(water, .amount(4)).quality == 0.5)
        #expect(!Quality.evaluate(water, .amount(4)).hit)
        #expect(Quality.evaluate(water, .amount(7)).hit) // 87.5% counts as a hit
        #expect(Quality.evaluate(water, .amount(12)).quality == 1)
    }

    @Test func atMostTarget() {
        let screen = target("screen", 3, direction: .atMost)
        #expect(Quality.evaluate(screen, .amount(2)).quality == 1)
        #expect(Quality.evaluate(screen, .amount(4.5)).quality == 0.5)
        #expect(Quality.evaluate(screen, .amount(9)).quality == 0)
    }

    @Test func sleepCombinesParts() {
        #expect(SleepScoring.quality(hoursSlept: 8) == 1)
        #expect(SleepScoring.quality(hoursSlept: 6) == 0.75)
        let q = SleepScoring.quality(hoursSlept: 8, bedtimeDeviationMinutes: 75, restedRating: 3)
        #expect(abs(q - (1 + 0.5 + 0.5) / 3) < 1e-9)
    }
}

@Suite("Weighting")
struct WeightingTests {
    @Test func weightsSumToOne() {
        let w = Weighting.normalizedWeights(for: [check("a", rank: 0), check("b", rank: 1), check("c", rank: 2, focus: true)])
        #expect(abs(w.values.reduce(0, +) - 1) < 1e-9)
    }

    @Test func higherRankWeighsMore() {
        let w = Weighting.normalizedWeights(for: [check("a", rank: 0), check("b", rank: 1), check("c", rank: 2)])
        #expect(w["a"]! > w["b"]! && w["b"]! > w["c"]!)
        #expect(abs(w["a"]! / w["c"]! - 2) < 1e-9) // 1.5 vs 0.75
    }

    @Test func focusBoostsWeight() {
        let plain = Weighting.normalizedWeights(for: [check("a", rank: 0), check("b", rank: 1), check("c", rank: 2)])
        let focused = Weighting.normalizedWeights(for: [check("a", rank: 0), check("b", rank: 1, focus: true), check("c", rank: 2)])
        #expect(focused["b"]! > plain["b"]!)
        // Same rank: Focus is worth 1.5x.
        #expect(abs(focused["b"]! / focused["c"]! - 1.5 * plain["b"]! / plain["c"]!) < 1e-9)
    }

    @Test func perfectDayIsAlways100() {
        for count in [1, 3, 10] {
            let behaviors = (0..<count).map { check("b\($0)", rank: $0) }
            let logs = behaviors.flatMap { daily($0.id, .completed(true), days: 1) }
            #expect(abs(replay(behaviors, logs, days: 1).days[0].score - 100) < 1e-9)
        }
    }
}

@Suite("Levels and ranks")
struct LevelTests {
    @Test func levelsGetHarder() {
        let curve = LevelCurve()
        for level in 1..<80 {
            #expect(curve.xpToAdvance(from: level + 1) > curve.xpToAdvance(from: level))
        }
    }

    @Test func levelForXPRoundTrips() {
        let curve = LevelCurve()
        for level in [1, 2, 9, 10, 35, 70] {
            let start = curve.totalXP(toReach: level)
            #expect(curve.level(forTotalXP: start) == level)
            #expect(curve.level(forTotalXP: start + curve.xpToAdvance(from: level) - 0.001) == level)
        }
    }

    @Test func rankThemes() {
        #expect(RankTheme.plant.rank(forLevel: 1).name == "Seedling")
        #expect(RankTheme.plant.rank(forLevel: 9).name == "Seedling")
        #expect(RankTheme.plant.rank(forLevel: 10).name == "Sprout")
        #expect(RankTheme.frat.rank(forLevel: 1).name == "Potential New Member")
        #expect(RankTheme.frat.rank(forLevel: 35).name == "Brother")
        #expect(RankTheme.frat.rank(forLevel: 70).name == "President")
        #expect(RankTheme.frat.rank(forLevel: 250).name == "President")
        #expect(RankTheme.plant.nextRankLevel(after: 12) == 20)
        #expect(RankTheme.plant.nextRankLevel(after: 75) == nil)
        #expect(RankTheme.all.allSatisfy { $0.rankNames.count == 8 })
    }

    @Test func presetsAreValid() {
        let ids = PresetLibrary.all.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(PresetLibrary.core.allSatisfy { $0.isCore && $0.isEnabled })
        #expect(PresetLibrary.library.allSatisfy { !$0.isEnabled })
        #expect(PresetLibrary.all.filter { $0.kind == .target || $0.kind == .volume }.allSatisfy { ($0.target ?? 0) > 0 })
    }
}
