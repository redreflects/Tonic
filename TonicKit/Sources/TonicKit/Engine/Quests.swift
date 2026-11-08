import Foundation

/// What a weekly quest asks for.
public enum QuestGoal: Hashable, Sendable {
    /// Hit one habit on this many days this week.
    case hitDays(behaviorID: String, days: Int)
    /// Score at least `minScore` on this many days.
    case strongDays(minScore: Double, days: Int)
    /// Hit every Focus habit (without slipping) on this many days.
    case perfectFocusDays(Int)
    /// No slips on any avoid habit all week. Completes when the week ends.
    case noSlips
    /// Log at least this much of a volume habit this week.
    case weeklyVolume(behaviorID: String, amount: Double)
}

public struct Quest: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let icon: String
    public let goal: QuestGoal
    public let rewardXP: Double
}

public struct QuestProgress: Identifiable, Hashable, Sendable {
    public let quest: Quest
    public let current: Double
    public let target: Double
    public let isComplete: Bool

    public var id: String { quest.id }
    public var fraction: Double { target > 0 ? min(current / target, 1) : 0 }
}

/// Running totals for the current week, used to check quest progress.
struct WeekStats {
    var hits: [String: Int] = [:]
    var volume: [String: Double] = [:]
    var strongDays: [Double: Int] = [:]
    var perfectFocusDays = 0
    var slips = 0
    var completed: Set<String> = []
}

/// Picks three quests per week. The choice depends only on the week and your habits,
/// so replaying history always gives the same quests.
public enum QuestBoard {
    public static func quests(forWeek week: Int, behaviors: [Behavior]) -> [Quest] {
        var rng = SeededGenerator(seed: UInt64(bitPattern: Int64(week)) &* 0x9E37_79B9_7F4A_7C15 &+ 1)
        let ranked = behaviors.sorted { ($0.priorityRank, $0.name) < ($1.priorityRank, $1.name) }
        var quests: [Quest] = []
        func id(_ n: Int) -> String { "w\(week)-\(n)" }

        // 1. Hit a habit on 4–5 days (prefer Focus habits, skip avoid habits).
        let positive = ranked.filter { $0.kind != .avoid }
        let focus = positive.filter(\.isFocus)
        var firstPickID: String?
        if let pick = (focus.isEmpty ? positive : focus).randomElement(using: &rng) {
            firstPickID = pick.id
            let days = Int.random(in: 4...5, using: &rng)
            quests.append(Quest(
                id: id(1), title: hitTitle(pick, days: days), icon: pick.icon,
                goal: .hitDays(behaviorID: pick.id, days: days), rewardXP: Double(days) * 15
            ))
        }

        // 2. Strong days or Perfect Focus Days, alternating by week.
        if !behaviors.filter(\.isFocus).isEmpty && week % 2 == 0 {
            quests.append(Quest(
                id: id(2), title: "3 Perfect Focus Days", icon: "star.circle.fill",
                goal: .perfectFocusDays(3), rewardXP: 90
            ))
        } else {
            quests.append(Quest(
                id: id(2), title: "Score 80+ on 4 days", icon: "chart.bar.fill",
                goal: .strongDays(minScore: 80, days: 4), rewardXP: 80
            ))
        }

        // 3. Zero slips, a volume total, or another habit.
        let volumes = positive.filter { $0.kind == .volume && ($0.target ?? 0) > 0 }
        if behaviors.contains(where: { $0.kind == .avoid }) && (volumes.isEmpty || week % 3 != 1) {
            quests.append(Quest(
                id: id(3), title: "Zero slips all week", icon: "shield.checkered",
                goal: .noSlips, rewardXP: 100
            ))
        } else if let pick = volumes.randomElement(using: &rng), let target = pick.target {
            let amount = (target * 5).rounded()
            let unit = pick.unit.map { " \($0)" } ?? ""
            quests.append(Quest(
                id: id(3), title: "Log \(formatted(amount))\(unit) of \(pick.name) this week", icon: pick.icon,
                goal: .weeklyVolume(behaviorID: pick.id, amount: amount), rewardXP: 80
            ))
        } else if let pick = positive.filter({ $0.id != firstPickID }).randomElement(using: &rng) {
            quests.append(Quest(
                id: id(3), title: hitTitle(pick, days: 5), icon: pick.icon,
                goal: .hitDays(behaviorID: pick.id, days: 5), rewardXP: 75
            ))
        }
        return quests
    }

    static func progress(_ quest: Quest, stats: WeekStats, weekFinished: Bool) -> QuestProgress {
        let (current, target): (Double, Double)
        var complete: Bool
        switch quest.goal {
        case .hitDays(let id, let days):
            (current, target) = (Double(stats.hits[id] ?? 0), Double(days))
            complete = current >= target
        case .strongDays(let minScore, let days):
            (current, target) = (Double(stats.strongDays[minScore] ?? 0), Double(days))
            complete = current >= target
        case .perfectFocusDays(let days):
            (current, target) = (Double(stats.perfectFocusDays), Double(days))
            complete = current >= target
        case .noSlips:
            (current, target) = (Double(stats.slips), 0)
            complete = weekFinished && stats.slips == 0
        case .weeklyVolume(let id, let amount):
            (current, target) = (stats.volume[id] ?? 0, amount)
            complete = current >= target
        }
        complete = complete || stats.completed.contains(quest.id)
        return QuestProgress(quest: quest, current: current, target: target, isComplete: complete)
    }

    private static func hitTitle(_ b: Behavior, days: Int) -> String {
        switch b.kind {
        case .check: "\(b.name) on \(days) days"
        case .target where b.direction == .atMost: "Stay under your \(b.name) limit \(days) days"
        case .target: "Hit your \(b.name) goal \(days) days"
        case .volume: "Full credit on \(b.name) \(days) days"
        case .avoid: "\(days) clean days of \(b.name)"
        }
    }

    private static func formatted(_ x: Double) -> String {
        x.formatted(.number.precision(.fractionLength(0...1)))
    }
}

/// Small deterministic random generator (SplitMix64).
struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
