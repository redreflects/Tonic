import CoreTransferable
import SwiftData
import SwiftUI
import TonicKit
import UniformTypeIdentifiers

/// Everything Tonic stores, as one readable JSON file the user owns.
struct TonicExport: Codable, Transferable {
    struct Log: Codable {
        var behaviorID: String
        var day: String
        var value: LogValue
        var fromAppleHealth: Bool
    }

    var format = "tonic-export"
    var version = 1
    var exportedAt: Date
    var rankTheme: String
    var journeyStartDay: String?
    var behaviors: [Behavior]
    var logs: [Log]

    @MainActor
    init(context: ModelContext) {
        let defaults = UserDefaults.standard
        let tracked = (try? context.fetch(FetchDescriptor<TrackedBehavior>(sortBy: [SortDescriptor(\.priorityRank)]))) ?? []
        let saved = (try? context.fetch(FetchDescriptor<DailyLog>(sortBy: [SortDescriptor(\.dayIndex)]))) ?? []
        let start = defaults.integer(forKey: AppSettings.journeyStartDay)

        exportedAt = .now
        rankTheme = defaults.string(forKey: AppSettings.rankThemeID) ?? RankTheme.plant.id
        journeyStartDay = start == 0 ? nil : Self.dateString(Day(index: start))
        behaviors = tracked.map(\.behavior)
        logs = saved.map {
            Log(behaviorID: $0.behaviorID, day: Self.dateString(Day(index: $0.dayIndex)), value: $0.value, fromAppleHealth: $0.isFromHealth)
        }
    }

    var fileName: String { "Tonic-export-\(Self.dateString(Day(exportedAt))).json" }

    func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { export in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(export.fileName)
            try export.jsonData().write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }

    private static func dateString(_ day: Day) -> String {
        let c = day.components
        return String(format: "%04d-%02d-%02d", c.year, c.month, c.day)
    }
}

/// Settings section with the export button.
struct DataSettingsSection: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        ShareLink(
            item: TonicExport(context: context),
            preview: SharePreview("Tonic data export", image: Image(systemName: "doc.text"))
        ) {
            Label("Export my data", systemImage: "square.and.arrow.up")
        }
    }
}
