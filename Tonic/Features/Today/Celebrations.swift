import SwiftUI
import TonicKit

/// A big moment that gets the full screen.
struct LevelUpMoment: Identifiable, Equatable {
    let id = UUID()
    let level: Int
    /// Set when this level also starts a new rank.
    let newRank: Rank?
}

/// A small banner that slides in and disappears on its own.
struct Toast: Identifiable, Equatable {
    let id = UUID()
    let icon: String
    let color: Color
    let title: String
    let message: String
}

/// Turns engine events into things to show, and queues the banners.
@Observable
final class CelebrationCenter {
    var levelUp: LevelUpMoment?
    private(set) var toasts: [Toast] = []

    var currentToast: Toast? { toasts.first }

    /// Compares progress before and after a log change and celebrates anything new.
    func present(before: ProgressionState, after: ProgressionState, from day: Day, behaviors: [Behavior], theme: RankTheme) {
        let names = Dictionary(behaviors.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let units = Dictionary(behaviors.map { ($0.id, $0.unit ?? "") }, uniquingKeysWith: { first, _ in first })

        let oldKeys = Set(before.days.filter { $0.day >= day }.flatMap(\.events).map(Self.key))
        let fresh = after.days.filter { $0.day >= day }.flatMap(\.events).filter { !oldKeys.contains(Self.key($0)) }

        for event in fresh {
            if let toast = Self.toast(for: event, names: names, units: units) {
                toasts.append(toast)
            }
        }

        if after.level > before.level {
            let rankChanged = RankTheme.tier(forLevel: after.level) > RankTheme.tier(forLevel: before.level)
            levelUp = LevelUpMoment(level: after.level, newRank: rankChanged ? theme.rank(forLevel: after.level) : nil)
        }
    }

    /// Banners for achievements earned by the latest change.
    func present(achievements: [Achievement]) {
        for a in achievements {
            toasts.append(Toast(icon: a.icon, color: .purple, title: "Achievement: \(a.title)", message: a.detail))
        }
    }

    func dismissToast(_ toast: Toast) {
        toasts.removeAll { $0.id == toast.id }
    }

    /// Identity of an event, ignoring amounts, so nudging a stepper doesn't repeat a banner.
    private static func key(_ event: ProgressEvent) -> String {
        switch event {
        case .bestDay(let id, _): "bestDay:\(id)"
        case .bestWeek(let id, _): "bestWeek:\(id)"
        case .streakRecord(let id, _): "streakRecord:\(id)"
        case .questCompleted(let id, _, _): "quest:\(id)"
        default: "\(event)"
        }
    }

    private static func toast(for event: ProgressEvent, names: [String: String], units: [String: String]) -> Toast? {
        func name(_ id: String) -> String { names[id] ?? "Habit" }
        func amount(_ id: String, _ value: Double) -> String {
            "\(formatAmount(value)) \(units[id] ?? "")".trimmingCharacters(in: .whitespaces)
        }

        switch event {
        case .perfectFocusDay:
            return Toast(icon: "star.circle.fill", color: .yellow, title: "Perfect Focus Day", message: "Every Focus habit done. +25% XP today.")
        case .comboWeek:
            return Toast(icon: "flame.circle.fill", color: .orange, title: "Combo week!", message: "5 strong days this week. +150 XP.")
        case .bestDay(let id, let value):
            return Toast(icon: "trophy.fill", color: .yellow, title: "New personal record", message: "\(name(id)): \(amount(id, value)) in a day.")
        case .bestWeek(let id, let value):
            return Toast(icon: "trophy.fill", color: .yellow, title: "Best week ever", message: "\(name(id)): \(amount(id, value)) this week.")
        case .streakRecord(let id, let days):
            return Toast(icon: "flame.fill", color: .orange, title: "Longest streak yet", message: "\(name(id)): \(days) days and counting.")
        case .streakShieldEarned(let id):
            return Toast(icon: "shield.fill", color: .blue, title: "Streak shield earned", message: "It will cover one missed day of \(name(id)).")
        case .streakShieldUsed(let id):
            return Toast(icon: "shield.lefthalf.filled", color: .blue, title: "Shield used", message: "Your \(name(id)) streak is safe.")
        case .comeback(let id):
            return Toast(icon: "arrow.uturn.up.circle.fill", color: .green, title: "Comeback!", message: "Back on track with \(name(id)). +25 XP.")
        case .slipped(let id):
            return Toast(icon: "exclamationmark.triangle.fill", color: .red, title: "Slip: \(name(id))", message: "Streak reset and no streak bonuses today.")
        case .questCompleted(_, let title, let reward):
            return Toast(icon: "map.fill", color: .accentColor, title: "Quest complete!", message: "\(title). +\(Int(reward)) XP.")
        case .levelUp, .rankUp:
            return nil // shown full screen instead
        }
    }
}

/// The banner itself.
struct ToastView: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.icon)
                .font(.title2)
                .foregroundStyle(toast.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title).font(.subheadline.bold())
                Text(toast.message).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.regularMaterial, in: .rect(cornerRadius: 18))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }
}

