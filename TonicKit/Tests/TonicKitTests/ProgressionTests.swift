import Testing
@testable import TonicKit

@Suite("Progression")
struct ProgressionTests {
    @Test func streaksCompoundXP() {
        let b = [check("read")]
        let state = replay(b, daily("read", .completed(true), days: 25), days: 25)
        #expect(state.behaviors["read"]!.streak == 25)
        #expect(state.days[0].xp == 100)
        #expect(abs(state.days[10].xp - 150) < 1e-9) // day 11: +50%
        #expect(abs(state.days[24].xp - 200) < 1e-9) // capped at +100%
    }

    @Test func slipCostsDoubleAndResetsStreak() {
        let b = [avoid("alcohol", rank: 0), check("read", rank: 1)]
        var logs = daily("alcohol", .slipped(false), days: 3) + daily("read", .completed(true), days: 4)
        logs.append(LogEntry(behaviorID: "alcohol", day: monday.advanced(by: 3), value: .slipped(true)))
        let state = replay(b, logs, days: 4)

        let slipDay = state.days[3]
        #expect(slipDay.score < 0) // the slip outweighs the habit that was done
        #expect(slipDay.events.contains(.slipped(behaviorID: "alcohol")))
        #expect(state.behaviors["alcohol"]!.streak == 0)
        #expect(state.behaviors["read"]!.streak == 4)
    }

    @Test func slipCancelsStreakBonusesThatDay() {
        // Read is #1 (2/3 weight), alcohol #2 (1/3 weight).
        let b = [check("read", rank: 0), avoid("alcohol", rank: 1)]
        var logs = daily("read", .completed(true), days: 26) + daily("alcohol", .slipped(false), days: 25)
        logs.append(LogEntry(behaviorID: "alcohol", day: monday.advanced(by: 25), value: .slipped(true)))

        let slipDay = replay(b, logs, days: 26).days[25]
        // Read earns its plain 66.7 points (no 2x streak bonus); the slip costs 2 x 33.3.
        #expect(abs(slipDay.xp) < 1e-9)
        #expect(ProgressionEngine().replay(behaviors: b, logs: logs, from: monday, through: monday.advanced(by: 25), pendingDays: 0)
            .behaviors["read"]!.streak == 26) // the streak itself survives

