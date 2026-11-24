// دربك — © 0xF8D
//
// الدروع: كريستال زجاجي سداسي بحواف ذهبية، ولمعة تتحرك لما تميّل الجوال.
// الجزء الثابت يترسم مرة وحدة، وبس خط اللمعة يتحدث مع الحركة عشان ما يعلق.

import SwiftUI
import CoreMotion

final class MotionManager: ObservableObject {
    static let shared = MotionManager()

    /// ميلان الجوال (x = يمين/يسار، y = قدام/ورا) — قيمة وحدة عشان تحديث واحد بس كل مرة
    @Published private(set) var tilt = CGPoint.zero

    private let manager = CMMotionManager()
    private var users = 0
    private var smooth = CGPoint.zero

    func start() {
        users += 1
        guard users == 1, manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let x = max(-0.8, min(0.8, motion.attitude.roll))
            let y = max(-0.8, min(0.8, motion.attitude.pitch - 0.6))
            self.smooth.x = self.smooth.x * 0.8 + CGFloat(x) * 0.2
            self.smooth.y = self.smooth.y * 0.8 + CGFloat(y) * 0.2
            // ما نحدّث الشاشة إلا إذا تحرك الجوال فعلًا
            if abs(self.smooth.x - self.tilt.x) > 0.004 || abs(self.smooth.y - self.tilt.y) > 0.004 {
                self.tilt = self.smooth
            }
        }
    }

    func stop() {
        users = max(0, users - 1)
        if users == 0 { manager.stopDeviceMotionUpdates() }
    }
}

struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        for i in 0..<6 {
            let a = (Double(i) * 60 - 90) * Double.pi / 180
            let pt = CGPoint(x: c.x + r * CGFloat(cos(a)), y: c.y + r * CGFloat(sin(a)))
            if i == 0 {
                p.move(to: pt)
            } else {
                p.addLine(to: pt)
            }
        }
        p.closeSubpath()
        return p
    }
}

/// مثلث من مركز السداسي لضلع واحد (أوجه الكريستال)
struct HexFacet: Shape {
    let index: Int

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        func vertex(_ i: Int) -> CGPoint {
            let a = (Double(i % 6) * 60 - 90) * Double.pi / 180
            return CGPoint(x: c.x + r * CGFloat(cos(a)), y: c.y + r * CGFloat(sin(a)))
        }
        var p = Path()
        p.move(to: c)
        p.addLine(to: vertex(index))
        p.addLine(to: vertex(index + 1))
        p.closeSubpath()
        return p
    }
}

struct CrystalBadge: View {
    let colors: [Color]
    let label: String
    var symbol: String? = nil
    var size: CGFloat = 100
    var earned: Bool = true
    var count: Int? = nil
    var animated: Bool = true

    init(tier: BadgeTier, size: CGFloat = 100, earned: Bool = true, count: Int? = nil, animated: Bool = true) {
        self.colors = tier.colors
        self.label = tier.label
        self.size = size
        self.earned = earned
        self.count = count
        self.animated = animated
    }

    init(colors: [Color], label: String, symbol: String? = nil, size: CGFloat = 100,
         earned: Bool = true, count: Int? = nil, animated: Bool = true) {
        self.colors = colors
        self.label = label
        self.symbol = symbol
        self.size = size
        self.earned = earned
        self.count = count
        self.animated = animated
    }

    static func best(size: CGFloat, earned: Bool = true, animated: Bool = true) -> CrystalBadge {
        CrystalBadge(colors: [Palette.gold, Palette.goldDeep], label: "", symbol: "crown.fill",
                     size: size, earned: earned, animated: animated)
    }

    private var c0: Color { colors.first ?? .white }
    private var c1: Color { colors.count > 1 ? colors[1] : c0 }