/// Full-screen celebration for a new level, bigger for a new rank.
struct LevelUpView: View {
    let moment: LevelUpMoment
    let theme: RankTheme
    let onDismiss: () -> Void

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.accentColor, Color.accentColor.opacity(0.6), .indigo],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if !reduceMotion {
                ConfettiView(count: moment.newRank == nil ? 40 : 90)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack(spacing: 20) {
                Spacer()
                Group {
                    if let rank = moment.newRank {
                        RankBadge(rank: rank, size: 120)
                            .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 96, weight: .bold))
                            .foregroundStyle(.white)
                            .symbolEffect(.bounce, value: appeared)
                    }
                }
                .scaleEffect(appeared ? 1 : 0.3)

                Text(moment.newRank == nil ? "LEVEL UP" : "NEW RANK")
                    .font(.headline.weight(.heavy))
                    .tracking(4)
                    .foregroundStyle(.white.opacity(0.85))

                if let rank = moment.newRank {
                    Text(rank.name)
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                    Text("Level \(moment.level)")
                        .font(.title2.bold())
                        .foregroundStyle(.white.opacity(0.9))
                } else {
                    Text("Level \(moment.level)")
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(nextRankLine)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                Button(action: onDismiss) {
                    Text("Keep going")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(Color.accentColor)
                .controlSize(.large)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
            .padding()
        }
        .sensoryFeedback(.success, trigger: appeared)
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.6, bounce: 0.5)) { appeared = true }
        }
    }

    private var nextRankLine: String {
        guard let next = theme.nextRankLevel(after: moment.level) else { return "Top rank. Legendary." }
        let levelsLeft = next - moment.level
        return "\(levelsLeft) level\(levelsLeft == 1 ? "" : "s") to \(theme.rank(forLevel: next).name)"
    }
}

/// Falling confetti pieces.
struct ConfettiView: View {
    let count: Int
    @State private var falling = false

    private static let colors: [Color] = [.yellow, .pink, .orange, .white, .mint, .cyan, .purple]

    var body: some View {
        GeometryReader { proxy in
            ForEach(0..<count, id: \.self) { i in
                let piece = Piece(seed: i, width: proxy.size.width)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Self.colors[i % Self.colors.count])
                    .frame(width: piece.size, height: piece.size * 1.8)
                    .rotationEffect(.degrees(falling ? piece.spin : 0))
                    .position(
                        x: piece.x + (falling ? piece.drift : 0),
                        y: falling ? proxy.size.height + 40 : -40
                    )
                    .animation(.easeIn(duration: piece.duration).delay(piece.delay), value: falling)
            }
        }
        .onAppear { falling = true }
    }

    /// Deterministic pseudo-random values per piece.
    private struct Piece {
        let x, drift, size, spin, duration, delay: Double

        init(seed: Int, width: Double) {
            func r(_ salt: Int) -> Double {
                let v = sin(Double(seed * 9973 + salt * 131)) * 43758.5453
                return v - v.rounded(.down)
            }
            x = r(1) * width
            drift = (r(2) - 0.5) * 120
            size = 6 + r(3) * 6
            spin = (r(4) - 0.5) * 1080
            duration = 2.2 + r(5) * 1.8
            delay = r(6) * 0.8
        }
    }
}
