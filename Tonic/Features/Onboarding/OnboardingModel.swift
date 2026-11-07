import Foundation
import Observation
import TonicKit

enum OnboardingStep: Hashable {
    case behaviors, ranking, focus, theme, summary
}

/// Choices made during setup, before anything is saved.
@Observable
final class OnboardingModel {
    static let maxFocus = 3

    /// Presets plus any behaviors the user created.
    var catalog: [Behavior] = PresetLibrary.all
    var customIDs: Set<String> = []
    var selectedIDs: Set<String> = Set(PresetLibrary.core.map(\.id))
    /// Selected behaviors in priority order (most important first).
    var ranked: [Behavior] = []
    var focusIDs: Set<String> = []
    var themeID = RankTheme.plant.id

    var selectedCount: Int { selectedIDs.count }

    /// Need 2–3 Focus habits, or all of them if fewer than 2 are tracked.
    var focusRange: ClosedRange<Int> {
        let minimum = min(2, ranked.count)
        return minimum...max(minimum, min(Self.maxFocus, ranked.count))
    }

    func toggle(_ id: String) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    func addCustom(_ behavior: Behavior) {
        catalog.append(behavior)
        customIDs.insert(behavior.id)
        selectedIDs.insert(behavior.id)
    }

    func toggleFocus(_ id: String) {
        if focusIDs.contains(id) {
            focusIDs.remove(id)
        } else if focusIDs.count < Self.maxFocus {
            focusIDs.insert(id)
        }
    }

    /// Syncs the ranking list with the current selection, keeping any order the
    /// user already set and adding new picks at the bottom.
    func prepareRanking() {
        let kept = ranked.filter { selectedIDs.contains($0.id) }
        let keptIDs = Set(kept.map(\.id))
        let added = catalog.filter { selectedIDs.contains($0.id) && !keptIDs.contains($0.id) }
        ranked = kept + added
        focusIDs.formIntersection(selectedIDs)
    }

    /// The behaviors as they'll be saved, with rank and Focus applied.
    func finalBehaviors(startDay: Day? = nil) -> [Behavior] {
        ranked.enumerated().map { index, behavior in
            var b = behavior
            b.priorityRank = index
            b.isFocus = focusIDs.contains(b.id)
            b.isEnabled = true
            b.startDay = startDay
            return b
        }
    }

    /// Each behavior's share of a perfect day.
    var weights: [String: Double] {
        Weighting.normalizedWeights(for: finalBehaviors())
    }
}
