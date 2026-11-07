import Foundation

/// Something worth celebrating (or flagging) in the UI.
public enum ProgressEvent: Hashable, Sendable {
    case levelUp(level: Int)
    case rankUp(tier: Int)
    case perfectFocusDay
    case comboWeek
    case streakShieldEarned(behaviorID: String)
    case streakShieldUsed(behaviorID: String)
    case streakRecord(behaviorID: String, days: Int)
    case comeback(behaviorID: String)
    case slipped(behaviorID: String)
    case bestDay(behaviorID: String, amount: Double)
    case bestWeek(behaviorID: String, amount: Double)
}

/// Running stats for one behavior.
public struct BehaviorProgress: Hashable, Sendable {
    public var streak = 0
    public var bestStreak = 0
    public var shields = 0
    public var totalSlips = 0
    /// Volume behaviors: largest single-day amount.
    public var bestDay = 0.0
    /// Volume behaviors: largest Monday–Sunday total.
    public var bestWeek = 0.0
    public var currentWeekTotal = 0.0

    var comebackPending = false
    var streakRecordAnnounced = false

    public init() {}
}

public struct DayResult: Hashable, Sendable {
    public let day: Day
    /// −100 to 100. A perfect day is 100.
    public let score: Double
    /// XP earned (or lost) this day, before the level floor is applied.
    public let xp: Double
    /// The day is still open for logging, so missing entries didn't count against streaks.
    public let isPending: Bool
    public let events: [ProgressEvent]
}

public struct ProgressionState: Hashable, Sendable {
    public var totalXP: Double = 0
    public var level: Int = 1
    public var behaviors: [String: BehaviorProgress] = [:]
    public var days: [DayResult] = []
    public var curve: LevelCurve = LevelCurve()

    public var xpIntoLevel: Double { totalXP - curve.totalXP(toReach: level) }
    public var xpForNextLevel: Double { curve.xpToAdvance(from: level) }
    /// 0–1 progress toward the next level, for the XP bar.
    public var levelProgress: Double { min(max(xpIntoLevel / xpForNextLevel, 0), 1) }
}

/// Computes the user's whole progression by replaying their logs one day at a time.
///
/// Replaying from scratch keeps things simple and correct: editing an old log just
/// means replaying again. A year of logs takes well under a millisecond per day.
public struct ProgressionEngine: Sendable {
    public var tuning: Tuning

    public init(tuning: Tuning = .standard) {
        self.tuning = tuning
    }

