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
                ProgressTabView()
            }
            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
            }
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
        hasOnboarded = false
    }
}
