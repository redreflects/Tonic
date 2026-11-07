/// A named rank: a band of 10 levels with its own badge.
public struct Rank: Hashable, Sendable {
    /// 0 for levels 1–9, 1 for levels 10–19, ... up to 7 for level 70+.
    public let tier: Int
    public let name: String
    /// Asset catalog name for the badge, e.g. "rank.plant.3".
    public let badgeAsset: String
}

/// A set of rank names. The user picks one in onboarding and can switch in Settings.
///
/// To add a theme, add a static entry here and include it in `all`.
public struct RankTheme: Identifiable, Hashable, Sendable {
    public static let levelsPerRank = 10

    public let id: String
    public let displayName: String
    public let rankNames: [String]

    public init(id: String, displayName: String, rankNames: [String]) {
        self.id = id
        self.displayName = displayName
        self.rankNames = rankNames
    }

    public static let plant = RankTheme(
        id: "plant",
        displayName: "Plant",
        rankNames: ["Seedling", "Sprout", "Sapling", "Bloom", "Grove", "Evergreen", "Redwood", "Ancient"]
    )

    public static let frat = RankTheme(
        id: "frat",
        displayName: "Frat",
        rankNames: [
            "Potential New Member", "Pledge", "Pledge Class President", "Brother",
            "Philanthropy Chair", "Social Chair", "Vice President", "President",
        ]
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
        return Rank(tier: tier, name: rankNames[tier], badgeAsset: "rank.\(id).\(tier)")
    }

    /// The first level of the next rank, or nil at the top rank.
    public func nextRankLevel(after level: Int) -> Int? {
        let tier = Self.tier(forLevel: level, rankCount: rankNames.count)
        guard tier < rankNames.count - 1 else { return nil }
        return (tier + 1) * Self.levelsPerRank
    }
}
