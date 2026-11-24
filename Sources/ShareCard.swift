// دربك — © 0xF8D

import SwiftUI
import UIKit

struct ShareCardView: View {
    let steps: Int
    let goal: Int
    let streak: Int
    let longest: Int
    let distanceKm: Double
    let date: Date

    private var tier: BadgeTier? { BadgeTier.highest(for: steps) }
    private var progress: Double { min(Double(steps) / Double(max(goal, 1)), 1) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.bgTop, Color(hex: 0x0B1A48)], startPoint: .top, endPoint: .bottom)
            Circle()
                .fill((tier?.primary ?? Palette.blue).opacity(0.35))
                .frame(width: 300, height: 300)
                .blur(radius: 90)
                .offset(y: -40)
            Circle()
                .fill(Palette.violet.opacity(0.25))
                .frame(width: 220, height: 220)
                .blur(radius: 80)
                .offset(x: 120, y: 200)

            VStack(spacing: 16) {
                HStack {
                    Text("دربك")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(Fmt.dayMonth(date))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.text2)
                }

                Spacer(minLength: 0)

                if let tier {
                    CrystalBadge(tier: tier, size: 130, animated: false)
                } else {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundStyle(Palette.cyan)
                        .frame(height: 130)
                }

                VStack(spacing: 2) {
                    Text(Fmt.num(steps))
                        .font(.system(size: 58, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: (tier?.primary ?? Palette.blue).opacity(0.8), radius: 14)
                    Text(steps >= goal ? "خطوة اليوم · حققت هدفي ✓" : "خطوة اليوم")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(steps >= goal ? Palette.green : Palette.text2)
                }

                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    GeometryReader { g in
                        Capsule()
                            .fill(LinearGradient(colors: Palette.ring, startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(g.size.width * progress, 8))
                    }
                }
                .frame(height: 10)

                HStack(spacing: 10) {
                    pill("🔥 \(Fmt.num(streak)) يوم")
                    pill("📍 \(Fmt.dec(distanceKm)) كم")
                    pill("🏆 أطول \(Fmt.num(longest))")
                }

                Spacer(minLength: 0)

                Text("© 0xF8D")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.text3)
            }
            .padding(24)
        }
        .frame(width: 360, height: 560)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.08), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
    }
}

struct ShareSheetView: View {
    let card: ShareCardView
    @State var image: UIImage?

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 20) {
                Text("بطاقة المشاركة")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 24)

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 480)
                        .shadow(color: Palette.violet.opacity(0.4), radius: 20)

                    ShareLink(item: Image(uiImage: image),
                              preview: SharePreview("دربك", image: Image(uiImage: image))) {
                        Label("شارك", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(NeonButtonStyle(colors: [Palette.violet, Palette.pink]))
                    .padding(.horizontal, 24)
                } else {
                    ProgressView().tint(.white)
                    Spacer()
                }
                Spacer(minLength: 0)
            }
        }
        .onAppear { render() }
    }

    @MainActor
    private func render() {
        let renderer = ImageRenderer(content:
            card
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "ar_SA"))
        )
        renderer.scale = 3
        image = renderer.uiImage
    }
}
