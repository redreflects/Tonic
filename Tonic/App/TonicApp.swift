import SwiftData
import SwiftUI
import TonicKit

@main
struct TonicApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(Self.container)
    }

    /// Data lives in the shared App Group folder (the widget's group). Spelled out so the
    /// location can't change silently if entitlements change.
    static let container: ModelContainer = {
        let schema = Schema([TrackedBehavior.self, DailyLog.self])
        let config = ModelConfiguration(schema: schema, groupContainer: .identifier(WidgetSnapshot.appGroup))
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Couldn't open Tonic's database: \(error)")
        }
    }()
}

/// Shows onboarding until setup is finished, then the main app.
struct RootView: View {
    @AppStorage(AppSettings.hasOnboarded) private var hasOnboarded = false

    var body: some View {
        if hasOnboarded {
            MainTabView()
        } else {
            OnboardingFlow()
        }
    }
}
