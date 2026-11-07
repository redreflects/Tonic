import SwiftUI
import TonicKit

/// Choose how ranks are named.
struct RankThemePickerView: View {
    @Binding var selection: String
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Every 10 levels you earn a new rank. Pick the ladder you want to climb. You can change it later in Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(RankTheme.all) { theme in
                    ThemeCard(theme: theme, isSelected: theme.id == selection)
                        .onTapGesture { selection = theme.id }
                        .accessibilityAddTraits(theme.id == selection ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding()
        }
        .navigationTitle("Rank theme")
        .safeAreaInset(edge: .bottom) {
            ContinueBar(title: "Continue", action: onContinue)
        }
    }
}

private struct ThemeCard: View {
    let theme: RankTheme
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: theme.symbol)
                    .font(.title3)
                    .foregroundStyle(.tint)
                Text(theme.displayName)
                    .font(.title3.bold())
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            }
            ForEach(Array(theme.rankNames.enumerated()), id: \.offset) { tier, name in
                HStack {
                    Text(levelRange(tier))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 56, alignment: .leading)
                    Text(name)
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(.background.secondary, in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), lineWidth: 2)
        }
        .contentShape(.rect)
    }

    private func levelRange(_ tier: Int) -> String {
        let start = max(tier * RankTheme.levelsPerRank, 1)
        if tier == theme.rankNames.count - 1 { return "Lv \(start)+" }
        return "Lv \(start)–\(tier * RankTheme.levelsPerRank + 9)"
    }
}

/// Last look before saving.
struct OnboardingSummaryView: View {
    let model: OnboardingModel
    let onFinish: () -> Void

    var body: some View {
        let weights = model.weights
        let theme = RankTheme.theme(withID: model.themeID)
        List {
            Section {
                ForEach(model.ranked) { behavior in
                    HStack {
                        BehaviorRow(behavior: behavior)
                        Spacer()
                        if model.focusIDs.contains(behavior.id) {
                            Image(systemName: "star.fill").foregroundStyle(.yellow)
                        }
                        Text(formatPercent(weights[behavior.id] ?? 0))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Your behaviors")
            }

            Section("How you'll score") {
                rule("100", "A perfect day scores 100, weighted by your priorities.")
                rule("flame.fill", "Streaks add 5% XP per day, up to double.")
                rule("exclamationmark.triangle.fill", "Slipping on a habit you're avoiding costs double and resets its streak.")
                rule("shield.fill", "Every 7-day streak earns a shield that covers one missed day.")
                rule("arrow.up.circle.fill", "Levels never go down.")
            }

            Section("Starting rank") {
                Text("Level 1 · \(theme.rank(forLevel: 1).name)")
                    .font(.headline)
            }
        }
        .navigationTitle("You're all set")
        .safeAreaInset(edge: .bottom) {
            ContinueBar(title: "Start my journey", action: onFinish)
        }
    }

    private func rule(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if icon == "100" {
                    Text("100").font(.caption.bold().monospacedDigit())
                } else {
                    Image(systemName: icon)
                }
            }
            .foregroundStyle(.tint)
            .frame(width: 28)
            Text(text).font(.subheadline)
        }
    }
}
