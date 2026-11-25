// دربك — © 0xF8D
//
// انفجار نيون + اهتزاز: درع جديد، مستوى جديد، أو تحدي خلص

import SwiftUI

struct CelebrationView: View {
    let event: CelebrationEvent
    var onDone: () -> Void

    @State var go = false
    @State var badgeIn = false

    private var primary: Color { event.colors.first ?? Palette.cyan }
    private var secondary: Color { event.colors.count > 1 ? event.colors[1] : primary }
    private var gradient: LinearGradient {
        LinearGradient(colors: event.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(go ? 0.6 : 0)
                .ignoresSafeArea()

            // حلقات تنفجر
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(gradient, lineWidth: 5)
                    .frame(width: 130, height: 130)
                    .scaleEffect(CGFloat(go ? 3.6 + Double(i) : 0.3))
                    .opacity(go ? 0 : 0.95)
                    .shadow(color: primary, radius: 12)
                    .animation(.easeOut(duration: 1.3).delay(Double(i) * 0.15), value: go)
            }

            // شرارات
            ForEach(0..<28, id: \.self) { i in
                Capsule()
                    .fill(i % 2 == 0 ? primary : secondary)
                    .frame(width: 4, height: i % 3 == 0 ? 22 : 14)
                    .shadow(color: primary, radius: 6)
                    .offset(y: go ? -CGFloat(170 + (i % 4) * 30) : -20)
                    .rotationEffect(.degrees(Double(i) * (360.0 / 28.0)))
                    .opacity(go ? 0 : 1)
                    .animation(.easeOut(duration: 1.1).delay(0.05), value: go)
            }

            VStack(spacing: 16) {
                CrystalBadge(colors: event.colors, label: event.label, symbol: event.symbol, size: 170)
                    .scaleEffect(badgeIn ? 1 : 0.1)
                    .rotationEffect(.degrees(badgeIn ? 0 : -40))
                    .animation(.spring(response: 0.55, dampingFraction: 0.55), value: badgeIn)

                VStack(spacing: 6) {
                    Text(event.title)
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 20)
                        .shadow(color: primary, radius: 12)
                    Text(event.subtitle)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
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
