import Foundation

/// A calendar day, stored as the number of days since 1970-01-01.
///
/// Using a plain day number keeps the engine free of time zones and daylight
/// saving: the app turns a `Date` into a `Day` once, using the user's calendar.
public struct Day: Hashable, Comparable, Codable, Sendable, Strideable, CustomStringConvertible {
    public let index: Int

    public init(index: Int) {
        self.index = index
    }

    /// Builds a day from a civil date (proleptic Gregorian calendar).
    public init(year: Int, month: Int, day: Int) {
        // Howard Hinnant's days_from_civil algorithm.
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = (month + 9) % 12
        let doy = (153 * mp + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        self.index = era * 146_097 + doe - 719_468
    }

    /// The day a `Date` falls on in the given calendar (the user's by default).
    public init(_ date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year ?? 1970, month: c.month ?? 1, day: c.day ?? 1)
    }

    /// 0 = Monday ... 6 = Sunday.
    public var weekday: Int { Self.floorMod(index + 3, 7) }

    /// Weeks run Monday to Sunday. Every day in the same week shares this number.
    public var weekIndex: Int { Self.floorDiv(index + 3, 7) }

    public var isLastDayOfWeek: Bool { weekday == 6 }

    public static func < (lhs: Day, rhs: Day) -> Bool { lhs.index < rhs.index }
    public func advanced(by n: Int) -> Day { Day(index: index + n) }
    public func distance(to other: Day) -> Int { other.index - index }

    public var description: String { "Day(\(index))" }

    private static func floorDiv(_ a: Int, _ b: Int) -> Int {
        (a >= 0 ? a : a - b + 1) / b
    }

    private static func floorMod(_ a: Int, _ b: Int) -> Int {
        ((a % b) + b) % b
    }
}