    /// - Parameters:
    ///   - pendingDays: How many days at the end are still open for logging. Missing
    ///     entries on these days don't break streaks yet. Use 1 for "today", or 2
    ///     before noon so yesterday can still be filled in (the grace window).
    public func replay(
        behaviors: [Behavior],
        logs: [LogEntry],
        from start: Day,
        through end: Day,
        pendingDays: Int = 1
    ) -> ProgressionState {
        var state = ProgressionState(curve: tuning.levelCurve)
        let active = behaviors.filter(\.isEnabled)
        for behavior in active { state.behaviors[behavior.id] = BehaviorProgress() }
        guard start <= end else { return state }

        // Later entries for the same behavior and day replace earlier ones.
        var logIndex: [String: [Day: LogValue]] = [:]
        for entry in logs { logIndex[entry.behaviorID, default: [:]][entry.day] = entry.value }

        let firstPendingDay = end.advanced(by: 1 - max(pendingDays, 0))
        var comboDays = 0

        for day in start...end {
            let isPending = day >= firstPendingDay
            let todays = active.filter { ($0.startDay ?? start) <= day }
            let weights = Weighting.normalizedWeights(for: todays, tuning: tuning)

            var events: [ProgressEvent] = []
            var score = 0.0
            var positiveXP = 0.0
            /// The extra XP from streak multipliers, kept apart so a slip can cancel it.
            var streakBonusXP = 0.0
            var negativeXP = 0.0
            var bonusXP = 0.0
            var anySlip = false
            let focusCount = todays.filter(\.isFocus).count
            var focusHits = 0

            for behavior in todays {
                let weight = weights[behavior.id] ?? 0
                let points = 100 * weight
                let outcome = Quality.evaluate(behavior, logIndex[behavior.id]?[day], tuning: tuning)
                var p = state.behaviors[behavior.id] ?? BehaviorProgress()

                score += points * outcome.quality

                if outcome.slipped {
                    anySlip = true
                    negativeXP += points * outcome.quality
                    p.streak = 0
                    p.streakRecordAnnounced = false
                    p.comebackPending = true
                    p.totalSlips += 1
                    events.append(.slipped(behaviorID: behavior.id))
                } else if outcome.hit {
                    p.streak += 1
                    if p.streak > p.bestStreak {
                        if p.bestStreak >= tuning.streakRecordMinimum && !p.streakRecordAnnounced {
                            p.streakRecordAnnounced = true
                            events.append(.streakRecord(behaviorID: behavior.id, days: p.streak))
                        }
                        p.bestStreak = p.streak
                    }
                    if p.streak % tuning.shieldEveryDays == 0 && p.shields < tuning.maxShields {
                        p.shields += 1
                        events.append(.streakShieldEarned(behaviorID: behavior.id))
                    }
                    let base = points * outcome.quality
                    positiveXP += base
                    streakBonusXP += base * (tuning.streakMultiplier(forStreak: p.streak) - 1)
                    if behavior.isFocus { focusHits += 1 }
                    if behavior.kind == .avoid && p.comebackPending {
                        p.comebackPending = false
                        bonusXP += tuning.comebackBonusXP
                        events.append(.comeback(behaviorID: behavior.id))
                    }
                } else {
                    // Missed or only partly done. Partial credit still earns some XP.
                    positiveXP += points * max(outcome.quality, 0)
                    let stillOpen = isPending && !outcome.logged
                    if !stillOpen && p.streak > 0 {
                        if p.shields > 0 {
                            p.shields -= 1
                            events.append(.streakShieldUsed(behaviorID: behavior.id))
                        } else {
                            p.streak = 0
                            p.streakRecordAnnounced = false
                        }
                    }
                }

                if behavior.kind == .volume, let amount = outcome.amount, amount > 0 {
                    if amount > p.bestDay {
                        if p.bestDay > 0 {
                            bonusXP += tuning.personalRecordBonusXP
                            events.append(.bestDay(behaviorID: behavior.id, amount: amount))
                        }
                        p.bestDay = amount
                    }
                    if let target = behavior.target, target > 0, amount > target {
                        // More is always better, with diminishing returns.
                        bonusXP += points * tuning.volumeOverflowFactor * log2(amount / target)
                    }
                    p.currentWeekTotal += amount
                }

                state.behaviors[behavior.id] = p
            }

            // Any slip wipes out the day's streak bonuses, so a slip always costs real XP.
            if !(anySlip && tuning.slipCancelsStreakBonus) {
                positiveXP += streakBonusXP
            }

            if focusCount > 0 && focusHits == focusCount && !anySlip {
                positiveXP *= tuning.perfectFocusMultiplier
                events.append(.perfectFocusDay)
            }

            score = min(max(score, -100), 100)
            if !isPending && score >= tuning.comboWeekScoreThreshold { comboDays += 1 }

            if day.isLastDayOfWeek {
                if !isPending {
                    if comboDays >= tuning.comboWeekDaysRequired {
                        bonusXP += tuning.comboWeekBonusXP
                        events.append(.comboWeek)
                    }
                    for behavior in todays where behavior.kind == .volume {
                        guard var p = state.behaviors[behavior.id] else { continue }
                        if p.currentWeekTotal > p.bestWeek {
                            if p.bestWeek > 0 {
                                bonusXP += tuning.personalRecordBonusXP
                                events.append(.bestWeek(behaviorID: behavior.id, amount: p.currentWeekTotal))
                            }
                            p.bestWeek = p.currentWeekTotal
                        }
                        state.behaviors[behavior.id] = p
                    }
                }
                comboDays = 0
                for id in state.behaviors.keys { state.behaviors[id]?.currentWeekTotal = 0 }
            }

            let dayXP = positiveXP + negativeXP + bonusXP

            // XP can fall, but never below the start of the current level.
            let levelFloor = tuning.levelCurve.totalXP(toReach: state.level)
            state.totalXP = max(levelFloor, state.totalXP + dayXP)
            let newLevel = tuning.levelCurve.level(forTotalXP: state.totalXP)
            if newLevel > state.level {
                events.append(.levelUp(level: newLevel))
                let oldTier = RankTheme.tier(forLevel: state.level)
                let newTier = RankTheme.tier(forLevel: newLevel)
                if newTier > oldTier { events.append(.rankUp(tier: newTier)) }
                state.level = newLevel
            }

            state.days.append(DayResult(day: day, score: score, xp: dayXP, isPending: isPending, events: events))
        }

        return state
    }
}
