import SwiftData
import SwiftUI
import TonicKit

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<TrackedBehavior> { $0.isEnabled }, sort: \TrackedBehavior.priorityRank)
    private var tracked: [TrackedBehavior]
    @Query private var logs: [DailyLog]
    @AppStorage(AppSettings.rankThemeID) private var rankThemeID = RankTheme.plant.id
    @AppStorage(AppSettings.journeyStartDay) private var journeyStartDay = 0

    @State private var showingYesterday = false
    @State private var headerCollapsed = false
    @State private var expandedHeaderHeight: CGFloat = 220
    @State private var celebrations = CelebrationCenter()

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
        let behaviors = tracked.map(\.behavior).filter { ($0.startDay ?? day) <= day }
        let focus = behaviors.filter(\.isFocus)
        let others = behaviors.filter { !$0.isFocus }

        NavigationStack {
            List {
                if !focus.isEmpty {
                    Section("Focus") {
                        ForEach(focus) { row($0, day: day, value: dayLogs[$0.id], state: state) }
                    }
                }
                if !others.isEmpty {
                    Section(focus.isEmpty ? "Habits" : "Everything else") {
                        ForEach(others) { row($0, day: day, value: dayLogs[$0.id], state: state) }
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
        .fullScreenCover(item: $celebrations.levelUp) { moment in
            LevelUpView(moment: moment, theme: theme) { celebrations.levelUp = nil }
        }
    }

    private func row(_ behavior: Behavior, day: Day, value: LogValue?, state: ProgressionState) -> some View {
        CheckInRow(behavior: behavior, value: value, progress: state.behaviors[behavior.id]) { newValue in
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
        withAnimation(.snappy) {
            celebrations.present(
                before: before, after: after, from: day,
                behaviors: tracked.map(\.behavior), theme: theme
            )
        }
    }
}
