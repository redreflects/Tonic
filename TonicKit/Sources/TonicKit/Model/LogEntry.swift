/// What the user logged for one behavior on one day.
public enum LogValue: Hashable, Codable, Sendable {
    /// `.check` behaviors: did it or not.
    case completed(Bool)
    /// `.avoid` behaviors: `true` if the user slipped, `false` if they stayed clean.
    case slipped(Bool)
    /// `.target` and `.volume` behaviors: the amount (hours, glasses, minutes...).
    case amount(Double)
    /// A precomputed 0–1 quality, for behaviors scored from several parts (see `SleepScoring`).
    case quality(Double)
}

public struct LogEntry: Hashable, Codable, Sendable {
    public var behaviorID: String
    public var day: Day
    public var value: LogValue

    public init(behaviorID: String, day: Day, value: LogValue) {
        self.behaviorID = behaviorID
        self.day = day
        self.value = value
    }
}
