import Foundation

/// One day of Apple Health numbers. Missing values are nil.
public struct HealthDay: Hashable, Sendable {
    public var day: Day
    public var sleepHours: Double?
    public var steps: Double?
    public var exerciseMinutes: Double?
    public var mindfulMinutes: Double?
    public var waterLiters: Double?

    public init(
        day: Day, sleepHours: Double? = nil, steps: Double? = nil,
        exerciseMinutes: Double? = nil, mindfulMinutes: Double? = nil, waterLiters: Double? = nil
    ) {
        self.day = day
        self.sleepHours = sleepHours
        self.steps = steps
        self.exerciseMinutes = exerciseMinutes
        self.mindfulMinutes = mindfulMinutes
        self.waterLiters = waterLiters
    }
}

/// Turns Apple Health numbers into habit logs for the built-in habits that Health can measure.
///
/// Returns nil whenever Health has nothing useful, so an empty Health day never
/// overwrites or invents a log.
public enum HealthImport {
    public static let litersPerGlass = 0.25
    public static let exerciseMinutesForCredit = 30.0

    /// What each supported habit reads from Health, for showing in Settings.
    public static let sources: [(behaviorID: String, description: String)] = [
        ("sleep", "Time asleep, counted on the morning you wake up"),
        ("steps", "Step count"),
        ("exercise", "Exercise minutes (30+ checks it off)"),
        ("meditate", "Mindful minutes"),
        ("hydration", "Water (1 glass = 250 ml)"),
    ]

    public static var supportedBehaviorIDs: Set<String> { Set(sources.map(\.behaviorID)) }

    public static func value(for behavior: Behavior, from data: HealthDay) -> LogValue? {
        switch behavior.id {
        case "sleep":
            guard let hours = data.sleepHours, hours >= 0.5 else { return nil }
            return .amount((hours * 10).rounded() / 10)
        case "steps":
            guard let steps = data.steps, steps >= 1 else { return nil }
            return .amount(steps.rounded())
        case "exercise":
            // Only check it off. Fewer minutes leaves it open so you can still log by hand.
            guard let minutes = data.exerciseMinutes, minutes >= exerciseMinutesForCredit else { return nil }
            return .completed(true)
        case "meditate":
            guard let minutes = data.mindfulMinutes, minutes >= 1 else { return nil }
            return .amount(minutes.rounded())
        case "hydration":
            guard let liters = data.waterLiters else { return nil }
            let glasses = (liters / litersPerGlass).rounded()
            return glasses >= 1 ? .amount(glasses) : nil
        default:
            return nil
        }
    }

    /// Total time covered by a set of possibly overlapping intervals, in seconds.
    /// Used so sleep recorded by both a watch and a phone isn't counted twice.
    public static func mergedDuration(_ intervals: [(start: Double, end: Double)]) -> Double {
        let sorted = intervals.filter { $0.end > $0.start }.sorted { $0.start < $1.start }
        var total = 0.0
        var current: (start: Double, end: Double)?
        for interval in sorted {
            if let c = current, interval.start <= c.end {
                current = (c.start, max(c.end, interval.end))
            } else {
                if let c = current { total += c.end - c.start }
                current = interval
            }
        }
        if let c = current { total += c.end - c.start }
        return total
    }
}
