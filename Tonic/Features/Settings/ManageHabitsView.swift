import SwiftData
import SwiftUI
import TonicKit

/// Change which habits you track after setup: add, turn off, re-rank, Focus, edit.
struct ManageHabitsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TrackedBehavior.priorityRank) private var all: [TrackedBehavior]

    @State private var adding = false
    @State private var editing: TrackedBehavior?

    private var active: [TrackedBehavior] { all.filter(\.isEnabled) }
    private var inactive: [TrackedBehavior] { all.filter { !$0.isEnabled } }
    private var focusCount: Int { active.filter(\.isFocus).count }

    var body: some View {
        let weights = Weighting.normalizedWeights(for: active.map(\.behavior))
        List {
            Section {
                ForEach(active) { item in
                    activeRow(item, weight: weights[item.id] ?? 0)
                }
                .onMove(perform: move)
            } header: {
                Text("Tracking · drag to rank")
            } footer: {
                Text("Tap ☆ to make a habit a Focus habit (up to 3). Percentages are each habit's share of a perfect day. Rank and Focus changes apply to your whole history.")
            }

            if !inactive.isEmpty {
                Section {
                    ForEach(inactive) { item in
                        HStack {
                            BehaviorRow(behavior: item.behavior)
                                .opacity(0.6)
                            Spacer()
                            Button("Turn on") { turnOn(item) }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                } header: {
                    Text("Turned off")
                } footer: {
                    Text("Past logs and scores are kept. Turning a habit back on picks up where it left off; the days it was off don't count.")
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Manage habits")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Add habits", systemImage: "plus") { adding = true }
        }
        .sheet(isPresented: $adding) {
            AddHabitsView(existingIDs: Set(all.map(\.id)), onAdd: add)
        }
        .sheet(item: $editing) { item in
            EditHabitView(item: item)
        }
    }

    private func activeRow(_ item: TrackedBehavior, weight: Double) -> some View {
        HStack(spacing: 10) {
            BehaviorRow(behavior: item.behavior)
            Spacer(minLength: 4)
            Text(formatPercent(weight))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Button {
                toggleFocus(item)
            } label: {
                Image(systemName: item.isFocus ? "star.fill" : "star")
                    .font(.title3)
                    .foregroundStyle(item.isFocus ? AnyShapeStyle(.yellow) : AnyShapeStyle(.tertiary))
            }
            .buttonStyle(.plain)
            .disabled(!item.isFocus && focusCount >= OnboardingModel.maxFocus)
            .accessibilityLabel(item.isFocus ? "Remove from Focus" : "Make Focus habit")

            Menu {
                Button("Edit", systemImage: "pencil") { editing = item }
                Button("Turn off", systemImage: "pause.circle", role: .destructive) { turnOff(item) }
                    .disabled(active.count <= 1)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("More options for \(item.name)")
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var list = active
        list.move(fromOffsets: source, toOffset: destination)
        renumber(list)
    }

    private func toggleFocus(_ item: TrackedBehavior) {
        if item.isFocus {
            item.isFocus = false
        } else if focusCount < OnboardingModel.maxFocus {
            item.isFocus = true
        }
        try? context.save()
    }

    private func turnOff(_ item: TrackedBehavior) {
        withAnimation {
            // Focus stays set so past days keep scoring exactly as before.
            item.isEnabled = false
            item.endDayIndex = Day(.now).index
            renumber(active.filter { $0.id != item.id })
        }
    }

    private func turnOn(_ item: TrackedBehavior) {
        withAnimation {
            let today = Day(.now)
            // Skip the days it was off, but keep everything before them.
            if let end = item.endDayIndex, end < today.index {
                item.pausedRanges.append(DayRange(start: Day(index: end), end: today))
            }
            item.endDayIndex = nil
            if item.isFocus && focusCount >= OnboardingModel.maxFocus { item.isFocus = false }
            // Slot it back into its old place in the ranking, so its past days weigh the same.
            var ordered = active
            ordered.insert(item, at: min(max(item.priorityRank, 0), ordered.count))
            item.isEnabled = true
            renumber(ordered)
        }
    }

    private func add(_ behaviors: [Behavior], customIDs: Set<String>) {
        let today = Day(.now)
        let start = active.count
        for (offset, behavior) in behaviors.enumerated() {
            var b = behavior
            b.priorityRank = start + offset
            b.isEnabled = true
            b.isFocus = false
            b.startDay = today
            b.endDay = nil
            context.insert(TrackedBehavior(b, isCustom: customIDs.contains(b.id)))
        }
        try? context.save()
    }

    private func renumber(_ ordered: [TrackedBehavior]) {
        for (index, item) in ordered.enumerated() {
            item.priorityRank = index
        }
        try? context.save()
    }
}

/// Pick new habits from the library or create custom ones.
struct AddHabitsView: View {
    let existingIDs: Set<String>
    let onAdd: ([Behavior], Set<String>) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []
    @State private var custom: [Behavior] = []
    @State private var creatingCustom = false

    private var available: [Behavior] {
        PresetLibrary.all.filter { !existingIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !custom.isEmpty {
                    Section("Yours") {
                        ForEach(custom) { row($0) }
                    }
                }
                ForEach(BehaviorCategory.allCases, id: \.self) { category in
                    let items = available.filter { $0.category == category }
                    if !items.isEmpty {
                        Section(category.title) {
                            ForEach(items) { row($0) }
                        }
                    }
                }
                Section {
                    Button {
                        creatingCustom = true
                    } label: {
                        Label("Create your own", systemImage: "plus.circle.fill")
                    }
                } footer: {
                    Text("New habits count from today, so they won't change past scores. They're added at the bottom of your ranking.")
                }
            }
            .navigationTitle("Add habits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(selected.isEmpty ? "Add" : "Add (\(selected.count))") {
                        let chosen = (custom + available).filter { selected.contains($0.id) }
                        onAdd(chosen, Set(custom.map(\.id)))
                        dismiss()
                    }
                    .disabled(selected.isEmpty)
                }
            }
            .sheet(isPresented: $creatingCustom) {
                CustomBehaviorForm { behavior in
                    custom.append(behavior)
                    selected.insert(behavior.id)
                }
            }
        }
    }

    private func row(_ behavior: Behavior) -> some View {
        SelectableBehaviorRow(behavior: behavior, isSelected: selected.contains(behavior.id)) {
            if selected.contains(behavior.id) {
                selected.remove(behavior.id)
            } else {
                selected.insert(behavior.id)
            }
        }
    }
}

/// Change a habit's name or target.
struct EditHabitView: View {
    let item: TrackedBehavior

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var amountText = ""
    @State private var unit = ""
    @State private var direction: TargetDirection = .atLeast

    private var kind: BehaviorKind { BehaviorKind(rawValue: item.kindRaw) ?? .check }
    private var needsAmount: Bool { kind == .target || kind == .volume }
    private var amount: Double? { Double(amountText.replacingOccurrences(of: ",", with: ".")) }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (!needsAmount || (amount ?? 0) > 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Name", text: $name)
                }
                if needsAmount {
                    Section {
                        if kind == .target {
                            Picker("Goal", selection: $direction) {
                                Text("At least").tag(TargetDirection.atLeast)
                                Text("At most").tag(TargetDirection.atMost)
                            }
                            .pickerStyle(.segmented)
                        }
                        HStack {
                            TextField("Amount", text: $amountText)
                                .keyboardType(.decimalPad)
                            TextField("Unit", text: $unit)
                        }
                    } header: {
                        Text(kind == .target ? "Target" : "Daily amount for full credit")
                    } footer: {
                        Text("Changing the target rescores your past days against the new target.")
                    }
                }
                Section {
                    LabeledContent("Type", value: kind.shortLabel)
                } footer: {
                    Text(kind.explainer)
                }
            }
            .navigationTitle("Edit habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
            .onAppear {
                name = item.name
                // No thousands separator, so "8000" doesn't come back as "8,000" and parse as 8.
                amountText = item.target.map { $0.formatted(.number.grouping(.never).precision(.fractionLength(0...2))) } ?? ""
                unit = item.unit ?? ""
                direction = TargetDirection(rawValue: item.directionRaw) ?? .atLeast
            }
        }
    }

    private func save() {
        item.name = name.trimmingCharacters(in: .whitespaces)
        if needsAmount {
            item.target = amount
            let trimmed = unit.trimmingCharacters(in: .whitespaces)
            item.unit = trimmed.isEmpty ? nil : trimmed
            if kind == .target { item.directionRaw = direction.rawValue }
        }
        try? context.save()
        dismiss()
    }
}
