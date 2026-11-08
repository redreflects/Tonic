import SwiftUI
import TonicKit

extension BehaviorKind {
    var shortLabel: String {
        switch self {
        case .check: "Yes/No"
        case .avoid: "Avoid"
        case .target: "Target"
        case .volume: "Volume"
        }
    }

    var explainer: String {
        switch self {
        case .check: "A good habit you either do or don't, like meditating."
        case .avoid: "A habit you're cutting out. Staying clean earns points; a slip costs double."
        case .target: "Graded against a goal or limit, with partial credit, like 8 glasses of water."
        case .volume: "More is always better, like study minutes. Tracks personal records."
        }
    }
}

extension BehaviorCategory {
    var title: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .body: .orange
        case .mind: .indigo
        case .social: .pink
        case .work: .blue
        }
    }
}

extension Behavior {
    /// One-line description of how this behavior is scored.
    var detail: String {
        switch kind {
        case .check:
            return "Did it or didn't"
        case .avoid:
            return "Stay clean · slips cost double"
        case .target:
            let amount = "\(formatAmount(target ?? 0)) \(unit ?? "")".trimmingCharacters(in: .whitespaces)
            return direction == .atMost ? "Limit: \(amount)" : "Goal: \(amount)"
        case .volume:
            let amount = "\(formatAmount(target ?? 0)) \(unit ?? "")".trimmingCharacters(in: .whitespaces)
            return "Full credit at \(amount) · tracks PRs"
        }
    }
}

func formatAmount(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...1)))
}

func formatPercent(_ fraction: Double) -> String {
    fraction.formatted(.percent.precision(.fractionLength(0)))
}

/// Icon tile + name + scoring detail. Used across onboarding and the main app.
struct BehaviorRow: View {
    let behavior: Behavior

    var body: some View {
        HStack(spacing: 12) {
            BehaviorIcon(behavior: behavior)
            VStack(alignment: .leading, spacing: 2) {
                Text(behavior.name)
                    .font(.body)
                Text(behavior.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct BehaviorIcon: View {
    let behavior: Behavior
    var size: CGFloat = 34

    var body: some View {
        Image(systemName: behavior.icon)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(behavior.category.color.gradient, in: .rect(cornerRadius: size * 0.28))
    }
}

/// A behavior with a checkmark circle; tap to select or deselect.
struct SelectableBehaviorRow: View {
    let behavior: Behavior
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                BehaviorRow(behavior: behavior)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A full-width primary button pinned to the bottom of the screen.
struct ContinueBar: View {
    let title: String
    var isEnabled = true
    var hint: String?
    let action: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            if let hint {
                Text(hint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button(action: action) {
                Text(title)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!isEnabled)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

extension RankTheme {
    /// SF Symbol shown next to the user's rank.
    var symbol: String {
        switch id {
        case RankTheme.frat.id: "building.columns.fill"
        default: "leaf.fill"
        }
    }
}
