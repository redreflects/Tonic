@testable import TonicKit

/// Monday, 5 January 2026.
let monday = Day(year: 2026, month: 1, day: 5)

func check(_ id: String, rank: Int = 0, focus: Bool = false) -> Behavior {
    Behavior(id: id, name: id, kind: .check, category: .mind, icon: "circle", priorityRank: rank, isFocus: focus)
}

func avoid(_ id: String, rank: Int = 0, focus: Bool = false) -> Behavior {
    Behavior(id: id, name: id, kind: .avoid, category: .body, icon: "circle", priorityRank: rank, isFocus: focus)
}

func target(_ id: String, _ goal: Double, direction: TargetDirection = .atLeast, rank: Int = 0) -> Behavior {
    Behavior(id: id, name: id, kind: .target, category: .body, icon: "circle", target: goal, direction: direction, priorityRank: rank)
}

func volume(_ id: String, _ reference: Double, rank: Int = 0) -> Behavior {
    Behavior(id: id, name: id, kind: .volume, category: .work, icon: "circle", target: reference, priorityRank: rank)
}

/// One log entry per day for `days` days starting at `start`.
func daily(_ id: String, _ value: LogValue, days: Int, from start: Day = monday) -> [LogEntry] {
    (0..<days).map { LogEntry(behaviorID: id, day: start.advanced(by: $0), value: value) }
}

/// Replays with no pending days, so every day counts as final.
func replay(_ behaviors: [Behavior], _ logs: [LogEntry], days: Int, pending: Int = 0) -> ProgressionState {
    ProgressionEngine().replay(
        behaviors: behaviors, logs: logs,
        from: monday, through: monday.advanced(by: days - 1),
        pendingDays: pending
    )
}
