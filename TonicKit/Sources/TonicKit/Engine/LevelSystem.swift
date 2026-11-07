import Foundation

/// XP needed per level. Each level costs a bit more than the last.
///
/// XP to go from `level` to `level + 1` = `base × level ^ exponent`.
public struct LevelCurve: Sendable, Hashable {
    public var base: Double
    public var exponent: Double

    public init(base: Double = 200, exponent: Double = 0.75) {
        self.base = base
        self.exponent = exponent
    }

    /// XP needed to advance from `level` to the next one.
    public func xpToAdvance(from level: Int) -> Double {
        base * pow(Double(max(level, 1)), exponent)
    }

    /// Total XP at which `level` begins. Level 1 begins at 0.
    public func totalXP(toReach level: Int) -> Double {
        guard level > 1 else { return 0 }
        return (1..<level).reduce(0) { $0 + xpToAdvance(from: $1) }
    }

    /// The level for a total XP amount.
    public func level(forTotalXP xp: Double) -> Int {
        // Add up thresholds in the same order as `totalXP(toReach:)` so both agree exactly.
        var level = 1
        var nextLevelStart = xpToAdvance(from: 1)
        while xp >= nextLevelStart {
            level += 1
            nextLevelStart += xpToAdvance(from: level)
        }
        return level
    }
}
