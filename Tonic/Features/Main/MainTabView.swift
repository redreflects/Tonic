import SwiftData
import SwiftUI
import TonicKit

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Today", systemImage: "sun.max.fill") {
                TodayView()
            }
            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis") {
                ProgressPlaceholderView()
            }
            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
    }
}

/// Temporary Today screen: shows level, rank and tracked behaviors.
/// Daily check-ins and the score ring arrive in Phase 3.
struct TodayView: View {
    @Query(sort: \TrackedBehavior.priorityRank) private var tracked: [TrackedBehavior]
    @AppStorage(AppSettings.rankThemeID) private var rankThemeID = RankTheme.plant.id

    private var theme: RankTheme { RankTheme.theme(withID: rankThemeID) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: theme.symbol)
                            .font(.largeTitle)
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading) {
                            Text("Level 1")
                                .font(.title2.bold())
                            Text(theme.rank(forLevel: 1).name)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    ForEach(tracked.filter(\.isEnabled)) { item in
                        HStack {
                            BehaviorRow(behavior: item.behavior)
                            Spacer()
                            if item.isFocus {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                            }
                        }
                    }
                } header: {
                    Text("Your behaviors")
                } footer: {
                    Text("Daily check-ins are coming next.")
                }
            }
            .navigationTitle("Today")
        }
    }
}

struct ProgressPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Progress",
                systemImage: "chart.line.uptrend.xyaxis",
                description: Text("Streaks, personal records and history will live here.")
            )
            .navigationTitle("Progress")
        }
    }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(AppSettings.rankThemeID) private var rankThemeID = RankTheme.plant.id
    @AppStorage(AppSettings.hasOnboarded) private var hasOnboarded = true
    @State private var confirmingReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Rank theme") {
                    Picker("Theme", selection: $rankThemeID) {
                        ForEach(RankTheme.all) { theme in
                            Text(theme.displayName).tag(theme.id)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    Button("Erase all data and start over", role: .destructive) {
                        confirmingReset = true
                    }
                } footer: {
                    Text("Your data is stored only on this phone.")
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Erase all behaviors and logs? This can't be undone.",
                isPresented: $confirmingReset,
                titleVisibility: .visible
            ) {
                Button("Erase everything", role: .destructive, action: eraseAll)
            }
        }
    }

    private func eraseAll() {
        try? context.delete(model: DailyLog.self)
        try? context.delete(model: TrackedBehavior.self)
        try? context.save()
        hasOnboarded = false
    }
}
