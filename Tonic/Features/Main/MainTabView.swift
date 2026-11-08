import SwiftData
import SwiftUI
import TonicKit
import WidgetKit

struct MainTabView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppSettings.healthSyncEnabled) private var healthSyncEnabled = false
    /// Changes when the calendar day does, so Today and Progress roll over at midnight.
    @State private var currentDay = Day(.now)

    var body: some View {
        TabView {
            Tab("Today", systemImage: "sun.max.fill") {
                TodayView()
            }
            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis") {
                ProgressTabView()
            }
            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
        .id(currentDay)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            refreshDay()
        }
        // Pull in new Apple Health data whenever the app comes to the front.
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            refreshDay()
            guard healthSyncEnabled else { return }
            Task { await HealthSync.shared.sync(context: context) }
        }
    }
}

extension MainTabView {
    fileprivate func refreshDay() {
        let today = Day(.now)
        if today != currentDay { currentDay = today }
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
                Section {
                    NavigationLink {
                        ManageHabitsView()
                    } label: {
                        Label("Manage habits", systemImage: "list.bullet.rectangle")
                    }
                } footer: {
                    Text("Add new habits, turn some off, re-rank, change Focus habits or edit targets.")
                }
                ReminderSettingsSection()

                HealthSettingsSection()

                Section("Rank theme") {
                    Picker("Theme", selection: $rankThemeID) {
                        ForEach(RankTheme.all) { theme in
                            Text(theme.displayName).tag(theme.id)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    DataSettingsSection()
                    Button("Erase all data and start over", role: .destructive) {
                        confirmingReset = true
                    }
                } footer: {
                    Text("Your data is stored only on this phone. Export saves everything as a JSON file you can keep or move.")
                }
                #if DEBUG
                Section {
                    Button("Add 30 days of sample history") {
                        SampleHistory.add(days: 30, context: context)
                    }
                } header: {
                    Text("Developer")
                } footer: {
                    Text("Debug builds only. Fills in the 30 days before your start date with realistic logs.")
                }
                #endif
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
        UserDefaults.standard.removeObject(forKey: AppSettings.journeyStartDay)
        UserDefaults.standard.removeObject(forKey: AppSettings.lastRecapWeek)
        WidgetSnapshot.clear()
        WidgetCenter.shared.reloadAllTimelines()
        hasOnboarded = false
    }
}
