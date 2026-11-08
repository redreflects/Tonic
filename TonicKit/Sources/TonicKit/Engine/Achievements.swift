import Foundation

/// A badge you earn once.
public struct Achievement: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let icon: String
}

public enum Achievements {
    public static let all: [Achievement] = [
        .init(id: "first_step", title: "First Step", detail: "Log your first day", icon: "shoeprints.fill"),
        .init(id: "showing_up", title: "Showing Up", detail: "Log 30 different days", icon: "calendar"),
        .init(id: "flawless", title: "Flawless", detail: "Score 100 in a day", icon: "sparkles"),
        .init(id: "week_warrior", title: "Week Warrior", detail: "7-day streak on any habit", icon: "flame"),
        .init(id: "habit_formed", title: "Habit Formed", detail: "30-day streak on any habit", icon: "flame.fill"),
        .init(id: "unstoppable", title: "Unstoppable", detail: "100-day streak on any habit", icon: "bolt.fill"),
        .init(id: "clean_month", title: "Clean Month", detail: "30 clean days in a row on a habit you're avoiding", icon: "leaf.fill"),
        .init(id: "locked_in", title: "Locked In", detail: "10 Perfect Focus Days", icon: "scope"),
        .init(id: "on_a_roll", title: "On a Roll", detail: "Earn a combo week", icon: "flame.circle.fill"),
        .init(id: "consistency", title: "Consistency King", detail: "Earn 4 combo weeks", icon: "crown.fill"),
        .init(id: "record_breaker", title: "Record Breaker", detail: "Set a personal record", icon: "trophy.fill"),
        .init(id: "pr_machine", title: "PR Machine", detail: "Set 10 personal records", icon: "trophy.circle.fill"),
        .init(id: "bounce_back", title: "Bounce Back", detail: "Earn a comeback after a slip", icon: "arrow.uturn.up.circle.fill"),
        .init(id: "saved", title: "Saved by the Shield", detail: "A streak shield saves your streak", icon: "shield.lefthalf.filled"),
        .init(id: "quest_taker", title: "Quest Taker", detail: "Complete a weekly quest", icon: "map.fill"),
        .init(id: "quest_master", title: "Quest Master", detail: "Complete 10 weekly quests", icon: "map.circle.fill"),
        .init(id: "double_digits", title: "Double Digits", detail: "Reach level 10", icon: "10.circle.fill"),
        .init(id: "quarter_century", title: "Quarter Century", detail: "Reach level 25", icon: "25.circle.fill"),
        .init(id: "halfway_legend", title: "Halfway Legend", detail: "Reach level 50", icon: "50.circle.fill"),
        .init(id: "ten_k", title: "10K Club", detail: "Earn 10,000 XP", icon: "star.circle.fill"),
    ]

    /// Every unlocked achievement and the day it was earned.
    public static func unlocked(in state: ProgressionState, behaviors: [Behavior]) -> [String: Day] {
        let avoidIDs = Set(behaviors.filter { $0.kind == .avoid }.map(\.id))
        var earned: [String: Day] = [:]
        var loggedDays = 0, perfectFocus = 0, combos = 0, records = 0, quests = 0

        func unlock(_ id: String, _ condition: Bool, _ day: Day) {
            if condition && earned[id] == nil { earned[id] = day }
        }

        for result in state.days {
            let day = result.day
            if result.score > 0 { loggedDays += 1 }
            for event in result.events {
                switch event {
                case .perfectFocusDay: perfectFocus += 1
                case .comboWeek: combos += 1
                case .bestDay, .bestWeek: records += 1
                case .questCompleted: quests += 1
                case .comeback: unlock("bounce_back", true, day)
                case .streakShieldUsed: unlock("saved", true, day)
                default: break
                }
            }
            let longest = result.streaks.values.max() ?? 0
            let longestClean = result.streaks.filter { avoidIDs.contains($0.key) }.values.max() ?? 0

            unlock("first_step", loggedDays >= 1, day)
            unlock("showing_up", loggedDays >= 30, day)
            unlock("flawless", result.score >= 99.5, day)
            unlock("week_warrior", longest >= 7, day)
            unlock("habit_formed", longest >= 30, day)
            unlock("unstoppable", longest >= 100, day)
            unlock("clean_month", longestClean >= 30, day)
            unlock("locked_in", perfectFocus >= 10, day)
            unlock("on_a_roll", combos >= 1, day)
            unlock("consistency", combos >= 4, day)
            unlock("record_breaker", records >= 1, day)
            unlock("pr_machine", records >= 10, day)
            unlock("quest_taker", quests >= 1, day)
            unlock("quest_master", quests >= 10, day)
            unlock("double_digits", result.level >= 10, day)
            unlock("quarter_century", result.level >= 25, day)
            unlock("halfway_legend", result.level >= 50, day)
            unlock("ten_k", result.totalXP >= 10_000, day)
        }
        return earned
    }
}

