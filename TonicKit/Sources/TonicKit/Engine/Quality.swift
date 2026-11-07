/// How one behavior went on one day.
public struct Outcome: Hashable, Sendable {
    /// 0–1 for good outcomes. Negative (−slipPenalty) when an avoid behavior slipped.
    public var quality: Double
    /// Good enough to keep a streak going.
    public var hit: Bool
    public var slipped: Bool
    public var logged: Bool
    /// The raw amount, for `.target` and `.volume` behaviors.
    public var amount: Double?
}

/// Scores a single log entry on a common 0–1 scale, whatever the behavior type.
public enum Quality {
    public static func evaluate(
        _ behavior: Behavior,
        _ value: LogValue?,
        tuning: Tuning = .standard
    ) -> Outcome {
        guard let value else {
            return Outcome(quality: 0, hit: false, slipped: false, logged: false, amount: nil)
        }

        var amount: Double?
        var slipped = false
        let quality: Double

        switch value {
        case .quality(let q):
            quality = clamp(q)
        case .completed(let done):
            quality = done ? 1 : 0
        case .slipped(let didSlip):
            slipped = didSlip
            quality = didSlip ? -tuning.slipPenalty : 1
        case .amount(let a):
            amount = max(a, 0)
            quality = amountQuality(behavior, amount: max(a, 0))
        }

        let hit = !slipped && quality >= tuning.hitThreshold
        return Outcome(quality: quality, hit: hit, slipped: slipped, logged: true, amount: amount)
    }

    private static func amountQuality(_ behavior: Behavior, amount: Double) -> Double {
        guard let target = behavior.target, target > 0 else {
            // No target: any amount counts as done.
            return amount > 0 ? 1 : 0
        }
        switch (behavior.kind, behavior.direction) {
        case (.target, .atMost):
            // Full credit at or under the limit, falling to zero at double the limit.
            return amount <= target ? 1 : clamp(1 - (amount - target) / target)
        default:
            return clamp(amount / target)
        }
    }

    private static func clamp(_ x: Double) -> Double { min(max(x, 0), 1) }
}
