import SwiftUI
import TonicKit

/// Drag to put the most important behaviors at the top.
struct PriorityRankingView: View {
    @Bindable var model: OnboardingModel
    let onContinue: () -> Void

    var body: some View {
        let weights = model.weights
        List {
            Section {
                ForEach(Array(model.ranked.enumerated()), id: \.element.id) { index, behavior in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        BehaviorRow(behavior: behavior)
                        Spacer()
                        Text(formatPercent(weights[behavior.id] ?? 0))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .onMove { model.ranked.move(fromOffsets: $0, toOffset: $1) }
            } header: {
                Text("Most important at the top")
            } footer: {
                Text("Your #1 counts twice as much as your last. Percentages show each behavior's share of a perfect day.")
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Rank your priorities")
        .safeAreaInset(edge: .bottom) {
            ContinueBar(title: "Continue", action: onContinue)
        }
    }
}

/// Pick 2–3 habits to emphasize.
struct FocusPickerView: View {
    @Bindable var model: OnboardingModel
    let onContinue: () -> Void

    var body: some View {
        let weights = model.weights
        let range = model.focusRange
        List {
            Section {
                ForEach(model.ranked) { behavior in
                    let isFocus = model.focusIDs.contains(behavior.id)
                    let isFull = model.focusIDs.count >= OnboardingModel.maxFocus
                    Button {
                        model.toggleFocus(behavior.id)
                    } label: {
                        HStack {
                            BehaviorRow(behavior: behavior)
                            Spacer()
                            Text(formatPercent(weights[behavior.id] ?? 0))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Image(systemName: isFocus ? "star.fill" : "star")
                                .font(.title3)
                                .foregroundStyle(isFocus ? AnyShapeStyle(.yellow) : AnyShapeStyle(.tertiary))
                                .frame(width: 32)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isFocus && isFull)
                    .accessibilityAddTraits(isFocus ? .isSelected : [])
                }
            } header: {
                Text("Pick \(range.lowerBound == range.upperBound ? "\(range.lowerBound)" : "\(range.lowerBound)–\(range.upperBound)") Focus habits")
            } footer: {
                Text("Focus habits count 1.5× more, get their own streak flame, and a day where you hit all of them earns 25% bonus XP.")
            }
        }
        .navigationTitle("Choose your focus")
        .safeAreaInset(edge: .bottom) {
            ContinueBar(
                title: "Continue",
                isEnabled: range.contains(model.focusIDs.count),
                hint: "\(model.focusIDs.count) of \(range.upperBound) chosen",
                action: onContinue
            )
        }
    }
}
