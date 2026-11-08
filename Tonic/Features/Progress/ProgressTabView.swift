import Charts
import SwiftData
import SwiftUI
import TonicKit

struct ProgressTabView: View {
    /// All habits, including turned-off ones, so their past days still count.
    @Query(sort: \TrackedBehavior.priorityRank) private var tracked: [TrackedBehavior]
    @Query private var logs: [DailyLog]
    @AppStorage(AppSettings.rankThemeID) private var rankThemeID = RankTheme.plant.id
    @AppStorage(AppSettings.journeyStartDay) private var journeyStartDay = 0

    var body: some View {
        let theme = RankTheme.theme(withID: rankThemeID)
        let state = ProgressCalculator.state(tracked: tracked, logs: logs, journeyStartDay: journeyStartDay)
        let finished = state.days.filter { !$0.isPending }

        NavigationStack {
            List {
                Section {
                    RankLadderCard(state: state, theme: theme)
                }

                Section("Character") {
                    CharacterRadar(stats: CharacterStats.compute(days: state.days, behaviors: tracked.map(\.behavior)))
                }

                Section("You vs. past you") {
                    PastSelfCard(state: state)
                }

                Section {
                    ScoreChart(days: Array(state.days.suffix(30)))
                } header: {
                    Text("Daily score · last 30 days")
                } footer: {
                    if !finished.isEmpty {
                        let average = finished.suffix(30).map(\.score).reduce(0, +) / Double(min(finished.count, 30))
                        Text("Average \(Int(average.rounded())) · best \(Int((finished.map(\.score).max() ?? 0).rounded()))")
                    }
                }

                Section("History") {
                    ScoreCalendar(days: state.days)
                }

                let unlocked = Achievements.unlocked(in: state, behaviors: tracked.map(\.behavior))
                Section {
                    AchievementGrid(unlocked: unlocked)
                } header: {
                    Text("Achievements · \(unlocked.count) of \(Achievements.all.count)")
                }

                Section("Streaks & records") {
                    ForEach(tracked.filter(\.isEnabled).map(\.behavior)) { behavior in
                        NavigationLink {
                            BehaviorDetailView(behavior: behavior, state: state, logs: logs)
                        } label: {
                            RecordRow(behavior: behavior, progress: state.behaviors[behavior.id])
                        }
                    }
                }
            }
            .navigationTitle("Progress")
        }
    }
}

/// Current rank, level progress, and the whole ladder with earned ranks lit up.
private struct RankLadderCard: View {
    let state: ProgressionState
    let theme: RankTheme

