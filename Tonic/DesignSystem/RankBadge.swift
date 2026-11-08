import SwiftUI
import TonicKit

/// A rank's badge: its symbol on a shield whose metal gets richer with each rank.
struct RankBadge: View {
    let rank: Rank
    var size: CGFloat = 44
    /// Locked ranks are drawn in grey.
    var isEarned = true

    /// Bronze → silver → gold → emerald → sapphire → amethyst → ruby → prismatic.
    static let metals: [[Color]] = [
        [Color(red: 0.80, green: 0.52, blue: 0.30), Color(red: 0.55, green: 0.33, blue: 0.18)],
        [Color(red: 0.82, green: 0.84, blue: 0.88), Color(red: 0.52, green: 0.56, blue: 0.62)],
        [Color(red: 1.00, green: 0.82, blue: 0.30), Color(red: 0.82, green: 0.55, blue: 0.08)],
        [Color(red: 0.30, green: 0.85, blue: 0.60), Color(red: 0.05, green: 0.52, blue: 0.38)],
        [Color(red: 0.35, green: 0.62, blue: 1.00), Color(red: 0.12, green: 0.28, blue: 0.75)],
        [Color(red: 0.72, green: 0.48, blue: 1.00), Color(red: 0.42, green: 0.18, blue: 0.72)],
        [Color(red: 1.00, green: 0.38, blue: 0.45), Color(red: 0.68, green: 0.08, blue: 0.20)],
        [Color(red: 1.00, green: 0.55, blue: 0.85), Color(red: 0.40, green: 0.75, blue: 1.00), Color(red: 0.55, green: 1.00, blue: 0.75)],
    ]

    private var colors: [Color] {
        isEarned ? Self.metals[min(rank.tier, Self.metals.count - 1)] : [Color.gray.opacity(0.35), Color.gray.opacity(0.55)]
    }

    var body: some View {
        ZStack {
            BadgeShape()
                .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            BadgeShape()
                .strokeBorder(.white.opacity(isEarned ? 0.55 : 0.25), lineWidth: max(1, size * 0.04))
                .padding(size * 0.06)
            Image(systemName: rank.symbol)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(.white.opacity(isEarned ? 1 : 0.7))
                .shadow(color: .black.opacity(isEarned ? 0.25 : 0), radius: size * 0.04, y: size * 0.02)
                .offset(y: -size * 0.03)
        }
        .frame(width: size, height: size * 1.1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(rank.name) badge\(isEarned ? "" : ", locked")")
    }
}

/// A shield: flat top with rounded corners, sides curving to a point.
nonisolated struct BadgeShape: InsettableShape {
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let corner = r.width * 0.18
        var p = Path()
        p.move(to: CGPoint(x: r.minX + corner, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - corner, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + corner), control: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.52))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY), control: CGPoint(x: r.maxX, y: r.minY + r.height * 0.86))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.52), control: CGPoint(x: r.minX, y: r.minY + r.height * 0.86))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + corner))
        p.addQuadCurve(to: CGPoint(x: r.minX + corner, y: r.minY), control: CGPoint(x: r.minX, y: r.minY))
        p.closeSubpath()
        return p
    }

    func inset(by amount: CGFloat) -> BadgeShape {
        var copy = self
        copy.inset += amount
        return copy
    }
}

#Preview {
    VStack(spacing: 16) {
        ForEach(RankTheme.all) { theme in
            HStack {
                ForEach(0..<8, id: \.self) { tier in
                    RankBadge(rank: theme.rank(forLevel: max(tier * 10, 1)), size: 40)
                }
            }
        }
    }
    .padding()
}
