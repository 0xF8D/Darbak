import SwiftUI

struct BadgeTier: Identifiable {
    let steps: Int
    let colors: [Color]
    var id: Int { steps }
    var label: String { "\(steps / 1000)K" }
    var primary: Color { colors[0] }
    var secondary: Color { colors[1] }
    var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static let dailyGoal = 10_000

    // تدرجات من الأزرق للبنفسجي، كل درع له تدرج مختلف شوي
    static let all: [BadgeTier] = [
        BadgeTier(steps: 6_000,  colors: [Color(hex: 0x22D3EE), Color(hex: 0x3B82F6)]),
        BadgeTier(steps: 7_000,  colors: [Color(hex: 0x38BDF8), Color(hex: 0x6366F1)]),
        BadgeTier(steps: 8_000,  colors: [Color(hex: 0x3B82F6), Color(hex: 0x8B5CF6)]),
        BadgeTier(steps: 9_000,  colors: [Color(hex: 0x6366F1), Color(hex: 0xA855F7)]),
        BadgeTier(steps: 10_000, colors: [Color(hex: 0x8B5CF6), Color(hex: 0xD946EF)])
    ]
}

struct NeonBadge: View {
    let tier: BadgeTier
    var size: CGFloat = 100
    var earned: Bool = true
    var count: Int? = nil

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [tier.primary.opacity(0.45), tier.secondary.opacity(0.12)],
                                     center: .topLeading, startRadius: 0, endRadius: size))
            Circle().fill(.ultraThinMaterial).opacity(0.25)
            Circle().strokeBorder(tier.gradient, lineWidth: size * 0.05)
            Circle().inset(by: size * 0.10)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            Circle()
                .trim(from: 0.60, to: 0.73)
                .stroke(Color.white.opacity(0.55),
                        style: StrokeStyle(lineWidth: size * 0.035, lineCap: .round))
                .padding(size * 0.075)
            Text(tier.label)
                .font(.system(size: size * 0.31, weight: .heavy, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.white, tier.primary],
                                                startPoint: .top, endPoint: .bottom))
                .shadow(color: tier.primary.opacity(0.9), radius: size * 0.06)
        }
        .frame(width: size, height: size)
        .saturation(earned ? 1 : 0)
        .opacity(earned ? 1 : 0.4)
        .shadow(color: earned ? tier.primary.opacity(0.65) : .clear, radius: size * 0.16)
        .shadow(color: earned ? tier.secondary.opacity(0.5) : .clear, radius: size * 0.30)
        .overlay(alignment: .topLeading) {
            if let count, count > 0 {
                Text("×\(Fmt.num(count))")
                    .font(.system(size: max(11, size * 0.14), weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.55), in: Capsule())
                    .overlay(Capsule().strokeBorder(tier.gradient, lineWidth: 1))
                    .offset(x: -size * 0.04, y: -size * 0.04)
            }
        }
    }
}
