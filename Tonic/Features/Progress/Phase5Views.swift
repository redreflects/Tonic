import SwiftUI
import TonicKit

// MARK: - Quests

/// One weekly quest with its progress bar.
struct QuestRow: View {
    let progress: QuestProgress

    var body: some View {
        let quest = progress.quest
        HStack(spacing: 12) {
            Image(systemName: progress.isComplete ? "checkmark.seal.fill" : quest.icon)
                .font(.title3)
                .foregroundStyle(progress.isComplete ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(quest.title)
                        .font(.subheadline.weight(.medium))
                        .strikethrough(progress.isComplete, color: .secondary)
                    Spacer(minLength: 6)
                    Text("+\(Int(quest.rewardXP)) XP")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(progress.isComplete ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                }
                if case .noSlips = quest.goal {
                    Text(noSlipsCaption)
                        .font(.caption)
                        .foregroundStyle(progress.current > 0 ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                } else {
                    ProgressView(value: progress.fraction)
                        .tint(progress.isComplete ? .accentColor : .orange)
                    Text("\(formatAmount(min(progress.current, progress.target))) / \(formatAmount(progress.target))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var noSlipsCaption: String {
        if progress.isComplete { return "Clean week!" }
        if progress.current > 0 { return "Slipped this week · try again next week" }
        return "No slips so far · completes Sunday night"
    }
}

// MARK: - Character stats

/// Four-axis radar chart of how strong each life area has been lately.
struct CharacterRadar: View {
    let stats: [BehaviorCategory: Double]

    private let categories = BehaviorCategory.allCases

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { proxy in
                let size = min(proxy.size.width, proxy.size.height)
                let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                let radius = size / 2 - 34
                ZStack {
                    ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { ring in
                        polygon(values: categories.map { _ in ring }, center: center, radius: radius)
                            .stroke(.quaternary, lineWidth: 1)
                    }
                    ForEach(categories.indices, id: \.self) { i in
                        Path { path in
                            path.move(to: center)
                            path.addLine(to: point(i, value: 1, center: center, radius: radius))
                        }
                        .stroke(.quaternary, lineWidth: 1)
                    }
                    let values = categories.map { (stats[$0] ?? 0) / 100 }
                    polygon(values: values, center: center, radius: radius)
                        .fill(Color.accentColor.opacity(0.25))
                    polygon(values: values, center: center, radius: radius)
                        .stroke(Color.accentColor, lineWidth: 2)
                    ForEach(categories.indices, id: \.self) { i in
                        let category = categories[i]
                        VStack(spacing: 0) {
                            Text(category.title).font(.caption.bold())
                            Text(stats[category].map { "\(Int($0.rounded()))" } ?? "–")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(stats[category] == nil ? AnyShapeStyle(.tertiary) : AnyShapeStyle(category.color))
                        .position(point(i, value: 1, center: center, radius: radius + 22))
                    }
                }
            }
            .frame(height: 230)
            Text("How consistent each area of your life has been over the last 30 days.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(categories.map { "\($0.title) \(stats[$0].map { Int($0.rounded()) } ?? 0)" }.joined(separator: ", "))
    }

    private func point(_ i: Int, value: Double, center: CGPoint, radius: Double) -> CGPoint {
        let angle = -Double.pi / 2 + Double(i) * 2 * .pi / Double(categories.count)
        return CGPoint(x: center.x + cos(angle) * radius * value, y: center.y + sin(angle) * radius * value)
    }

    private func polygon(values: [Double], center: CGPoint, radius: Double) -> Path {
        Path { path in
            for (i, value) in values.enumerated() {
                let p = point(i, value: max(value, 0.02), center: center, radius: radius)
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.closeSubpath()
        }
    }
}

// MARK: - You vs. past you

struct PastSelfCard: View {
    let state: ProgressionState
    private let today = Day(.now)

    var body: some View {
        // Only finished days, so a half-logged today doesn't drag the numbers down.
        let finished = state.days.filter { !$0.isPending }
        let thisWeek = PeriodSummary(finished.filter { $0.day.weekIndex == today.weekIndex })
        let lastWeek = PeriodSummary.week(today.weekIndex - 1, in: state)
        let thisMonth = PeriodSummary(finished.filter { $0.day.monthKey == today.monthKey })
        let best = PeriodSummary.bestMonth(in: state, before: today)

        VStack(alignment: .leading, spacing: 14) {
            Text("This week vs. last week")
                .font(.subheadline.bold())
            if lastWeek.days == 0 {
                Text("Check back next week to compare.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 10) {
                    compare("Avg score", thisWeek.averageScore, lastWeek.averageScore)
                    compare("XP", thisWeek.xp, lastWeek.xp)
                    compare("80+ days", Double(thisWeek.strongDays), Double(lastWeek.strongDays))
                }
                Text(thisWeek.days == 0 ? "No finished days yet this week. Today counts once it's over." : "\(thisWeek.days) finished day\(thisWeek.days == 1 ? "" : "s") this week. Today counts once it's over.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Text("This month vs. your best month")
                .font(.subheadline.bold())
            if let best {
                HStack(spacing: 10) {
                    compare("Avg score", thisMonth.averageScore, best.summary.averageScore)
                    compare("Perfect Focus", Double(thisMonth.perfectFocusDays), Double(best.summary.perfectFocusDays))
                    compare("Slips", Double(thisMonth.slips), Double(best.summary.slips), lowerIsBetter: true)
                }
                Text("Best month: \(monthName(best.key))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Finish your first month to set a record to beat.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private func compare(_ label: String, _ now: Double, _ then: Double, lowerIsBetter: Bool = false) -> some View {
        let delta = now - then
        let better = lowerIsBetter ? delta < 0 : delta > 0
        let color: Color = abs(delta) < 0.5 ? .secondary : (better ? .green : .red)
        return VStack(alignment: .leading, spacing: 2) {
            Text("\(Int(now.rounded()))")
                .font(.title3.bold().monospacedDigit())
            HStack(spacing: 2) {
                Image(systemName: delta >= 0 ? "arrow.up" : "arrow.down")
                Text("\(Int(abs(delta).rounded()))")
            }
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(color)
            .opacity(abs(delta) < 0.5 ? 0 : 1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func monthName(_ key: Int) -> String {
        let components = DateComponents(year: key / 12, month: key % 12 + 1, day: 1)
        guard let date = Calendar.current.date(from: components) else { return "" }
        return date.formatted(.dateTime.month(.wide).year())
    }
}

// MARK: - Achievements

struct AchievementGrid: View {
    let unlocked: [String: Day]
    @State private var selected: Achievement?

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 14) {
            ForEach(Achievements.all) { achievement in
                let earned = unlocked[achievement.id] != nil
                Button {
                    selected = achievement
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: achievement.icon)
                            .font(.title2)
                            .foregroundStyle(earned ? .white : Color.secondary.opacity(0.5))
                            .frame(width: 54, height: 54)
                            .background(
                                earned ? AnyShapeStyle(Color.accentColor.gradient) : AnyShapeStyle(.fill.tertiary),
                                in: .circle
                            )
                        Text(achievement.title)
                            .font(.caption2)
                            .multilineTextAlignment(.center)
                            .lineLimit(2, reservesSpace: true)
                            .foregroundStyle(earned ? .primary : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(achievement.title), \(earned ? "earned" : "locked"). \(achievement.detail)")
            }
        }
        .padding(.vertical, 8)
        .alert(selected?.title ?? "", isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } })) {
            Button("OK") { selected = nil }
        } message: {
            if let selected {
                if let day = unlocked[selected.id] {
                    Text("\(selected.detail).\nEarned \(day.date.formatted(date: .abbreviated, time: .omitted)).")
                } else {
                    Text("\(selected.detail).\nNot earned yet.")
                }
            }
        }
    }
}

// MARK: - Weekly recap

/// Shown once at the start of a new week, summing up the week before.
struct WeeklyRecapView: View {
    let lastWeek: PeriodSummary
    let weekBefore: PeriodSummary
    let newAchievements: [Achievement]
    let topStreak: (name: String, days: Int)?
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 6) {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.system(size: 52))
                            .foregroundStyle(.tint)
                        Text("Your week in review")
                            .font(.title.bold())
                        Text(headline)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                        GridRow {
                            tile("\(Int(lastWeek.averageScore.rounded()))", "Avg score", delta: lastWeek.averageScore - weekBefore.averageScore, icon: "gauge.with.dots.needle.67percent")
                            tile("+\(Int(lastWeek.xp.rounded()).formatted())", "XP earned", delta: lastWeek.xp - weekBefore.xp, icon: "star.fill")
                        }
                        GridRow {
                            tile("\(lastWeek.strongDays)", "Days at 80+", delta: Double(lastWeek.strongDays - weekBefore.strongDays), icon: "checkmark.circle.fill")
                            tile("\(lastWeek.questsCompleted)", "Quests done", delta: nil, icon: "map.fill")
                        }
                        GridRow {
                            tile("\(lastWeek.perfectFocusDays)", "Perfect Focus", delta: nil, icon: "star.circle.fill")
                            tile("\(lastWeek.slips)", "Slips", delta: nil, icon: "exclamationmark.triangle.fill")
                        }
                    }

                    if let topStreak {
                        Label("Longest streak: \(topStreak.name), \(topStreak.days) days", systemImage: "flame.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.orange)
                    }

                    if !newAchievements.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Achievements earned").font(.headline)
                            ForEach(newAchievements) { a in
                                Label(a.title, systemImage: a.icon)
                                    .foregroundStyle(.tint)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.fill.quinary, in: .rect(cornerRadius: 14))
                    }
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                ContinueBar(title: "Start this week", action: onDone)
            }
        }
    }

    private var headline: String {
        if weekBefore.days == 0 { return "Here's how your first week went." }
        let change = lastWeek.averageScore - weekBefore.averageScore
        if change >= 3 { return "Up \(Int(change.rounded())) points from the week before. Keep it rolling." }
        if change <= -3 { return "Down \(Int((-change).rounded())) points from the week before. New week, fresh start." }
        return "Steady week. Consistency is what compounds."
    }

    private func tile(_ value: String, _ label: String, delta: Double?, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(value, systemImage: icon)
                .font(.title3.bold().monospacedDigit())
            HStack(spacing: 4) {
                Text(label).foregroundStyle(.secondary)
                if let delta, abs(delta) >= 0.5 {
                    Text(delta > 0 ? "▲\(Int(delta.rounded()))" : "▼\(Int((-delta).rounded()))")
                        .foregroundStyle(delta > 0 ? .green : .red)
                }
            }
            .font(.caption.monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.fill.quinary, in: .rect(cornerRadius: 14))
    }
}
