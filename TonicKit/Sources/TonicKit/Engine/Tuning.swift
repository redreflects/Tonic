import Foundation

/// Every number that shapes how Tonic feels, in one place.
///
/// Change values here (and re-run the pacing simulation test) to rebalance the game.
public struct Tuning: Sendable, Hashable {
    // MARK: Priority weighting
    /// Weight of the #1 ranked behavior. Ranks between top and bottom are spaced evenly.
    public var topRankWeight = 1.5
    /// Weight of the lowest ranked behavior.
    public var bottomRankWeight = 0.75
    /// Extra multiplier for the user's 2–3 Focus habits.
    public var focusMultiplier = 1.5

    // MARK: Daily outcome
    /// Quality needed for a day to count as a "hit" (keeps a streak going).
    public var hitThreshold = 0.8
    /// A slip on an avoid behavior costs this many times the behavior's normal max points.
    public var slipPenalty = 2.0
    /// When anything slips, no behavior gets its streak bonus that day (streaks themselves are kept).
    public var slipCancelsStreakBonus = true

    // MARK: Compounding
    /// Extra XP per consecutive streak day (0.05 = +5%).
    public var streakBonusPerDay = 0.05
    /// The streak bonus stops growing after this many days (+100% at 20 days).
    public var streakBonusCapDays = 20
    /// XP multiplier when every Focus habit is hit and nothing slipped.
    public var perfectFocusMultiplier = 1.25
    /// Bonus XP per unit of log2(amount / target) when a volume behavior beats its target.
    public var volumeOverflowFactor = 0.5

    // MARK: Weekly combo
    public var comboWeekScoreThreshold = 70.0
    public var comboWeekDaysRequired = 5
    public var comboWeekBonusXP = 150.0

    // MARK: Recovery and records
    /// A streak shield is earned every this many streak days.
    public var shieldEveryDays = 7
    public var maxShields = 2
    /// First clean day after a slip.
    public var comebackBonusXP = 25.0
    /// Beating a best day or best week on a volume behavior.
    public var personalRecordBonusXP = 25.0
    /// A new longest streak is only celebrated once the old best was at least this long.
    public var streakRecordMinimum = 7

    // MARK: Levels
    public var levelCurve = LevelCurve()

    public init() {}

    public static let standard = Tuning()

    /// XP multiplier for a behavior on its `streak`-th consecutive day.
    public func streakMultiplier(forStreak streak: Int) -> Double {
        1 + streakBonusPerDay * Double(min(max(streak - 1, 0), streakBonusCapDays))
    }
}
