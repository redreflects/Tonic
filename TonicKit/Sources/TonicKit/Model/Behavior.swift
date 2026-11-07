/// How a behavior is logged and scored.
public enum BehaviorKind: String, Codable, Sendable, CaseIterable {
    /// Good habit, yes or no (meditate, read).
    case check
    /// Bad habit to stay away from, clean or slipped (alcohol, vaping).
    case avoid
    /// Graded against a target, partial credit allowed (sleep, water, screen time).
    case target
    /// More is always better; tracks personal records (study minutes, pushups).
    case volume
}

/// For `.target` behaviors: is the goal to reach the target or stay under it?
public enum TargetDirection: String, Codable, Sendable {
    case atLeast
    case atMost
}

public enum BehaviorCategory: String, Codable, Sendable, CaseIterable {
    case body, mind, social, work
}

/// A behavior the user tracks, including their priority settings for it.
public struct Behavior: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var name: String
    public var kind: BehaviorKind
    public var category: BehaviorCategory
    /// SF Symbol name.
    public var icon: String
    /// Unit for `.target` and `.volume` amounts, e.g. "hours", "glasses", "minutes".
    public var unit: String?
    /// `.target`: the goal amount. `.volume`: the amount that earns full daily credit.
    public var target: Double?
    public var direction: TargetDirection
    /// Core behaviors are switched on by default during setup.
    public var isCore: Bool

    /// 0 = most important. Set on the ranking screen.
    public var priorityRank: Int
    /// The 2–3 habits the user is putting extra emphasis on.
    public var isFocus: Bool
    public var isEnabled: Bool
    /// First day this behavior counts. Days before it are ignored.
    public var startDay: Day?

    public init(
        id: String,
        name: String,
        kind: BehaviorKind,
        category: BehaviorCategory,
        icon: String,
        unit: String? = nil,
        target: Double? = nil,
        direction: TargetDirection = .atLeast,
        isCore: Bool = false,
        priorityRank: Int = 0,
        isFocus: Bool = false,
        isEnabled: Bool = true,
        startDay: Day? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.category = category
        self.icon = icon
        self.unit = unit
        self.target = target
        self.direction = direction
        self.isCore = isCore
        self.priorityRank = priorityRank
        self.isFocus = isFocus
        self.isEnabled = isEnabled
        self.startDay = startDay
    }
}
