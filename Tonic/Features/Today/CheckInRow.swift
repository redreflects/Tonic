import SwiftUI
import TonicKit

/// One behavior on the Today screen, with the right logging control for its type.
struct CheckInRow: View {
    let behavior: Behavior
    let value: LogValue?
    let progress: BehaviorProgress?
    var fromHealth = false
    /// Pass `nil` to clear the log for this day.
    let onChange: (LogValue?) -> Void

    @State private var editingAmount = false
    @State private var amountText = ""
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if typeSize.isAccessibilitySize {
                // Very large text: name on its own line, controls underneath.
                title
                control
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                HStack(spacing: 12) {
                    BehaviorIcon(behavior: behavior)
                    title
                    Spacer(minLength: 8)
                    control
                }
            }
            if behavior.kind == .target || behavior.kind == .volume {
                AmountBar(behavior: behavior, amount: amount, indent: !typeSize.isAccessibilitySize)
            }
        }
        .padding(.vertical, 4)
        .sensoryFeedback(.selection, trigger: value)
        .alert("\(behavior.name)", isPresented: $editingAmount) {
            TextField("Amount", text: $amountText)
                .keyboardType(.decimalPad)
            Button("Save") {
                if let number = Double(amountText.replacingOccurrences(of: ",", with: ".")) {
                    onChange(number > 0 ? .amount(number) : nil)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter the amount\(behavior.unit.map { " in \($0)" } ?? "").")
        }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(behavior.name)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
                if fromHealth {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(.pink)
                        .accessibilityLabel("Filled in from Apple Health")
                }
            }
            StreakLabel(progress: progress, isFocus: behavior.isFocus)
        }
    }

    private var amount: Double {
        if case .amount(let a) = value { return a }
        return 0
    }

    @ViewBuilder
    private var control: some View {
        switch behavior.kind {
        case .check:
            let done = value == .completed(true)
            Button {
                onChange(done ? nil : .completed(true))
            } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 34))
                    .foregroundStyle(done ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(done ? "\(behavior.name), done" : "Mark \(behavior.name) done")
            .accessibilityHint(done ? "Double-tap to undo." : "")

        case .avoid:
            HStack(spacing: 6) {
                choice("Clean", icon: "checkmark", selected: value == .slipped(false), tint: .accentColor) {
                    onChange(value == .slipped(false) ? nil : .slipped(false))
                }
                choice("Slipped", icon: "xmark", selected: value == .slipped(true), tint: .red) {
                    onChange(value == .slipped(true) ? nil : .slipped(true))
                }
            }

        case .target, .volume:
            HStack(spacing: 4) {
                stepButton("minus") { change(by: -behavior.step) }
                    .disabled(amount <= 0)
                Button {
                    amountText = amount > 0 ? formatAmount(amount) : ""
                    editingAmount = true
                } label: {
                    Text(formatAmount(amount))
                        .font(.body.monospacedDigit().weight(.semibold))
                        .frame(minWidth: 44)
                        .contentTransition(.numericText(value: amount))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(behavior.name): \(formatAmount(amount)) \(behavior.unit ?? "")")
                .accessibilityHint("Double-tap to type an amount.")
                stepButton("plus") { change(by: behavior.step) }
            }
        }
    }

    private func change(by delta: Double) {
        let next = max(amount + delta, 0)
        onChange(next > 0 ? .amount(next) : nil)
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .frame(width: 34, height: 34)
                .background(.fill.tertiary, in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(icon == "plus" ? "Increase \(behavior.name)" : "Decrease \(behavior.name)")
    }

    private func choice(_ title: String, icon: String, selected: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body.weight(.bold))
                .frame(width: 40, height: 34)
                .foregroundStyle(selected ? .white : tint)
                .background(selected ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(.fill.tertiary), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(behavior.name): \(title)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// "🔥 5 · 🛡 1" under the behavior name.
private struct StreakLabel: View {
    let progress: BehaviorProgress?
    let isFocus: Bool

    var body: some View {
        let streak = progress?.streak ?? 0
        let shields = progress?.shields ?? 0
        HStack(spacing: 8) {
            if isFocus {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .accessibilityLabel("Focus")
            }
            Label("\(streak)", systemImage: "flame.fill")
                .foregroundStyle(streak > 0 ? AnyShapeStyle(.orange) : AnyShapeStyle(.tertiary))
                .accessibilityLabel("\(streak) day streak")
            if shields > 0 {
                Label("\(shields)", systemImage: "shield.fill")
                    .foregroundStyle(.blue)
                    .accessibilityLabel("\(shields) streak shield\(shields == 1 ? "" : "s")")
            }
        }
        .font(.caption.weight(.semibold).monospacedDigit())
        .labelStyle(.titleAndIcon)
    }
}

/// Progress toward a target, or past it for volume behaviors.
private struct AmountBar: View {
    let behavior: Behavior
    let amount: Double
    var indent = true

    var body: some View {
        let target = behavior.target ?? 1
        let overLimit = behavior.direction == .atMost && amount > target
        VStack(alignment: .leading, spacing: 3) {
            ProgressView(value: min(amount / target, 1))
                .tint(overLimit ? .red : behavior.category.color)
            Text(caption(target: target))
                .font(.caption2)
                .foregroundStyle(overLimit ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
        }
        .padding(.leading, indent ? 46 : 0)
    }

    private func caption(target: Double) -> String {
        let unit = behavior.unit.map { " \($0)" } ?? ""
        let base = "\(formatAmount(amount)) / \(formatAmount(target))\(unit)"
        if behavior.direction == .atMost { return amount > target ? "\(base) · over your limit" : "\(base) limit" }
        if behavior.kind == .volume && amount > target { return "\(base) · bonus XP!" }
        return base
    }
}

extension Behavior {
    /// How much one tap of +/− changes the amount.
    var step: Double {
        let target = self.target ?? 1
        if unit == "hours" { return 0.5 }
        if target >= 2_000 { return 500 }
        if target >= 40 { return 5 }
        return 1
    }
}
