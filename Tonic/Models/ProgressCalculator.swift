import Foundation
import SwiftData
import TonicKit

/// Bridges saved data to the scoring engine.
enum ProgressCalculator {
    /// Yesterday stays open for logging until noon (the grace window).
    static func pendingDays(now: Date = .now, calendar: Calendar = .current) -> Int {
        calendar.component(.hour, from: now) < 12 ? 2 : 1
    }

    static func state(
        tracked: [TrackedBehavior],
        logs: [DailyLog],
        journeyStartDay: Int,
        today: Day = Day(.now)
    ) -> ProgressionState {
        let startIndex = journeyStartDay == 0 ? today.index : min(journeyStartDay, today.index)
        return ProgressionEngine().replay(
            behaviors: tracked.map(\.behavior),
            logs: logs.map(\.entry),
            from: Day(index: startIndex),
            through: today,
            pendingDays: pendingDays()
        )
    }
}

extension ModelContext {
    /// Saves, replaces or (with `nil`) removes the log for one behavior on one day.
    func setLog(_ value: LogValue?, behaviorID: String, day: Day, existing: [DailyLog]) {
        let match = existing.first { $0.behaviorID == behaviorID && $0.dayIndex == day.index }
        switch (match, value) {
        case (let log?, let value?):
            log.value = value
        case (let log?, nil):
            delete(log)
        case (nil, let value?):
            insert(DailyLog(LogEntry(behaviorID: behaviorID, day: day, value: value)))
        case (nil, nil):
            return
        }
        try? save()
    }
}
