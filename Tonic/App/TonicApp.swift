import SwiftData
import SwiftUI

@main
struct TonicApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [TrackedBehavior.self, DailyLog.self])
    }
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
