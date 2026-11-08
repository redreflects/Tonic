/// A named rank: a band of 10 levels with its own badge.
public struct Rank: Hashable, Sendable {
    /// 0 for levels 1–9, 1 for levels 10–19, ... up to 7 for level 70+.
    public let tier: Int
    public let name: String
    /// SF Symbol drawn on this rank's badge.
    public let symbol: String
}

/// A set of rank names. The user picks one in onboarding and can switch in Settings.
///
/// To add a theme, add a static entry here and include it in `all`.
public struct RankTheme: Identifiable, Hashable, Sendable {
    public static let levelsPerRank = 10

    public let id: String
    public let displayName: String
    public let rankNames: [String]
    /// One SF Symbol per rank, drawn on its badge.
    public let rankSymbols: [String]

    public init(id: String, displayName: String, rankNames: [String], rankSymbols: [String]) {
        precondition(rankNames.count == rankSymbols.count, "Each rank needs a symbol")
        self.id = id
        self.displayName = displayName
        self.rankNames = rankNames
        self.rankSymbols = rankSymbols
    }

    public static let plant = RankTheme(
        id: "plant",
        displayName: "Plant",
        rankNames: ["Seedling", "Sprout", "Sapling", "Bloom", "Grove", "Evergreen", "Redwood", "Ancient"],
        rankSymbols: ["circle.dotted", "leaf", "leaf.fill", "camera.macro", "tree", "tree.fill", "mountain.2.fill", "sun.max.fill"]
    )

    public static let frat = RankTheme(
        id: "frat",
        displayName: "Frat",
        rankNames: [
            "Potential New Member", "Pledge", "Pledge Class President", "Brother",
            "Philanthropy Chair", "Social Chair", "Vice President", "President",
        ],
        rankSymbols: ["person", "person.fill", "person.badge.key.fill", "person.2.fill", "heart.circle.fill", "party.popper.fill", "star.circle.fill", "crown.fill"]
    )

    public static let all: [RankTheme] = [plant, frat]

    public static func theme(withID id: String) -> RankTheme {
        all.first { $0.id == id } ?? plant
    }

    /// Which rank band a level falls in. Levels past the last band stay in the top rank.
    public static func tier(forLevel level: Int, rankCount: Int = 8) -> Int {
        min(max(level, 1) / levelsPerRank, rankCount - 1)
    }

    public func rank(forLevel level: Int) -> Rank {
        let tier = Self.tier(forLevel: level, rankCount: rankNames.count)
        return Rank(tier: tier, name: rankNames[tier], symbol: rankSymbols[tier])
    }

    /// The first level of the next rank, or nil at the top rank.
    public func nextRankLevel(after level: Int) -> Int? {
        let tier = Self.tier(forLevel: level, rankCount: rankNames.count)
        guard tier < rankNames.count - 1 else { return nil }
        return (tier + 1) * Self.levelsPerRank
    }
}
