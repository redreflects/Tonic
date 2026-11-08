import SwiftData
import SwiftUI
import TonicKit

struct HealthSettingsSection: View {
    @Environment(\.modelContext) private var context
    @AppStorage(AppSettings.healthSyncEnabled) private var enabled = false
    @Query(sort: \TrackedBehavior.priorityRank) private var tracked: [TrackedBehavior]
    @State private var status: String?
    @State private var working = false

    private var health: HealthSync { .shared }

    var body: some View {
        Section {
            if health.isAvailable {
                Toggle("Sync from Apple Health", isOn: $enabled)
                if enabled {
                    let names = Dictionary(tracked.filter(\.isEnabled).map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
                    let covered = HealthImport.sources.filter { names[$0.behaviorID] != nil }
                    if covered.isEmpty {
                        Text("None of your habits can be filled in from Health yet. Sleep, Steps, Exercise, Meditate and Hydration can.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(covered, id: \.behaviorID) { source in
                            LabeledContent(names[source.behaviorID] ?? "", value: source.description)
                                .font(.subheadline)
                        }
                    }
                    Button {
                        Task { await syncNow() }
                    } label: {
                        HStack {
                            Text("Sync now")
                            Spacer()
                            if working { ProgressView() }
                        }
                    }
                    .disabled(working)
                    #if DEBUG
                    Button("Write sample Health data (last 7 days)") {
                        Task {
                            working = true
                            do {
                                try await health.requestAccess()
                                try await health.writeSampleData()
                                await syncNow()
                            } catch {
                                status = "Couldn't write sample data: \(error.localizedDescription)"
                            }
                            working = false
                        }
                    }
                    #endif
                }
            } else {
                Text("Apple Health isn't available on this device.")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Apple Health")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if let status { Text(status) }
                Text("Fills in the last two weeks automatically each time you open Tonic. Anything you log by hand always wins. Health data stays on this phone.")
            }
        }
        .onChange(of: enabled) { _, isOn in
            guard isOn else { status = nil; return }
            Task { await syncNow() }
        }
    }

    private func syncNow() async {
        working = true
        defer { working = false }
        do {
            try await health.requestAccess()
            let changed = await health.sync(context: context)
            status = changed == 0
                ? "Up to date. If nothing fills in, check that Tonic is allowed to read your data in the Health app."
                : "Filled in \(changed) entr\(changed == 1 ? "y" : "ies") from Apple Health."
        } catch {
            status = "Couldn't connect to Apple Health: \(error.localizedDescription)"
        }
    }
}
