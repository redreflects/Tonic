import Foundation

/// `@AppStorage` keys for small app-wide settings.
enum AppSettings {
    static let hasOnboarded = "hasOnboarded"
    static let rankThemeID = "rankThemeID"
    /// `Day.index` of the first day the user tracked anything.
    static let journeyStartDay = "journeyStartDay"
}
