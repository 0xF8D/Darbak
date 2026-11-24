// دربك — © 0xF8D
//
// انفجار نيون + اهتزاز أول ما تفتح درع جديد

import SwiftUI

struct CelebrationView: View {
    let tier: BadgeTier
    var onDone: () -> Void

    @State var go = false
    @State var badgeIn = false

    var body: some View {
        ZStack {
            Color.black.opacity(go ? 0.6 : 0)
                .ignoresSafeArea()

            // حلقات تنفجر
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(tier.gradient, lineWidth: 5)
                    .frame(width: 130, height: 130)
                    .scaleEffect(CGFloat(go ? 3.6 + Double(i) : 0.3))
                    .opacity(go ? 0 : 0.95)
                    .shadow(color: tier.primary, radius: 12)
                    .animation(.easeOut(duration: 1.3).delay(Double(i) * 0.15), value: go)
            }

            // شرارات
            ForEach(0..<28, id: \.self) { i in
                Capsule()
                    .fill(i % 2 == 0 ? tier.primary : tier.secondary)
                    .frame(width: 4, height: i % 3 == 0 ? 22 : 14)
                    .shadow(color: tier.primary, radius: 6)
                    .offset(y: go ? -CGFloat(170 + (i % 4) * 30) : -20)
                    .rotationEffect(.degrees(Double(i) * (360.0 / 28.0)))
                    .opacity(go ? 0 : 1)
                    .animation(.easeOut(duration: 1.1).delay(0.05), value: go)
            }

            VStack(spacing: 16) {
                CrystalBadge(tier: tier, size: 170)
                    .scaleEffect(badgeIn ? 1 : 0.1)
                    .rotationEffect(.degrees(badgeIn ? 0 : -40))
                    .animation(.spring(response: 0.55, dampingFraction: 0.55), value: badgeIn)

                VStack(spacing: 6) {
                    Text("درع جديد!")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: tier.primary, radius: 12)
                    Text("وصلت \(Fmt.num(tier.steps)) خطوة يا وحش 🔥")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(tier.primary)
                }
                .opacity(badgeIn ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.25), value: badgeIn)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onDone() }
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) { go = true }
            badgeIn = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) { onDone() }
        }
    }
}
