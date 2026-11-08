import SwiftData
import SwiftUI
import TonicKit
import WidgetKit

struct TodayView: View {
    @Environment(\.modelContext) private var context
    /// All habits, including turned-off ones, so their past days still count.
    @Query(sort: \TrackedBehavior.priorityRank) private var tracked: [TrackedBehavior]
    @Query private var logs: [DailyLog]
    @AppStorage(AppSettings.rankThemeID) private var rankThemeID = RankTheme.plant.id
    @AppStorage(AppSettings.journeyStartDay) private var journeyStartDay = 0

    @State private var showingYesterday = false
    @State private var headerCollapsed = false
    @State private var expandedHeaderHeight: CGFloat = 220
    @State private var celebrations = CelebrationCenter()
    @AppStorage(AppSettings.lastRecapWeek) private var lastRecapWeek = 0
    @State private var showingRecap = false

    private var theme: RankTheme { RankTheme.theme(withID: rankThemeID) }

    var body: some View {
        let today = Day(.now)
        let state = ProgressCalculator.state(tracked: tracked, logs: logs, journeyStartDay: journeyStartDay, today: today)
        // Yesterday can be filled in until noon, if the journey had started by then.
        let canEditYesterday = ProgressCalculator.pendingDays() == 2 && journeyStartDay != 0 && journeyStartDay < today.index
        let isYesterday = showingYesterday && canEditYesterday
        let day = isYesterday ? today.advanced(by: -1) : today
        let result = state.days.last { $0.day == day }
        let dayLogs = Dictionary(
            logs.filter { $0.dayIndex == day.index }.map { ($0.behaviorID, $0.value) },
            uniquingKeysWith: { _, last in last }
        )
        let healthIDs = Set(logs.filter { $0.dayIndex == day.index && $0.isFromHealth }.map(\.behaviorID))
        let behaviors = tracked.filter(\.isEnabled).map(\.behavior).filter { ($0.startDay ?? day) <= day }
        let focus = behaviors.filter(\.isFocus)
        let others = behaviors.filter { !$0.isFocus }

        NavigationStack {
            List {
                if !focus.isEmpty {
                    Section("Focus") {
                        ForEach(focus) { row($0, day: day, value: dayLogs[$0.id], state: state, fromHealth: healthIDs.contains($0.id)) }
                    }
                }
                if !others.isEmpty {
                    Section(focus.isEmpty ? "Habits" : "Everything else") {
                        ForEach(others) { row($0, day: day, value: dayLogs[$0.id], state: state, fromHealth: healthIDs.contains($0.id)) }
                    }
                }
                if !state.quests.isEmpty {
                    Section {
                        ForEach(state.quests) { QuestRow(progress: $0) }
                    } header: {
                        Text("This week's quests")
                    } footer: {
                        Text("New quests every Monday.")
                    }
                }
            }
            // The header floats on top. The list keeps a fixed top margin equal to the
            // full header height, so shrinking the header never changes the scroll position.
            .contentMargins(.top, expandedHeaderHeight + 4, for: .scrollContent)
            .overlay(alignment: .top) {
                TodayHeader(
                    title: isYesterday ? "Yesterday" : "Today",
                    score: result?.score ?? 0,
                    dayXP: result?.xp ?? 0,
                    state: state,
                    theme: theme,
                    isCollapsed: headerCollapsed,
                    showingYesterday: $showingYesterday,
                    canEditYesterday: canEditYesterday
                )
                // The header stays on screen, so keep it from taking over at huge text sizes.
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                    if !headerCollapsed { expandedHeaderHeight = height }
                }
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, scrolled in
                // Different thresholds for shrinking and growing so the header doesn't flicker.
                if !headerCollapsed && scrolled > 40 {
                    withAnimation(.snappy(duration: 0.3)) { headerCollapsed = true }
                } else if headerCollapsed && scrolled < 8 {
                    withAnimation(.snappy(duration: 0.3)) { headerCollapsed = false }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: canEditYesterday) { _, open in
                if !open { showingYesterday = false }
            }
        }
        .overlay(alignment: .top) {
            if let toast = celebrations.currentToast {
                ToastView(toast: toast)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .id(toast.id)
                    .task(id: toast.id) {
                        try? await Task.sleep(for: .seconds(2.6))
                        withAnimation(.snappy) { celebrations.dismissToast(toast) }
                    }
                    .onTapGesture {
                        withAnimation(.snappy) { celebrations.dismissToast(toast) }
                    }
            }
        }
        .animation(.snappy, value: celebrations.currentToast)
        .onAppear { checkForRecap(state: state, today: today) }
        .task(id: widgetSnapshot(state: state, today: today)) {
            // Keep the home-screen widget in step with today's numbers.
            widgetSnapshot(state: state, today: today).save()
            WidgetCenter.shared.reloadAllTimelines()
        }
        .sheet(isPresented: $showingRecap) {
            recapSheet(state: state, today: today)
        }
        .fullScreenCover(item: $celebrations.levelUp) { moment in
            LevelUpView(moment: moment, theme: theme) { celebrations.levelUp = nil }
        }
    }

