import SwiftUI

struct StepRing: View {
    let steps: Int
    let goal: Int

    private var progress: Double { min(Double(steps) / Double(goal), 1) }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let lw = size * 0.075
            let r = (size - lw) / 2

            ZStack {
                Circle().stroke(Color.white.opacity(0.07), lineWidth: lw)

                Circle()
                    .trim(from: 0, to: max(progress, 0.002))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [Color(hex: 0x22D3EE), Color(hex: 0x6366F1),
                                                        Color(hex: 0xA855F7), Color(hex: 0xD946EF)]),
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360 * max(progress, 0.02))),
                        style: StrokeStyle(lineWidth: lw, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Color(hex: 0x6366F1).opacity(0.7), radius: 16)

                // نقاط الدروع على الحلقة
                ForEach(BadgeTier.all) { tier in
                    let f = Double(tier.steps) / Double(goal)
                    let a = (-90 + 360 * f) * Double.pi / 180
                    let reached = steps >= tier.steps
                    Circle()
                        .fill(reached ? Color.white : Color.white.opacity(0.25))
                        .frame(width: lw * 0.42, height: lw * 0.42)
                        .shadow(color: reached ? tier.primary : .clear, radius: 6)
                        .position(x: size / 2 + r * cos(a), y: size / 2 + r * sin(a))
                }

                VStack(spacing: size * 0.02) {
                    Text("اليوم")
                        .font(.system(size: size * 0.07, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.6))
                    Text(Fmt.num(steps))
                        .font(.system(size: size * 0.20, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                    Text("الهدف \(Fmt.num(goal)) خطوة")
                        .font(.system(size: size * 0.05, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.07), in: Capsule())
                }
                .padding(.horizontal, lw * 1.6)
            }
            .frame(width: size, height: size)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
            .animation(.spring(response: 0.9, dampingFraction: 0.8), value: progress)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