    var body: some View {
        ZStack {
            // الجزء الثابت يترسم مرة وحدة كصورة (أخف بكثير)
            ZStack {
                goldRim
                crystal
                    .padding(size * 0.075)
                labelView
            }
            .frame(width: size, height: size)
            .drawingGroup()
            .saturation(earned ? 1 : 0)
            .opacity(earned ? 1 : 0.35)
            .shadow(color: earned ? c0.opacity(0.55) : .clear, radius: size * 0.14)

            // اللمعة اللي تتحرك مع ميلان الجوال (هي بس اللي تتحدث)
            if earned {
                CrystalShine(size: size, animated: animated)
                    .padding(size * 0.075)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: size, height: size)
        .overlay(alignment: .topLeading) { countView }
    }

    private var goldRim: some View {
        ZStack {
            Hexagon()
                .fill(AngularGradient(colors: [Palette.goldLight, Palette.gold, Palette.goldDeep,
                                               Palette.gold, Palette.goldLight, Palette.goldDeep,
                                               Palette.goldLight],
                                      center: .center,
                                      startAngle: .degrees(0),
                                      endAngle: .degrees(360)))
            Hexagon()
                .stroke(Color.white.opacity(0.55), lineWidth: max(0.6, size * 0.006))
            Hexagon()
                .stroke(Palette.goldDeep.opacity(0.8), lineWidth: max(0.6, size * 0.008))
                .padding(size * 0.07)
        }
    }

    private var crystal: some View {
        ZStack {
            Hexagon()
                .fill(LinearGradient(colors: [c0, c1, c1.opacity(0.8)], startPoint: .top, endPoint: .bottom))
            ForEach(0..<6, id: \.self) { i in
                HexFacet(index: i).fill(facetColor(i))
            }
            Hexagon()
                .fill(LinearGradient(colors: [Color.white.opacity(0.32), Color.white.opacity(0.02)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .padding(size * 0.15)
            Hexagon()
                .stroke(Color.white.opacity(0.4), lineWidth: max(0.5, size * 0.006))
                .padding(size * 0.15)
            Hexagon()
                .stroke(LinearGradient(colors: [Color.white.opacity(0.85), c0.opacity(0.3)],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: max(0.6, size * 0.008))
        }
    }

    private func facetColor(_ i: Int) -> Color {
        switch i {
        case 0: return Color.white.opacity(0.24)
        case 1: return Color.white.opacity(0.08)
        case 2: return Color.black.opacity(0.12)
        case 3: return Color.black.opacity(0.24)
        case 4: return Color.black.opacity(0.06)
        default: return Color.white.opacity(0.16)
        }
    }

    @ViewBuilder
    private var labelView: some View {
        if let symbol {
            Image(systemName: symbol)
                .font(.system(size: size * 0.3, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [.white, Palette.goldLight], startPoint: .top, endPoint: .bottom))
                .shadow(color: c1.opacity(0.9), radius: size * 0.04)
        } else {
            Text(label)
                .font(.system(size: size * 0.25, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.white, Color.white.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                .shadow(color: c1, radius: size * 0.03)
                .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
                .environment(\.layoutDirection, .leftToRight)
        }
    }

    @ViewBuilder
    private var countView: some View {
        if let count, count > 0 {
            Text("×\(Fmt.num(count))")
                .font(.system(size: max(11, size * 0.13), weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Palette.bgTop.opacity(0.85), in: Capsule())
                .overlay(Capsule().strokeBorder(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing), lineWidth: 1))
                .offset(x: -size * 0.02, y: -size * 0.02)
        }
    }
}

/// خط اللمعة — الوحيد اللي يتابع حساس الحركة، فالتحديث خفيف
struct CrystalShine: View {
    let size: CGFloat
    let animated: Bool
    @ObservedObject var motion = MotionManager.shared

    var body: some View {
        let t = animated ? motion.tilt : CGPoint.zero
        LinearGradient(colors: [.clear, Color.white.opacity(0.6), .clear],
                       startPoint: .leading, endPoint: .trailing)
            .frame(width: size * 0.24, height: size * 1.6)
            .rotationEffect(.degrees(28))
            .offset(x: t.x * size * 1.1 - size * 0.12, y: t.y * size * 0.4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(Hexagon())
            .blendMode(.plusLighter)
            .onAppear { if animated { motion.start() } }
            .onDisappear { if animated { motion.stop() } }
    }
}
