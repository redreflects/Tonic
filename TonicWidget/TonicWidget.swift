import SwiftUI
import TonicKit
import WidgetKit

private let tonicGreen = Color(red: 0.122, green: 0.722, blue: 0.604)

@main
struct TonicWidgets: WidgetBundle {
    var body: some Widget {
        TodayWidget()
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TonicToday", provider: Provider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today")
        .description("Your daily score, level and Focus habit streaks.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

struct Entry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    let isEmpty: Bool
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, snapshot: .placeholder, isEmpty: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(for: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        // Show the saved numbers now, then a fresh day at midnight.
        let midnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
        completion(Timeline(entries: [entry(for: .now), entry(for: midnight)], policy: .after(midnight)))
    }

    private func entry(for date: Date) -> Entry {
        let today = Day(date).index
        guard let saved = WidgetSnapshot.load() else {
            return Entry(date: date, snapshot: .placeholder, isEmpty: true)
        }
        let snapshot = saved.dayIndex == today ? saved : saved.startingFresh(on: today)
        return Entry(date: date, snapshot: snapshot, isEmpty: false)
    }
}

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: Entry

    private var s: WidgetSnapshot { entry.snapshot }

    var body: some View {
        if entry.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "leaf.circle.fill").font(.title).foregroundStyle(tonicGreen)
                Text("Open Tonic to get started").font(.caption).multilineTextAlignment(.center)
            }
        } else {
            switch family {
            case .accessoryCircular: circular
            case .accessoryRectangular: rectangular
            case .systemMedium: medium
            default: small
            }
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Ring(score: s.score, lineWidth: 7).frame(width: 64, height: 64)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Image(systemName: "flame.fill").foregroundStyle(.orange)
                    Text("\(s.longestStreak)").font(.headline.monospacedDigit())
                }
            }
            Spacer(minLength: 0)
            Label("Level \(s.level)", systemImage: s.rankSymbol)
                .font(.subheadline.bold())
                .foregroundStyle(tonicGreen)
            ProgressView(value: s.levelProgress).tint(tonicGreen)
        }
    }

    private var medium: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Ring(score: s.score, lineWidth: 8).frame(width: 74, height: 74)
                Spacer(minLength: 0)
                Text(s.rankName).font(.caption.bold()).foregroundStyle(tonicGreen).lineLimit(1)
                Text("Level \(s.level)").font(.subheadline.bold())
                ProgressView(value: s.levelProgress).tint(tonicGreen)
            }
            .frame(width: 110)

            VStack(alignment: .leading, spacing: 8) {
                Text("FOCUS").font(.caption2.weight(.heavy)).foregroundStyle(.secondary)
                ForEach(s.focus.prefix(3), id: \.name) { habit in
                    HStack(spacing: 8) {
                        Image(systemName: habit.isDone ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(habit.isDone ? tonicGreen : .secondary)
                        Text(habit.name).font(.caption).lineLimit(1)
                        Spacer(minLength: 4)
                        Label("\(habit.streak)", systemImage: "flame.fill")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.orange)
                    }
                }
                Spacer(minLength: 0)
                if s.questsTotal > 0 {
                    Label("\(s.questsDone)/\(s.questsTotal) quests this week", systemImage: "map.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var circular: some View {
        Gauge(value: min(max(s.score, 0), 100), in: 0...100) {
            Image(systemName: "leaf.fill")
        } currentValueLabel: {
            Text("\(Int(s.score.rounded()))")
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Tonic · Lv \(s.level)").font(.headline)
            Text("Score \(Int(s.score.rounded())) · 🔥 \(s.longestStreak)")
            ProgressView(value: s.levelProgress)
        }
    }
}

private struct Ring: View {
    let score: Double
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle().stroke(.quaternary, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(abs(score) / 100, 1))
                .stroke(score < 0 ? Color.red : tonicGreen, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(score.rounded()))")
                .font(.system(.title3, design: .rounded).bold().monospacedDigit())
                .minimumScaleFactor(0.6)
        }
    }
}

#Preview(as: .systemMedium) {
    TodayWidget()
} timeline: {
    Entry(date: .now, snapshot: .placeholder, isEmpty: false)
}