    var body: some View {
        let rank = theme.rank(forLevel: state.level)
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                RankBadge(rank: rank, size: 60)
                VStack(alignment: .leading, spacing: 2) {
                    Text(rank.name)
                        .font(.title2.bold())
                    Text("Level \(state.level) · \(Int(state.totalXP.rounded()).formatted()) XP total")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let next = theme.nextRankLevel(after: state.level) {
                let start = Double(rank.tier * RankTheme.levelsPerRank)
                let span = Double(next) - max(start, 1)
                let progress = (Double(state.level) - max(start, 1) + state.levelProgress) / span
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: min(max(progress, 0), 1))
                    Text("\(next - state.level) level\(next - state.level == 1 ? "" : "s") to \(theme.rank(forLevel: next).name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // The ladder
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(theme.rankNames.enumerated()), id: \.offset) { tier, name in
                    let earned = tier <= rank.tier
                    HStack(spacing: 10) {
                        RankBadge(rank: theme.rank(forLevel: max(tier * 10, 1)), size: 22, isEarned: earned)
                        Text(name)
                            .font(.subheadline.weight(tier == rank.tier ? .bold : .regular))
                            .foregroundStyle(earned ? .primary : .secondary)
                        Spacer()
                        Text(tier == theme.rankNames.count - 1 ? "Lv \(tier * 10)+" : "Lv \(max(tier * 10, 1))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 6)
    }
}

/// Bar chart of daily scores; slip days dip below zero in red.
private struct ScoreChart: View {
    let days: [DayResult]

    var body: some View {
        if days.isEmpty {
            Text("Log a day to see your chart.")
                .foregroundStyle(.secondary)
        } else {
            Chart(days, id: \.day) { result in
                BarMark(
                    x: .value("Day", result.day.date, unit: .day),
                    y: .value("Score", result.score)
                )
                .foregroundStyle(result.score < 0 ? Color.red : (result.isPending ? Color.accentColor.opacity(0.4) : Color.accentColor))
                .cornerRadius(2)
            }
            .chartYScale(domain: min(-20, (days.map(\.score).min() ?? 0)) ... 100)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) {
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .frame(height: 180)
            .padding(.vertical, 6)
        }
    }
}

/// GitHub-style grid: one square per day, darker = higher score.
private struct ScoreCalendar: View {
    let days: [DayResult]
    private let weeksShown = 15

    var body: some View {
        let today = Day(.now)
        let scores = Dictionary(days.map { ($0.day.index, $0) }, uniquingKeysWith: { _, last in last })
        let firstMonday = today.advanced(by: -today.weekday - (weeksShown - 1) * 7)

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 4) {
                VStack(spacing: 4) {
                    ForEach(["M", "", "W", "", "F", "", "S"].indices, id: \.self) { i in
                        Text(["M", "", "W", "", "F", "", "S"][i])
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .frame(width: 10, height: 16)
                    }
                }
                ForEach(0..<weeksShown, id: \.self) { week in
                    VStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { weekday in
                            let day = firstMonday.advanced(by: week * 7 + weekday)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(color(for: scores[day.index], isFuture: day > today))
                                .frame(width: 16, height: 16)
                                .overlay {
                                    if day == today {
                                        RoundedRectangle(cornerRadius: 3).strokeBorder(.primary.opacity(0.6), lineWidth: 1.5)
                                    }
                                }
                        }
                    }
                }
            }
            HStack(spacing: 4) {
                Text("Less").font(.caption2).foregroundStyle(.secondary)
                ForEach([0.0, 30, 60, 90], id: \.self) { score in
                    RoundedRectangle(cornerRadius: 2).fill(color(forScore: score)).frame(width: 10, height: 10)
                }
                Text("More").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                RoundedRectangle(cornerRadius: 2).fill(.red.opacity(0.7)).frame(width: 10, height: 10)
                Text("Slip day").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Calendar of daily scores for the last \(weeksShown) weeks")
    }

    private func color(for result: DayResult?, isFuture: Bool) -> Color {
        guard !isFuture, let result else { return Color.secondary.opacity(isFuture ? 0.05 : 0.12) }
        return color(forScore: result.score)
    }

    private func color(forScore score: Double) -> Color {
        if score < 0 { return .red.opacity(0.7) }
        if score == 0 { return Color.secondary.opacity(0.12) }
        return Color.accentColor.opacity(0.2 + 0.8 * min(score, 100) / 100)
    }
}

/// One line per habit: current streak, best streak, and PR for volume habits.
private struct RecordRow: View {
    let behavior: Behavior
    let progress: BehaviorProgress?

    var body: some View {
        HStack(spacing: 12) {
            BehaviorIcon(behavior: behavior, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(behavior.name)
                HStack(spacing: 10) {
                    Label("\(progress?.streak ?? 0)", systemImage: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("Best \(progress?.bestStreak ?? 0)")
                        .foregroundStyle(.secondary)
                    if behavior.kind == .volume, let best = progress?.bestDay, best > 0 {
                        Label("\(formatAmount(best)) \(behavior.unit ?? "")", systemImage: "trophy.fill")
                            .foregroundStyle(.yellow)
                    }
                }
                .font(.caption.monospacedDigit())
            }
        }
    }
}

extension Day {
    /// Midday on this day in the user's calendar, for charts.
    var date: Date {
        let reference = DateComponents(calendar: .current, year: 1970, month: 1, day: 1, hour: 12).date ?? .distantPast
        return Calendar.current.date(byAdding: .day, value: index, to: reference) ?? reference
    }
}
