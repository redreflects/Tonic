import SwiftUI
import UserNotifications

/// Schedules the single daily "log your day" reminder.
enum ReminderScheduler {
    static let identifier = "tonic.daily-reminder"

    /// Asks for permission if needed. Returns false if notifications are turned off for Tonic.
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    static func schedule(minutesAfterMidnight minutes: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "How did today go?"
        content.body = "Log your habits in Tonic and keep your streaks alive. 🔥"
        content.sound = .default

        var when = DateComponents()
        when.hour = minutes / 60
        when.minute = minutes % 60
        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}

/// Settings section: toggle plus time picker.
struct ReminderSettingsSection: View {
    @AppStorage(AppSettings.reminderEnabled) private var enabled = false
    @AppStorage(AppSettings.reminderTime) private var minutes = 20 * 60 + 30 // 8:30 pm
    @State private var permissionDenied = false

    private var time: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
        } set: { date in
            let c = Calendar.current.dateComponents([.hour, .minute], from: date)
            minutes = (c.hour ?? 20) * 60 + (c.minute ?? 30)
        }
    }

    var body: some View {
        Section {
            Toggle("Daily reminder", isOn: $enabled)
            if enabled {
                DatePicker("Time", selection: time, displayedComponents: .hourAndMinute)
            }
        } header: {
            Text("Reminders")
        } footer: {
            if permissionDenied {
                Text("Notifications are turned off for Tonic. Turn them on in the iPhone Settings app under Notifications → Tonic.")
                    .foregroundStyle(.red)
            } else {
                Text("A nudge each day to log your habits before the day ends.")
            }
        }
        .onChange(of: enabled) { _, isOn in
            if isOn {
                Task {
                    if await ReminderScheduler.requestPermission() {
                        permissionDenied = false
                        ReminderScheduler.schedule(minutesAfterMidnight: minutes)
                    } else {
                        permissionDenied = true
                        enabled = false
                    }
                }
            } else {
                ReminderScheduler.cancel()
            }
        }
        .onChange(of: minutes) { _, newValue in
            if enabled { ReminderScheduler.schedule(minutesAfterMidnight: newValue) }
        }
    }
}
