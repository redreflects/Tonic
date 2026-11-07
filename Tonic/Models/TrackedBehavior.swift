import Foundation
import SwiftData
import TonicKit

/// A behavior the user tracks, saved on the device.
///
/// This mirrors `TonicKit.Behavior` with plain stored fields so SwiftData can save it.
/// Use `behavior` to hand it to the scoring engine.
@Model
final class TrackedBehavior {
    @Attribute(.unique) var id: String
    var name: String
    var kindRaw: String
    var categoryRaw: String
    var icon: String
    var unit: String?
    var target: Double?
    var directionRaw: String
    var isCore: Bool
    var isCustom: Bool
    var priorityRank: Int
    var isFocus: Bool
    var isEnabled: Bool
    var startDayIndex: Int?

    init(_ behavior: Behavior, isCustom: Bool) {
        id = behavior.id
        name = behavior.name
        kindRaw = behavior.kind.rawValue
        categoryRaw = behavior.category.rawValue
        icon = behavior.icon
        unit = behavior.unit
        target = behavior.target
        directionRaw = behavior.direction.rawValue
        isCore = behavior.isCore
        self.isCustom = isCustom
        priorityRank = behavior.priorityRank
        isFocus = behavior.isFocus
        isEnabled = behavior.isEnabled
        startDayIndex = behavior.startDay?.index
    }

    var behavior: Behavior {
        Behavior(
            id: id,
            name: name,
            kind: BehaviorKind(rawValue: kindRaw) ?? .check,
            category: BehaviorCategory(rawValue: categoryRaw) ?? .mind,
            icon: icon,
            unit: unit,
            target: target,
            direction: TargetDirection(rawValue: directionRaw) ?? .atLeast,
            isCore: isCore,
            priorityRank: priorityRank,
            isFocus: isFocus,
            isEnabled: isEnabled,
            startDay: startDayIndex.map(Day.init(index:))
        )
    }
}
