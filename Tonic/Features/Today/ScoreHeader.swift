import SwiftUI
import TonicKit

/// The pinned top of the Today screen. Full size at the top of the list,
/// shrinks to a slim bar once you scroll down.
struct TodayHeader: View {
    let title: String
    let score: Double
    let dayXP: Double
    let state: ProgressionState
    let theme: RankTheme
    let isCollapsed: Bool
    @Binding var showingYesterday: Bool
    let canEditYesterday: Bool

    @Namespace private var namespace

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isCollapsed {
                collapsed
            } else {
                expanded
            }
        }
        .padding(.horizontal)
        .padding(.top, isCollapsed ? 6 : 8)
        .padding(.bottom, isCollapsed ? 8 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider().opacity(isCollapsed ? 1 : 0)
        }
    }

    private var expanded: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.largeTitle.bold())
                .matchedGeometryEffect(id: "title", in: namespace)

            HStack(spacing: 20) {
                ScoreRing(score: score, lineWidth: 14, fontSize: 40, showsLabel: true)
                    .frame(width: 124, height: 124)
                    .matchedGeometryEffect(id: "ring", in: namespace)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        RankBadge(rank: theme.rank(forLevel: state.level), size: 20)
                        Text(theme.rank(forLevel: state.level).name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.tint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Text("Level \(state.level)")
                        .font(.title.bold())
                        .contentTransition(.numericText())
                        .matchedGeometryEffect(id: "level", in: namespace)
                    ProgressView(value: state.levelProgress)
                        .tint(.accentColor)
                        .matchedGeometryEffect(id: "xpbar", in: namespace)
                    Text("\(xp(state.xpIntoLevel)) / \(xp(state.xpForNextLevel)) XP")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    dayXPText
                        .font(.caption.weight(.semibold).monospacedDigit())
                }
            }

            if canEditYesterday {
                Picker("Day", selection: $showingYesterday) {
                    Text("Today").tag(false)
                    Text("Yesterday").tag(true)
                }
                .pickerStyle(.segmented)
                Text("You can finish logging yesterday until noon.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var collapsed: some View {
        HStack(spacing: 12) {
            ScoreRing(score: score, lineWidth: 5, fontSize: 15, showsLabel: false)
                .frame(width: 44, height: 44)
                .matchedGeometryEffect(id: "ring", in: namespace)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .matchedGeometryEffect(id: "title", in: namespace)
                    Text("·").foregroundStyle(.secondary)
                    Text("Level \(state.level)")
                        .font(.headline)
                        .matchedGeometryEffect(id: "level", in: namespace)
                    RankBadge(rank: theme.rank(forLevel: state.level), size: 16)
                }
                ProgressView(value: state.levelProgress)
                    .tint(.accentColor)
                    .matchedGeometryEffect(id: "xpbar", in: namespace)
            }
            Spacer(minLength: 8)
            dayXPText
                .font(.subheadline.weight(.semibold).monospacedDigit())
        }
    }

    private var dayXPText: some View {
        let rounded = Int(dayXP.rounded())
        return Text(rounded >= 0 ? "+\(rounded) XP" : "\(rounded) XP")
            .foregroundStyle(rounded >= 0 ? AnyShapeStyle(.secondary) : AnyShapeStyle(.red))
            .contentTransition(.numericText())
    }

    private func xp(_ value: Double) -> String {
        Int(value.rounded()).formatted()
    }
}

/// 0–100 ring. Negative scores (after a slip) fill red.
struct ScoreRing: View {
    let score: Double
    var lineWidth: CGFloat = 14
    var fontSize: CGFloat = 40
    var showsLabel = true

    private var color: Color {
        switch score {
        case ..<0: .red
        case ..<40: .orange
        case ..<70: .yellow
        default: .accentColor
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(abs(score) / 100, 1))
                .stroke(color.gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(score.rounded()))")
                    .font(.system(size: fontSize, weight: .bold, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText(value: score))
                    .minimumScaleFactor(0.6)
                if showsLabel {
                    Text("score")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .animation(.spring(duration: 0.5), value: score)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily score \(Int(score.rounded())) out of 100")
    }
}
