import SwiftUI
import TonicKit

/// Sheet for creating a behavior that isn't in the preset library.
struct CustomBehaviorForm: View {
    let onSave: (Behavior) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var kind: BehaviorKind = .check
    @State private var category: BehaviorCategory = .mind
    @State private var icon = "star.fill"
    @State private var amountText = ""
    @State private var unit = ""
    @State private var direction: TargetDirection = .atLeast

    private static let icons = [
        "star.fill", "heart.fill", "bolt.fill", "flame.fill", "leaf.fill", "drop.fill",
        "book.fill", "pencil", "music.note", "paintbrush.fill", "gamecontroller.fill", "figure.walk",
        "bicycle", "dumbbell.fill", "fork.knife", "cup.and.saucer.fill", "moon.fill", "sun.max.fill",
        "brain.head.profile", "person.2.fill", "phone.fill", "dollarsign.circle.fill", "briefcase.fill", "nosign",
    ]

    private var needsAmount: Bool { kind == .target || kind == .volume }

    /// Parsed as you type, so Add enables right away (a number-formatted field only updates when focus leaves it).
    private var amount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: "."))
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (!needsAmount || (amount ?? 0) > 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, e.g. Practice guitar", text: $name)
                }

                Section {
                    Picker("Type", selection: $kind) {
                        ForEach(BehaviorKind.allCases, id: \.self) { Text($0.shortLabel).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("How it's scored")
                } footer: {
                    Text(kind.explainer)
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
                            TextField("Unit, e.g. minutes", text: $unit)
                        }
                    } header: {
                        Text(kind == .target ? "Target" : "Daily amount for full credit")
                    } footer: {
                        if kind == .volume {
                            Text("Going past this amount earns bonus XP.")
                        }
                    }
                }

                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(BehaviorCategory.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(Self.icons, id: \.self) { symbol in
                            Button {
                                icon = symbol
                            } label: {
                                Image(systemName: symbol)
                                    .font(.title3)
                                    .frame(width: 40, height: 40)
                                    .foregroundStyle(icon == symbol ? .white : category.color)
                                    .background(
                                        icon == symbol ? AnyShapeStyle(category.color.gradient) : AnyShapeStyle(.fill.tertiary),
                                        in: .rect(cornerRadius: 10)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(symbol)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("New behavior")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: save).disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        let trimmedUnit = unit.trimmingCharacters(in: .whitespaces)
        let behavior = Behavior(
            id: "custom_\(UUID().uuidString)",
            name: name.trimmingCharacters(in: .whitespaces),
            kind: kind,
            category: category,
            icon: icon,
            unit: needsAmount && !trimmedUnit.isEmpty ? trimmedUnit : nil,
            target: needsAmount ? amount : nil,
            direction: kind == .target ? direction : .atLeast
        )
        onSave(behavior)
        dismiss()
    }
}
