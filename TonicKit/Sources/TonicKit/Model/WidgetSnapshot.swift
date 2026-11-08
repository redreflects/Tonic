import Foundation

/// The little bit of data the home-screen widget shows.
///
/// The app saves this to a shared App Group container whenever today's numbers change,
/// and the widget reads it. The widget never touches the main database.
public struct WidgetSnapshot: Codable, Hashable, Sendable {
    public struct Habit: Codable, Hashable, Sendable {
        public var name: String
        public var icon: String
        public var streak: Int
        public var isDone: Bool

        public init(name: String, icon: String, streak: Int, isDone: Bool) {
            self.name = name
            self.icon = icon
            self.streak = streak
            self.isDone = isDone
        }
    }

    /// `Day.index` the numbers belong to. If it isn't today, the widget shows a fresh day.
    public var dayIndex: Int
    public var score: Double
    public var level: Int
    public var levelProgress: Double
    public var rankName: String
    public var rankSymbol: String
    public var focus: [Habit]
    public var longestStreak: Int
    public var questsDone: Int
    public var questsTotal: Int

    public init(
        dayIndex: Int, score: Double, level: Int, levelProgress: Double,
        rankName: String, rankSymbol: String, focus: [Habit],
        longestStreak: Int, questsDone: Int, questsTotal: Int
    ) {
        self.dayIndex = dayIndex
        self.score = score
        self.level = level
        self.levelProgress = levelProgress
        self.rankName = rankName
        self.rankSymbol = rankSymbol
        self.focus = focus
        self.longestStreak = longestStreak
        self.questsDone = questsDone
        self.questsTotal = questsTotal
    }

    public static let appGroup = "group.com.tonicapp.Tonic"
    private static let key = "widgetSnapshot"

    public static func load() -> WidgetSnapshot? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    public func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: Self.appGroup)?.set(data, forKey: Self.key)
    }

    /// The same numbers for a new day that hasn't been logged yet.
    public func startingFresh(on day: Int) -> WidgetSnapshot {
        var copy = self
        copy.dayIndex = day
        copy.score = 0
        copy.focus = focus.map { Habit(name: $0.name, icon: $0.icon, streak: $0.streak, isDone: false) }
        return copy
    }

    public static let placeholder = WidgetSnapshot(
        dayIndex: 0, score: 72, level: 12, levelProgress: 0.4,
        rankName: "Sprout", rankSymbol: "leaf.fill",
        focus: [
            Habit(name: "Sleep", icon: "bed.double.fill", streak: 12, isDone: true),
            Habit(name: "Alcohol-free", icon: "wineglass", streak: 30, isDone: true),
            Habit(name: "Exercise", icon: "figure.run", streak: 4, isDone: false),
        ],
        longestStreak: 30, questsDone: 1, questsTotal: 3
    )
}
