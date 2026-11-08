import Foundation
import SwiftData
import TonicKit

/// One logged value for one behavior on one day, saved on the device.
@Model
final class DailyLog {
    var behaviorID: String
    var dayIndex: Int
    /// "completed", "slipped", "amount" or "quality".
    var valueKind: String
    /// 1/0 for completed and slipped, otherwise the amount or quality.
    var number: Double
    var updatedAt: Date
    /// "health" when filled in from Apple Health; nil when logged by hand.
    /// Sync only ever updates Health-filled logs, so manual entries always win.
    var source: String?

    init(_ entry: LogEntry) {
        behaviorID = entry.behaviorID
        dayIndex = entry.day.index
        (valueKind, number) = Self.encode(entry.value)
        updatedAt = .now
        source = nil
    }

    var isFromHealth: Bool { source == DailyLog.healthSource }
    static let healthSource = "health"

    var entry: LogEntry {
        LogEntry(behaviorID: behaviorID, day: Day(index: dayIndex), value: value)
    }

    var value: LogValue {
        get {
            switch valueKind {
            case "completed": .completed(number != 0)
            case "slipped": .slipped(number != 0)
            case "quality": .quality(number)
            default: .amount(number)
            }
        }
        set {
            (valueKind, number) = Self.encode(newValue)
            updatedAt = .now
        }
    }

    private static func encode(_ value: LogValue) -> (String, Double) {
        switch value {
        case .completed(let done): ("completed", done ? 1 : 0)
        case .slipped(let slipped): ("slipped", slipped ? 1 : 0)
        case .amount(let amount): ("amount", amount)
        case .quality(let quality): ("quality", quality)
        }
    }
}
