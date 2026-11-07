import Testing
@testable import TonicKit

/// Simulates realistic users for a year to check that leveling feels right.
/// If you change `Tuning`, run this and look at the printed timeline.
@Suite("Pacing simulation")
struct PacingSimulationTests {
    /// Small deterministic random generator so results are repeatable.
    struct SeededRandom: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
    }

    /// A user with the core behaviors plus study and reading, two of them Focus habits.
    static func behaviors() -> [Behavior] {
        var list = PresetLibrary.core + PresetLibrary.library.filter { ["study", "read"].contains($0.id) }
        for i in list.indices {
            list[i].priorityRank = i
            list[i].isEnabled = true
            list[i].isFocus = ["sleep", "study"].contains(list[i].id)
        }
        return list
    }

    /// `consistency`: chance of hitting each habit on a given day.
    /// `slipRate`: chance of slipping on each avoid habit on a given day.
    static func simulate(days: Int, consistency: Double, slipRate: Double, seed: UInt64) -> ProgressionState {
        var rng = SeededRandom(state: seed)
        let behaviors = behaviors()
        var logs: [LogEntry] = []
        for offset in 0..<days {
            let day = monday.advanced(by: offset)
            for b in behaviors {
                let hit = Double.random(in: 0..<1, using: &rng) < consistency
                let value: LogValue
                switch b.kind {
                case .check: value = .completed(hit)
                case .avoid: value = .slipped(Double.random(in: 0..<1, using: &rng) < slipRate)
                case .target: value = .amount(b.target! * (hit ? 1 : 0.6))
                case .volume: value = .amount(b.target! * (hit ? Double.random(in: 0.9...1.5, using: &rng) : 0.4))
                }
                logs.append(LogEntry(behaviorID: b.id, day: day, value: value))
            }
        }
        return replay(behaviors, logs, days: days)
    }

    static func dayReaching(_ level: Int, in state: ProgressionState) -> Int? {
        state.days.firstIndex { $0.events.contains(.levelUp(level: level)) }.map { $0 + 1 }
    }

    @Test func solidUserPacing() {
        let state = Self.simulate(days: 365, consistency: 0.85, slipRate: 0.03, seed: 42)
        let avgXP = state.totalXP / 365
        let avgScore = state.days.map(\.score).reduce(0, +) / 365
        let l10 = Self.dayReaching(10, in: state)
        let l30 = Self.dayReaching(30, in: state)
        print("""
        Solid user, 1 year: level \(state.level), avg score \(Int(avgScore)), avg XP/day \(Int(avgXP))
          level 10 on day \(l10.map(String.init) ?? "-"), level 20 on day \(Self.dayReaching(20, in: state).map(String.init) ?? "-"), level 30 on day \(l30.map(String.init) ?? "-")
        """)

        // Targets from the plan: first rank-up in ~4–6 weeks, level 30 in ~6–9 months.
        #expect((25...50).contains(l10 ?? .max))
        #expect((180...290).contains(l30 ?? .max))
    }

    @Test func casualUserStillProgresses() {
        let state = Self.simulate(days: 365, consistency: 0.55, slipRate: 0.15, seed: 7)
        print("Casual user, 1 year: level \(state.level), avg XP/day \(Int(state.totalXP / 365))")
        #expect(state.level >= 10)
        #expect(state.level < Self.simulate(days: 365, consistency: 0.85, slipRate: 0.03, seed: 42).level)
    }
}
