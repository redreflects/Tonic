#if DEBUG
import Foundation
import SwiftData
import TonicKit

/// Fake past logs for trying out streaks, levels and shields during development.
enum SampleHistory {
    static func add(days: Int, context: ModelContext) {
        let defaults = UserDefaults.standard
        let today = Day(.now)
        let currentStart = defaults.integer(forKey: AppSettings.journeyStartDay)
        let end = currentStart == 0 ? today : Day(index: currentStart)
        let newStart = end.advanced(by: -days)

        let tracked = (try? context.fetch(FetchDescriptor<TrackedBehavior>())) ?? []
        var rng = SystemRandomNumberGenerator()

        for offset in 0..<days {
            let day = newStart.advanced(by: offset)
            for item in tracked where item.isEnabled {
                let behavior = item.behavior
                let roll = Double.random(in: 0..<1, using: &rng)
                let hit = roll < 0.85
                let target = behavior.target ?? 1
                let value: LogValue? = switch behavior.kind {
                case .check: hit ? .completed(true) : nil
                case .avoid: .slipped(roll > 0.95)
                case .target where behavior.direction == .atMost: .amount(target * (hit ? 0.7 : 1.4))
                case .target: .amount(target * (hit ? 1 : 0.6))
                case .volume: .amount((target * (hit ? Double.random(in: 0.9...1.6, using: &rng) : 0.4)).rounded())
                }
                if let value {
                    context.insert(DailyLog(LogEntry(behaviorID: behavior.id, day: day, value: value)))
                }
            }
        }

        // Only habits that began with the journey move back; ones added later keep their start.
        for item in tracked where (item.startDayIndex ?? end.index) <= end.index {
            item.startDayIndex = newStart.index
        }
        try? context.save()
        defaults.set(newStart.index, forKey: AppSettings.journeyStartDay)
    }
}
#endif
