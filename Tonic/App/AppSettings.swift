import Foundation

/// `@AppStorage` keys for small app-wide settings.
enum AppSettings {
    static let hasOnboarded = "hasOnboarded"
    static let rankThemeID = "rankThemeID"
    /// `Day.index` of the first day the user tracked anything.
    static let journeyStartDay = "journeyStartDay"
    /// Week number of the last weekly recap shown.
    static let lastRecapWeek = "lastRecapWeek"
    static let reminderEnabled = "reminderEnabled"
    /// Minutes after midnight.
    static let reminderTime = "reminderTime"
}
