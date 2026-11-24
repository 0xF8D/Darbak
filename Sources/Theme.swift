// دربك — © 0xF8D

import SwiftUI
import UIKit

struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.bgTop, Palette.bgBottom], startPoint: .top, endPoint: .bottom)
            Circle()
                .fill(Palette.violet.opacity(0.22))
                .frame(width: 360, height: 360)
                .blur(radius: 120)
                .offset(x: 150, y: -330)
            Circle()
                .fill(Palette.cyan.opacity(0.15))
                .frame(width: 340, height: 340)
                .blur(radius: 120)
                .offset(x: -160, y: 360)
            Circle()
                .fill(Palette.blue.opacity(0.10))
                .frame(width: 260, height: 260)
                .blur(radius: 100)
                .offset(x: -120, y: -60)
        }
        .ignoresSafeArea()
    }
}

extension View {
    func glassCard(radius: CGFloat = 22, tint: Color = Palette.blue) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(colors: [Palette.card.opacity(0.85), Palette.cardDeep.opacity(0.85)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [tint.opacity(0.55), Color.white.opacity(0.05), tint.opacity(0.18)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1)
            )
    }

    /// يمرر كل الكائنات المشتركة والاتجاه العربي (نستخدمه للتطبيق وكل الـ sheets)
    func appEnvironment() -> some View {
        self
            .environmentObject(AppSettings.shared)
            .environmentObject(HealthStore.shared)
            .environmentObject(WalkMode.shared)
            .environmentObject(FoodStore.shared)
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "ar_SA"))
            .preferredColorScheme(.dark)
    }
}

enum Haptics {
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func tap() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }
}

func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

/// قراءة أرقام من الكيبورد (تقبل الأرقام العربية ١٢٣ والفاصلة ٫)
enum Num {
    static func parse(_ text: String) -> Double? {
        var s = ""
        for ch in text {
            if let v = ch.wholeNumberValue {
                s.append(String(v))
            } else if ch == "." || ch == "," || ch == "٫" {
                if !s.contains(".") { s.append(".") }
            }
        }
        if s.isEmpty { return nil }
        return Double(s)
    }

    static func string(_ x: Double) -> String {
        if x == x.rounded() { return String(Int(x)) }
        return String(format: "%.1f", x)
    }
}

// MARK: - عناصر مشتركة

struct StatBox: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.8), radius: 6)
            Text(value)
                .font(.system(size: 21, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            Text(unit)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.text2)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .glassCard(radius: 18, tint: color)
    }
}

struct InputField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboard: UIKeyboardType = .default
    var suffix: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.text2)
            HStack(spacing: 6) {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboard)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                if let suffix {
                    Text(suffix)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(Palette.text2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

struct NeonButtonStyle: ButtonStyle {
    var colors: [Color] = [Palette.cyan, Palette.blue]

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .shadow(color: colors[0].opacity(0.5), radius: 10)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct SoftButtonStyle: ButtonStyle {
    var color: Color = Palette.cyan

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(color)
            .padding(.vertical, 9)
            .padding(.horizontal, 14)
            .background(color.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.35), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

struct ScreenTitle: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Palette.text2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10)
    }
}
