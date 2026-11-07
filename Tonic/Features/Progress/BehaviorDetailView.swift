import Charts
import SwiftUI
import TonicKit

/// History and records for a single habit.
struct BehaviorDetailView: View {
    let behavior: Behavior
    let state: ProgressionState
    let logs: [DailyLog]

    var body: some View {
        let progress = state.behaviors[behavior.id] ?? BehaviorProgress()
        let entries = logs
            .filter { $0.behaviorID == behavior.id }
            .sorted { $0.dayIndex < $1.dayIndex }
        let recent = entries.filter { $0.dayIndex > Day(.now).index - 30 }
        let hitDays = state.days.suffix(30).filter { result in
            let value = recent.first { $0.dayIndex == result.day.index }?.value
            return Quality.evaluate(behavior, value).hit
        }.count
        let tracked = min(state.days.count, 30)

        List {
            Section {
                HStack(spacing: 14) {
                    BehaviorIcon(behavior: behavior, size: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(behavior.name).font(.title3.bold())
                        Text(behavior.detail).font(.subheadline).foregroundStyle(.secondary)
                        if behavior.isFocus {
                            Label("Focus habit", systemImage: "star.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.yellow)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow {
                        stat("\(progress.streak)", "Current streak", icon: "flame.fill", color: .orange)
                        stat("\(progress.bestStreak)", "Best streak", icon: "crown.fill", color: .yellow)
                    }
                    GridRow {
                        stat(tracked > 0 ? formatPercent(Double(hitDays) / Double(tracked)) : "–", "Hit rate, 30 days", icon: "target", color: .accentColor)
                        if behavior.kind == .avoid {
                            stat("\(progress.totalSlips)", "Total slips", icon: "exclamationmark.triangle.fill", color: .red)
                        } else {
                            stat("\(progress.shields)", "Shields ready", icon: "shield.fill", color: .blue)
                        }
                    }
                    if behavior.kind == .volume {
                        GridRow {
                            stat(formatAmount(progress.bestDay), "Best day (\(behavior.unit ?? ""))", icon: "trophy.fill", color: .yellow)
                            stat(formatAmount(progress.bestWeek), "Best week (\(behavior.unit ?? ""))", icon: "trophy.fill", color: .yellow)
                        }
                    }
                }
                .padding(.vertical, 6)
            }

            Section("Last 30 days") {
                if recent.isEmpty {
                    Text("No logs yet.").foregroundStyle(.secondary)
                } else {
                    Chart(recent, id: \.dayIndex) { log in
                        BarMark(
                            x: .value("Day", Day(index: log.dayIndex).date, unit: .day),
                            y: .value(yLabel, plotValue(log.value))
                        )
                        .foregroundStyle(barColor(log.value))
                        .cornerRadius(2)
                        if let target = behavior.target, behavior.kind == .target || behavior.kind == .volume {
                            RuleMark(y: .value("Target", target))
                                .foregroundStyle(.secondary)
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 7)) {
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    }
                    .chartYAxis(behavior.kind == .check || behavior.kind == .avoid ? .hidden : .automatic)
                    .frame(height: 180)
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle(behavior.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var yLabel: String { behavior.unit?.capitalized ?? "Done" }

    private func plotValue(_ value: LogValue) -> Double {
        switch value {
        case .amount(let a): a
        case .completed(let done): done ? 1 : 0
        case .slipped(let slipped): slipped ? -1 : 1
        case .quality(let q): q
        }
    }

    private func barColor(_ value: LogValue) -> Color {
        if case .slipped(true) = value { return .red }
        if case .amount(let a) = value, behavior.direction == .atMost, let t = behavior.target, a > t { return .red }
        return behavior.category.color
    }

    private func stat(_ value: String, _ label: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(value, systemImage: icon)
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
