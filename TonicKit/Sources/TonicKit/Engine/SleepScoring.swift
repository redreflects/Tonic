/// Turns up to three sleep measurements into one 0–1 quality.
///
/// Only the parts that were logged are averaged, so a quick "hours slept" entry
/// works on its own, and Apple Health data can fill in the rest later.
public enum SleepScoring {
    /// - Parameters:
    ///   - hoursSlept: Time asleep.
    ///   - targetHours: The user's sleep goal.
    ///   - bedtimeDeviationMinutes: How far tonight's bedtime was from the usual one.
    ///     Within 30 minutes is full credit, dropping to zero at 2 hours.
    ///   - restedRating: How rested the user feels, 1–5.
    public static func quality(
        hoursSlept: Double,
        targetHours: Double = 8,
        bedtimeDeviationMinutes: Double? = nil,
        restedRating: Int? = nil
    ) -> Double {
        var parts: [Double] = []

        if targetHours > 0 {
            parts.append(clamp(hoursSlept / targetHours))
        }
        if let deviation = bedtimeDeviationMinutes {
            let d = abs(deviation)
            parts.append(d <= 30 ? 1 : clamp(1 - (d - 30) / 90))
        }
        if let rested = restedRating {
            parts.append(clamp(Double(rested - 1) / 4))
        }

        guard !parts.isEmpty else { return 0 }
        return parts.reduce(0, +) / Double(parts.count)
    }

    private static func clamp(_ x: Double) -> Double { min(max(x, 0), 1) }
}