    private func row(_ behavior: Behavior, day: Day, value: LogValue?, state: ProgressionState, fromHealth: Bool) -> some View {
        CheckInRow(behavior: behavior, value: value, progress: state.behaviors[behavior.id], fromHealth: fromHealth) { newValue in
            log(newValue, behavior: behavior, day: day, before: state)
        }
    }

    private func log(_ value: LogValue?, behavior: Behavior, day: Day, before: ProgressionState) {
        withAnimation(.snappy) {
            context.setLog(value, behaviorID: behavior.id, day: day, existing: logs)
        }
        // Recompute right away from the saved data to see what this change unlocked.
        let allLogs = (try? context.fetch(FetchDescriptor<DailyLog>())) ?? []
        let after = ProgressCalculator.state(tracked: tracked, logs: allLogs, journeyStartDay: journeyStartDay)
        let behaviors = tracked.map(\.behavior)
        let earnedBefore = Achievements.unlocked(in: before, behaviors: behaviors)
        let earnedAfter = Achievements.unlocked(in: after, behaviors: behaviors)
        withAnimation(.snappy) {
            celebrations.present(before: before, after: after, from: day, behaviors: behaviors, theme: theme)
            celebrations.present(achievements: Achievements.all.filter { earnedAfter[$0.id] != nil && earnedBefore[$0.id] == nil })
        }
    }

    private func widgetSnapshot(state: ProgressionState, today: Day) -> WidgetSnapshot {
        let result = state.days.last { $0.day == today }
        let focus = tracked.filter { $0.isEnabled && $0.isFocus }.map(\.behavior)
        return WidgetSnapshot(
            dayIndex: today.index,
            score: result?.score ?? 0,
            level: state.level,
            levelProgress: state.levelProgress,
            rankName: theme.rank(forLevel: state.level).name,
            rankSymbol: theme.rank(forLevel: state.level).symbol,
            focus: focus.map { b in
                WidgetSnapshot.Habit(
                    name: b.name, icon: b.icon,
                    streak: state.behaviors[b.id]?.streak ?? 0,
                    isDone: (result?.qualities[b.id] ?? 0) >= Tuning.standard.hitThreshold
                )
            },
            longestStreak: state.behaviors.filter { id, _ in tracked.contains { $0.id == id && $0.isEnabled } }.values.map(\.streak).max() ?? 0,
            questsDone: state.quests.filter(\.isComplete).count,
            questsTotal: state.quests.count
        )
    }

    /// Show last week's recap once, the first time the app opens in a new week.
    private func checkForRecap(state: ProgressionState, today: Day) {
        guard journeyStartDay != 0, lastRecapWeek < today.weekIndex else { return }
        if PeriodSummary.week(today.weekIndex - 1, in: state).days > 0 {
            showingRecap = true
        } else {
            lastRecapWeek = today.weekIndex
        }
    }

    private func recapSheet(state: ProgressionState, today: Day) -> some View {
        let lastWeek = today.weekIndex - 1
        let behaviors = tracked.map(\.behavior)
        let earned = Achievements.unlocked(in: state, behaviors: behaviors)
        let newOnes = Achievements.all.filter { earned[$0.id]?.weekIndex == lastWeek }
        let lastDay = state.days.last { $0.day.weekIndex == lastWeek }
        let top = lastDay?.streaks.max { $0.value < $1.value }
        let topName = top.flatMap { entry in behaviors.first { $0.id == entry.key }?.name }
        return WeeklyRecapView(
            lastWeek: PeriodSummary.week(lastWeek, in: state),
            weekBefore: PeriodSummary.week(lastWeek - 1, in: state),
            newAchievements: newOnes,
            topStreak: topName.map { ($0, top?.value ?? 0) },
            onDone: {
                lastRecapWeek = today.weekIndex
                showingRecap = false
            }
        )
        .interactiveDismissDisabled()
    }
}
