/// Turns the user's priority ranking and Focus picks into weights that add up to 1.
///
/// Because weights always add up to 1, a perfect day is worth 100 points no matter
/// how many behaviors are tracked, so adding easy habits can't inflate the score.
public enum Weighting {
    public static func normalizedWeights(
        for behaviors: [Behavior],
        tuning: Tuning = .standard
    ) -> [String: Double] {
        let ordered = behaviors.sorted {
            ($0.priorityRank, $0.name) < ($1.priorityRank, $1.name)
        }
        guard !ordered.isEmpty else { return [:] }

        var raw: [String: Double] = [:]
        let steps = Double(max(ordered.count - 1, 1))
        for (position, behavior) in ordered.enumerated() {
            let fraction = ordered.count == 1 ? 0 : Double(position) / steps
            var weight = tuning.topRankWeight
                - (tuning.topRankWeight - tuning.bottomRankWeight) * fraction
            if behavior.isFocus { weight *= tuning.focusMultiplier }
            raw[behavior.id] = weight
        }

        let total = raw.values.reduce(0, +)
        return raw.mapValues { $0 / total }
    }
}
