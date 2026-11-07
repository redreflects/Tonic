import SwiftData
import SwiftUI
import TonicKit

/// Setup: welcome → pick behaviors → rank → Focus habits → rank theme → summary.
struct OnboardingFlow: View {
    @Environment(\.modelContext) private var context
    @AppStorage(AppSettings.hasOnboarded) private var hasOnboarded = false
    @AppStorage(AppSettings.rankThemeID) private var rankThemeID = RankTheme.plant.id
    @AppStorage(AppSettings.journeyStartDay) private var journeyStartDay = 0

    @State private var model = OnboardingModel()
    @State private var path: [OnboardingStep] = []

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView { path.append(.behaviors) }
                .navigationDestination(for: OnboardingStep.self) { step in
                    switch step {
                    case .behaviors:
                        BehaviorPickerView(model: model) {
                            model.prepareRanking()
                            path.append(.ranking)
                        }
                    case .ranking:
                        PriorityRankingView(model: model) { path.append(.focus) }
                    case .focus:
                        FocusPickerView(model: model) { path.append(.theme) }
                    case .theme:
                        RankThemePickerView(selection: $model.themeID) { path.append(.summary) }
                    case .summary:
                        OnboardingSummaryView(model: model, onFinish: finish)
                    }
                }
        }
    }

    private func finish() {
        let today = Day(.now)
        for behavior in model.finalBehaviors(startDay: today) {
            context.insert(TrackedBehavior(behavior, isCustom: model.customIDs.contains(behavior.id)))
        }
        try? context.save()
        rankThemeID = model.themeID
        journeyStartDay = today.index
        hasOnboarded = true
    }
}

struct WelcomeView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "leaf.circle.fill")
                    .font(.system(size: 88))
                    .foregroundStyle(.tint)
                    .symbolRenderingMode(.hierarchical)
                Text("Tonic")
                    .font(.largeTitle.bold())
                Text("Level up your life, one habit at a time.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 18) {
                feature("checklist", "Pick your habits", "Good ones to build and bad ones to cut.")
                feature("arrow.up.arrow.down", "Set your priorities", "What matters most to you counts most.")
                feature("flame.fill", "Build streaks and level up", "Consistency compounds. Slips hurt.")
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .safeAreaInset(edge: .bottom) {
            ContinueBar(title: "Get started", action: onStart)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func feature(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