        var lenient = Tuning.standard
        lenient.slipCancelsStreakBonus = false
        let oldRules = ProgressionEngine(tuning: lenient)
            .replay(behaviors: b, logs: logs, from: monday, through: monday.advanced(by: 25), pendingDays: 0)
        #expect(oldRules.days[25].xp > 60) // what used to happen
    }

    @Test func comebackBonusAfterSlip() {
        let b = [avoid("alcohol")]
        let logs = [
            LogEntry(behaviorID: "alcohol", day: monday, value: .slipped(true)),
            LogEntry(behaviorID: "alcohol", day: monday.advanced(by: 1), value: .slipped(false)),
            LogEntry(behaviorID: "alcohol", day: monday.advanced(by: 2), value: .slipped(false)),
        ]
        let state = replay(b, logs, days: 3)
        #expect(state.days[1].events.contains(.comeback(behaviorID: "alcohol")))
        #expect(!state.days[2].events.contains(.comeback(behaviorID: "alcohol")))
    }

    @Test func levelNeverDrops() {
        let b = [avoid("alcohol")]
        // Clean long enough to level up, then a run of slips.
        let clean = daily("alcohol", .slipped(false), days: 10)
        let slips = daily("alcohol", .slipped(true), days: 10, from: monday.advanced(by: 10))
        let state = replay(b, clean + slips, days: 20)
        let peak = state.days.prefix(10).reduce(1) { level, day in
            day.events.compactMap { if case .levelUp(let l) = $0 { l } else { nil } }.max() ?? level
        }
        #expect(peak > 1)
        #expect(state.level == peak)
        #expect(state.totalXP == LevelCurve().totalXP(toReach: peak))
    }

    @Test func shieldProtectsAMissedDay() {
        let b = [check("read")]
        var logs = daily("read", .completed(true), days: 7)
        // Day 8 missed, day 9 done.
        logs.append(LogEntry(behaviorID: "read", day: monday.advanced(by: 8), value: .completed(true)))
        let state = replay(b, logs, days: 9)

        #expect(state.days[6].events.contains(.streakShieldEarned(behaviorID: "read")))
        #expect(state.days[7].events.contains(.streakShieldUsed(behaviorID: "read")))
        #expect(state.behaviors["read"]!.streak == 8)
        #expect(state.behaviors["read"]!.shields == 0)
    }

    @Test func missedDayWithoutShieldBreaksStreak() {
        let b = [check("read")]
        var logs = daily("read", .completed(true), days: 3)
        logs.append(LogEntry(behaviorID: "read", day: monday.advanced(by: 4), value: .completed(true)))
        let state = replay(b, logs, days: 5)
        #expect(state.behaviors["read"]!.streak == 1)
        #expect(state.behaviors["read"]!.bestStreak == 3)
    }

    @Test func pendingDayDoesNotBreakStreak() {
        let b = [check("read")]
        let logs = daily("read", .completed(true), days: 3)
        // Day 4 is "today" and not logged yet.
        let state = replay(b, logs, days: 4, pending: 1)
        #expect(state.behaviors["read"]!.streak == 3)
        #expect(state.days[3].isPending)

        // Grace window: yesterday and today both still open.
        let grace = replay(b, daily("read", .completed(true), days: 2), days: 4, pending: 2)
        #expect(grace.behaviors["read"]!.streak == 2)
    }

    @Test func perfectFocusDay() {
        let b = [check("a", rank: 0, focus: true), check("b", rank: 1, focus: true), check("c", rank: 2)]
        let all = ["a", "b"].flatMap { daily($0, .completed(true), days: 1) }
        let state = replay(b, all, days: 1)
        #expect(state.days[0].events.contains(.perfectFocusDay))

        let partial = replay(b, daily("a", .completed(true), days: 1), days: 1)
        #expect(!partial.days[0].events.contains(.perfectFocusDay))
    }

    @Test func volumePersonalRecords() {
        let b = [volume("study", 60)]
        let logs = [
            LogEntry(behaviorID: "study", day: monday, value: .amount(60)),
            LogEntry(behaviorID: "study", day: monday.advanced(by: 1), value: .amount(90)),
            LogEntry(behaviorID: "study", day: monday.advanced(by: 2), value: .amount(30)),
        ]
        let state = replay(b, logs, days: 3)
        #expect(state.days[0].events.isEmpty) // first log sets the bar quietly
        #expect(state.days[1].events.contains(.bestDay(behaviorID: "study", amount: 90)))
        #expect(state.behaviors["study"]!.bestDay == 90)
        // Going past the target earns extra XP.
        #expect(state.days[1].xp > state.days[0].xp + Tuning.standard.personalRecordBonusXP)
    }

    @Test func bestWeekAndComboWeek() {
        let b = [volume("study", 60)]
        let week1 = daily("study", .amount(60), days: 7)
        let week2 = daily("study", .amount(70), days: 7, from: monday.advanced(by: 7))
        let state = replay(b, week1 + week2, days: 14)
        #expect(state.days[6].events.contains(.comboWeek))
        #expect(state.behaviors["study"]!.bestWeek == 490)
        #expect(state.days[13].events.contains(.bestWeek(behaviorID: "study", amount: 490)))
    }

    @Test func turningOffAHabitKeepsPastDaysUnchanged() {
        let b = [check("read", rank: 0), check("journal", rank: 1)]
        let logs = daily("read", .completed(true), days: 4) + daily("journal", .completed(true), days: 2)
        var turnedOff = b
        turnedOff[1].isEnabled = false
        turnedOff[1].endDay = monday.advanced(by: 2)

        let state = replay(turnedOff, logs, days: 4)
        // Days 1-2: both habits done -> 100. Days 3-4: only read counts -> still 100.
        #expect(state.days.allSatisfy { abs($0.score - 100) < 1e-9 })
        #expect(state.behaviors["journal"]!.bestStreak == 2)

        // Without an end day, a disabled habit is ignored entirely.
        var removed = b
        removed[1].isEnabled = false
        #expect(replay(removed, logs, days: 4).behaviors["journal"] == nil)
    }

    @Test func behaviorsAddedLaterDoNotCountBeforeTheirStart() {
        var later = check("journal", rank: 1)
        later.startDay = monday.advanced(by: 2)
        let b = [check("read", rank: 0), later]
        let state = replay(b, daily("read", .completed(true), days: 2), days: 2)
        #expect(state.days.allSatisfy { abs($0.score - 100) < 1e-9 })
    }
}
