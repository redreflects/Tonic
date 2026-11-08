import Testing
@testable import TonicKit

@Suite("Quests")
struct QuestTests {
    let habits = [check("read", rank: 0, focus: true), avoid("alcohol", rank: 1), volume("study", 60, rank: 2)]

    @Test func threeQuestsAndStablePerWeek() {
        for week in 0..<20 {
            let quests = QuestBoard.quests(forWeek: week, behaviors: habits)
            #expect(quests.count == 3)
            #expect(Set(quests.map(\.id)).count == 3)
            #expect(quests == QuestBoard.quests(forWeek: week, behaviors: habits))
        }
    }

    @Test func questsVaryAcrossWeeks() {
        let titles = Set((0..<12).flatMap { QuestBoard.quests(forWeek: $0, behaviors: habits).map(\.title) })
        #expect(titles.count >= 4)
    }

    @Test func completingAQuestPaysOnceAndShowsProgress() {
        let b = [check("read", rank: 0, focus: true)]
        let logs = daily("read", .completed(true), days: 7)
        let state = replay(b, logs, days: 7)
        let completions = state.days.flatMap(\.events).compactMap { event -> String? in
            if case .questCompleted(let id, _, _) = event { id } else { nil }
        }
        #expect(!completions.isEmpty)
        #expect(Set(completions).count == completions.count) // each quest pays once
        #expect(state.quests.count >= 2)
        #expect(state.quests.allSatisfy { $0.fraction >= 0 && $0.fraction <= 1 })
    }

    @Test func noSlipsQuestOnlyCompletesWhenWeekEnds() {
        let b = [avoid("alcohol")]
        let week = (0..<14).map { QuestBoard.quests(forWeek: monday.advanced(by: $0 * 7).weekIndex, behaviors: b) }
        guard let offset = week.firstIndex(where: { $0.contains { $0.goal == .noSlips } }) else {
            Issue.record("expected a no-slips quest within 14 weeks")
            return
        }
        let start = monday.advanced(by: offset * 7)
        let logs = daily("alcohol", .slipped(false), days: 7, from: start)
        let state = ProgressionEngine().replay(behaviors: b, logs: logs, from: start, through: start.advanced(by: 6), pendingDays: 0)
        let completedOn = state.days.firstIndex { $0.events.contains { if case .questCompleted(_, "Zero slips all week", _) = $0 { true } else { false } } }
        #expect(completedOn == 6)
    }
}

@Suite("Achievements and stats")
struct AchievementTests {
    @Test func unlocksInOrder() {
        let b = [check("read")]
        let state = replay(b, daily("read", .completed(true), days: 31), days: 31)
        let earned = Achievements.unlocked(in: state, behaviors: b)
        #expect(earned["first_step"] == monday)
        #expect(earned["flawless"] == monday)
        #expect(earned["week_warrior"] == monday.advanced(by: 6))
        #expect(earned["habit_formed"] == monday.advanced(by: 29))
        #expect(earned["showing_up"] == monday.advanced(by: 29))
        #expect(earned["unstoppable"] == nil)
        #expect(earned["clean_month"] == nil)
    }

    @Test func cleanMonthNeedsAnAvoidHabit() {
        let b = [avoid("alcohol")]
        let state = replay(b, daily("alcohol", .slipped(false), days: 30), days: 30)
        #expect(Achievements.unlocked(in: state, behaviors: b)["clean_month"] == monday.advanced(by: 29))
    }

    @Test func achievementIDsAreUnique() {
        #expect(Set(Achievements.all.map(\.id)).count == Achievements.all.count)
    }

    @Test func characterStatsByCategory() {
        let b = [check("read"), avoid("alcohol")] // read = mind, alcohol = body
        let logs = daily("read", .completed(true), days: 4) + daily("alcohol", .slipped(true), days: 2)
            + daily("alcohol", .slipped(false), days: 2, from: monday.advanced(by: 2))
        let stats = CharacterStats.compute(days: replay(b, logs, days: 4).days, behaviors: b)
        #expect(stats[.mind] == 100)
        #expect(stats[.body] == 50)
        #expect(stats[.social] == nil)
    }

    @Test func weekAndMonthSummaries() {
        let b = [check("read")]
        let logs = daily("read", .completed(true), days: 7) + daily("read", .completed(true), days: 3, from: monday.advanced(by: 7))
        let state = replay(b, logs, days: 14)
        let first = PeriodSummary.week(monday.weekIndex, in: state)
        let second = PeriodSummary.week(monday.weekIndex + 1, in: state)
        #expect(first.days == 7 && first.strongDays == 7)
        #expect(second.strongDays == 3)
        #expect(first.averageScore > second.averageScore)
    }

    @Test func dayComponentsRoundTrip() {
        for (y, m, d) in [(1970, 1, 1), (2024, 2, 29), (2026, 12, 31), (1999, 3, 1)] {
            let c = Day(year: y, month: m, day: d).components
            #expect(c.year == y && c.month == m && c.day == d)
        }
        #expect(Day(year: 2026, month: 1, day: 31).monthKey + 1 == Day(year: 2026, month: 2, day: 1).monthKey)
    }
}
