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

    var body: some View {
        let today = Day(.now)
        let state = ProgressCalculator.state(tracked: tracked, logs: logs, journeyStartDay: journeyStartDay, today: today)
        // Yesterday can be filled in until noon, if the journey had started by then.
        let canEditYesterday = ProgressCalculator.pendingDays() == 2 && journeyStartDay != 0 && journeyStartDay < today.index
        let day = showingYesterday && canEditYesterday ? today.advanced(by: -1) : today
        let result = state.days.last { $0.day == day }
        let dayLogs = Dictionary(
            logs.filter { $0.dayIndex == day.index }.map { ($0.behaviorID, $0.value) },
            uniquingKeysWith: { _, last in last }
        )
        let behaviors = tracked.map(\.behavior).filter { ($0.startDay ?? day) <= day }

        NavigationStack {
            List {
                Section {
                    ScoreHeader(
                        score: result?.score ?? 0,
                        dayXP: result?.xp ?? 0,
                        state: state,
                        theme: RankTheme.theme(withID: rankThemeID)
                    )
                    if canEditYesterday {
                        Picker("Day", selection: $showingYesterday) {
                            Text("Today").tag(false)
                            Text("Yesterday").tag(true)
                        }
                        .pickerStyle(.segmented)
                    }
                } footer: {
                    if canEditYesterday {
                        Text("You can finish logging yesterday until noon.")
                    }
                }

                let focus = behaviors.filter(\.isFocus)
                if !focus.isEmpty {
                    Section("Focus") {
                        ForEach(focus) { row($0, day: day, value: dayLogs[$0.id], state: state) }
                    }
                }
                let others = behaviors.filter { !$0.isFocus }
                if !others.isEmpty {
                    Section(focus.isEmpty ? "Habits" : "Everything else") {
                        ForEach(others) { row($0, day: day, value: dayLogs[$0.id], state: state) }
                    }
                }
            }
            .navigationTitle(showingYesterday && canEditYesterday ? "Yesterday" : "Today")
            .onChange(of: canEditYesterday) { _, open in
                if !open { showingYesterday = false }
            }
        }
    }

    private func row(_ behavior: Behavior, day: Day, value: LogValue?, state: ProgressionState) -> some View {
        CheckInRow(behavior: behavior, value: value, progress: state.behaviors[behavior.id]) { newValue in
            withAnimation(.snappy) {
                context.setLog(newValue, behaviorID: behavior.id, day: day, existing: logs)
            }
        }
    }
}
