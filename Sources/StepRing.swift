// دربك — © 0xF8D

import SwiftUI

struct StepRing: View {
    let steps: Int
    let goal: Int

    private var raw: Double { Double(steps) / Double(max(goal, 1)) }
    private var progress: Double { min(raw, 1) }
    private var overflow: Double { min(max(raw - 1, 0), 1) }
    private var tier: BadgeTier? { BadgeTier.highest(for: steps) }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let lw = size * 0.085
            let r = (size - lw) / 2

            ZStack {
                // توهج خلفي
                Circle()
                    .fill(RadialGradient(colors: [Palette.blue.opacity(0.28), Palette.violet.opacity(0.08), .clear],
                                         center: .center, startRadius: size * 0.1, endRadius: size * 0.62))
                    .scaleEffect(1.15)

                // تدريجات داخلية
                ForEach(0..<48, id: \.self) { i in
                    let major = i % 4 == 0
                    Capsule()
                        .fill(Color.white.opacity(major ? 0.28 : 0.1))
                        .frame(width: major ? 2.2 : 1.4, height: major ? lw * 0.42 : lw * 0.24)
                        .offset(y: -(r - lw * 1.05))
                        .rotationEffect(.degrees(Double(i) * 7.5))
                }

                // المسار
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: lw)
                Circle()
                    .stroke(Palette.bgTop.opacity(0.6), lineWidth: lw * 0.55)

                // التقدم
                Circle()
                    .trim(from: 0, to: max(progress, 0.002))
                    .stroke(
                        AngularGradient(colors: Palette.ring,
                                        center: .center,
                                        startAngle: .degrees(0),
                                        endAngle: .degrees(360 * max(progress, 0.05))),
                        style: StrokeStyle(lineWidth: lw, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Palette.cyan.opacity(0.55), radius: 10)
                    .shadow(color: Palette.violet.opacity(0.45), radius: 24)

                // لفة ذهبية لو تعديت هدفك
                if overflow > 0 {
                    Circle()
                        .trim(from: 0, to: overflow)
                        .stroke(LinearGradient(colors: [Palette.goldLight, Palette.gold],
                                               startPoint: .top, endPoint: .bottom),
                                style: StrokeStyle(lineWidth: lw * 0.32, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: Palette.gold.opacity(0.8), radius: 8)
                }

                // نقاط الدروع على الحلقة
                ForEach(BadgeTier.all.filter { $0.steps <= goal }) { t in
                    let f = Double(t.steps) / Double(max(goal, 1))
                    let a = (-90 + 360 * f) * Double.pi / 180
                    let reached = steps >= t.steps
                    Circle()
                        .fill(reached ? t.primary : Color.white.opacity(0.25))
                        .overlay(Circle().stroke(Color.white.opacity(reached ? 0.9 : 0.3), lineWidth: 1.5))
                        .frame(width: lw * 0.42, height: lw * 0.42)
                        .shadow(color: reached ? t.primary : .clear, radius: 6)
                        .position(x: size / 2 + r * CGFloat(cos(a)), y: size / 2 + r * CGFloat(sin(a)))
                }

                // رأس الحلقة المضيء
                if progress > 0.01 {
                    let a = (-90 + 360 * progress) * Double.pi / 180
                    Circle()
                        .fill(Color.white)
                        .frame(width: lw * 0.5, height: lw * 0.5)
                        .shadow(color: .white, radius: 5)
                        .shadow(color: Palette.pink, radius: 10)
                        .position(x: size / 2 + r * CGFloat(cos(a)), y: size / 2 + r * CGFloat(sin(a)))
                }

                center(size: size)
                    .padding(.horizontal, lw * 1.8)
            }
            .frame(width: size, height: size)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
            .animation(.spring(response: 0.9, dampingFraction: 0.8), value: progress)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func center(size: CGFloat) -> some View {
        VStack(spacing: size * 0.02) {
            ZStack {
                if let tier {
                    CrystalBadge(tier: tier, size: size * 0.2)
                        .id(tier.steps)
                        .transition(.scale(scale: 0.2).combined(with: .opacity))
                } else {
                    Image(systemName: "figure.walk")
                        .font(.system(size: size * 0.085, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [Palette.cyan, Palette.blue], startPoint: .top, endPoint: .bottom))
                        .shadow(color: Palette.cyan.opacity(0.7), radius: 8)
                }
            }
            .frame(height: size * 0.2)
            .animation(.spring(response: 0.6, dampingFraction: 0.6), value: tier?.steps)

            Text(Fmt.num(steps))
                .font(.system(size: size * 0.19, weight: .heavy, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.white, Color(hex: 0xBFD4FF)], startPoint: .top, endPoint: .bottom))
                .shadow(color: Palette.blue.opacity(0.6), radius: 12)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: steps)

            Text("من \(Fmt.num(goal)) خطوة")
                .font(.system(size: size * 0.048, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.text2)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.07), in: Capsule())
        }
    }
}
