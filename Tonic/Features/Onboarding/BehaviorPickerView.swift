import SwiftUI
import TonicKit

struct BehaviorPickerView: View {
    @Bindable var model: OnboardingModel
    let onContinue: () -> Void

    @State private var creatingCustom = false

    var body: some View {
        List {
            let custom = model.catalog.filter { model.customIDs.contains($0.id) }
            if !custom.isEmpty {
                Section("Yours") {
                    ForEach(custom) { selectableRow($0) }
                }
            }

            Section {
                ForEach(model.catalog.filter(\.isCore)) { selectableRow($0) }
            } header: {
                Text("Core")
            } footer: {
                Text("Recommended for everyone. Tap to turn any off.")
            }

            ForEach(BehaviorCategory.allCases, id: \.self) { category in
                let items = model.catalog.filter {
                    !$0.isCore && $0.category == category && !model.customIDs.contains($0.id)
                }
                if !items.isEmpty {
                    Section(category.title) {
                        ForEach(items) { selectableRow($0) }
                    }
                }
            }

            Section {
                Button {
                    creatingCustom = true
                } label: {
                    Label("Create your own", systemImage: "plus.circle.fill")
                }
            }
        }
        .navigationTitle("Choose behaviors")
        .toolbar {
            Button("Create your own", systemImage: "plus") { creatingCustom = true }
        }
        .safeAreaInset(edge: .bottom) {
            ContinueBar(
                title: "Continue",
                isEnabled: model.selectedCount > 0,
                hint: "\(model.selectedCount) selected",
                action: onContinue
            )
        }
        .sheet(isPresented: $creatingCustom) {
            CustomBehaviorForm { model.addCustom($0) }
        }
    }

    private func selectableRow(_ behavior: Behavior) -> some View {
        let isSelected = model.selectedIDs.contains(behavior.id)
        return Button {
            model.toggle(behavior.id)
        } label: {
            HStack {
                BehaviorRow(behavior: behavior)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