/// How strong each life area is lately: average quality of its habits, 0–100.
public enum CharacterStats {
    /// Finished days only. Slips count as 0. Areas with no habits are left out.
    public static func compute(days: [DayResult], behaviors: [Behavior], window: Int = 30) -> [BehaviorCategory: Double] {
        let category = Dictionary(behaviors.map { ($0.id, $0.category) }, uniquingKeysWith: { first, _ in first })
        var sums: [BehaviorCategory: (total: Double, count: Int)] = [:]
        for result in days.filter({ !$0.isPending }).suffix(window) {
            for (id, quality) in result.qualities {
                guard let c = category[id] else { continue }
                sums[c, default: (0, 0)].total += max(quality, 0)
                sums[c, default: (0, 0)].count += 1
            }
        }
        return sums.compactMapValues { $0.count > 0 ? 100 * $0.total / Double($0.count) : nil }
    }
}

/// Totals for a stretch of days, for "this week vs last week" comparisons.
public struct PeriodSummary: Hashable, Sendable {
    public let days: Int
    public let averageScore: Double
    public let xp: Double
    public let strongDays: Int
    public let perfectFocusDays: Int
    public let slips: Int
    public let questsCompleted: Int

    public init(_ results: [DayResult], strongScore: Double = 80) {
        days = results.count
        averageScore = results.isEmpty ? 0 : results.map(\.score).reduce(0, +) / Double(results.count)
        xp = results.map(\.xp).reduce(0, +)
        strongDays = results.filter { $0.score >= strongScore }.count
        let events = results.flatMap(\.events)
        perfectFocusDays = events.filter { $0 == .perfectFocusDay }.count
        slips = events.filter { if case .slipped = $0 { true } else { false } }.count
        questsCompleted = events.filter { if case .questCompleted = $0 { true } else { false } }.count
    }

    public static func week(_ weekIndex: Int, in state: ProgressionState) -> PeriodSummary {
        PeriodSummary(state.days.filter { $0.day.weekIndex == weekIndex })
    }

    /// Calendar month containing `day`.
    public static func month(of day: Day, in state: ProgressionState) -> PeriodSummary {
        let key = day.monthKey
        return PeriodSummary(state.days.filter { $0.day.monthKey == key })
    }

    /// The best finished month by average score (at least `minimumDays` logged).
    public static func bestMonth(in state: ProgressionState, before day: Day, minimumDays: Int = 7) -> (key: Int, summary: PeriodSummary)? {
        let current = day.monthKey
        let grouped = Dictionary(grouping: state.days.filter { $0.day.monthKey < current }, by: \.day.monthKey)
        return grouped
            .filter { $0.value.count >= minimumDays }
            .map { (key: $0.key, summary: PeriodSummary($0.value)) }
            .max { $0.summary.averageScore < $1.summary.averageScore }
    }
}

extension Day {
    /// Civil date for this day (inverse of `init(year:month:day:)`).
    public var components: (year: Int, month: Int, day: Int) {
        let z = index + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        return (yoe + era * 400 + (m <= 2 ? 1 : 0), m, d)
    }

    /// Same number for every day in a calendar month; increases month to month.
    public var monthKey: Int {
        let c = components
        return c.year * 12 + c.month - 1
    }
}
