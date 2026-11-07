import SwiftUI
import TonicKit

/// Daily score ring plus level, rank and XP progress.
struct ScoreHeader: View {
    let score: Double
    let dayXP: Double
    let state: ProgressionState
    let theme: RankTheme

    var body: some View {
        HStack(spacing: 20) {
            ScoreRing(score: score)
                .frame(width: 124, height: 124)

            VStack(alignment: .leading, spacing: 6) {
                Label(theme.rank(forLevel: state.level).name, systemImage: theme.symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("Level \(state.level)")
                    .font(.title.bold())
                    .contentTransition(.numericText())
                ProgressView(value: state.levelProgress)
                    .tint(.accentColor)
                Text("\(Int(state.xpIntoLevel.rounded())) / \(Int(state.xpForNextLevel.rounded())) XP")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(dayXP >= 0 ? "+\(Int(dayXP.rounded())) XP this day" : "\(Int(dayXP.rounded())) XP this day")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(dayXP >= 0 ? AnyShapeStyle(.secondary) : AnyShapeStyle(.red))
                    .contentTransition(.numericText())
            }
        }
        .padding(.vertical, 8)
        .animation(.snappy, value: state.totalXP)
    }
}

/// 0–100 ring. Negative scores (after a slip) fill red.
struct ScoreRing: View {
    let score: Double

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
                .stroke(.quaternary, lineWidth: 14)
            Circle()
                .trim(from: 0, to: min(abs(score) / 100, 1))
                .stroke(color.gradient, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(score.rounded()))")
                    .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText(value: score))
                Text("score")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .animation(.spring(duration: 0.5), value: score)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily score \(Int(score.rounded())) out of 100")
    }
}
