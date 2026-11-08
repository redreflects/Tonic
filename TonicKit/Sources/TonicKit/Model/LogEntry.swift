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

/// Encoded as `{"kind": "amount", "value": 7.5}` so exported files are easy to read.
extension LogValue {
    private enum CodingKeys: String, CodingKey { case kind, value }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .kind) {
        case "completed": self = .completed(try c.decode(Bool.self, forKey: .value))
        case "slipped": self = .slipped(try c.decode(Bool.self, forKey: .value))
        case "amount": self = .amount(try c.decode(Double.self, forKey: .value))
        case "quality": self = .quality(try c.decode(Double.self, forKey: .value))
        case let other:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: c, debugDescription: "Unknown log kind \(other)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .completed(let v): try c.encode("completed", forKey: .kind); try c.encode(v, forKey: .value)
        case .slipped(let v): try c.encode("slipped", forKey: .kind); try c.encode(v, forKey: .value)
        case .amount(let v): try c.encode("amount", forKey: .kind); try c.encode(v, forKey: .value)
        case .quality(let v): try c.encode("quality", forKey: .kind); try c.encode(v, forKey: .value)
        }
    }
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
