// دربك — © 0xF8D

import SwiftUI

final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    static let goals = [7_000, 8_000, 9_000, 10_000]

    private let d = UserDefaults.standard

    @Published var goal: Int { didSet { d.set(goal, forKey: "goal") } }
    @Published var milestoneHaptics: Bool { didSet { d.set(milestoneHaptics, forKey: "milestoneHaptics") } }

    init() {
        let g = d.integer(forKey: "goal")
        goal = Self.goals.contains(g) ? g : 8_000
        milestoneHaptics = d.object(forKey: "milestoneHaptics") as? Bool ?? true
    }

}

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var walk: WalkMode
    @EnvironmentObject var health: HealthStore
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        goalCard
                        WaterGoalCard()
                        healthCard
                        toggles
                        walkCard
                        about
                    }
                    .padding(.horizontal, 18)
                    .screenWidth()
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("الإعدادات")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("تم") { dismiss() }
                        .fontWeight(.bold)
                }
            }
        }
    }

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("هدفك اليومي", systemImage: "target")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            HStack(spacing: 10) {
                ForEach(AppSettings.goals, id: \.self) { g in
                    let tier = BadgeTier.tier(g)
                    let on = settings.goal == g
                    Button {
                        settings.goal = g
                        Haptics.tap()
                    } label: {
                        VStack(spacing: 2) {
                            Text(Fmt.num(g / 1000))
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                            Text("آلاف")
                                .font(.system(size: 11, design: .rounded))
                        }
                        .foregroundStyle(on ? Color.white : Palette.text2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(on ? AnyShapeStyle(tier?.gradient ?? LinearGradient(colors: [Palette.blue], startPoint: .top, endPoint: .bottom))
                                         : AnyShapeStyle(Color.white.opacity(0.05)))
                        )
                        .shadow(color: on ? (tier?.primary ?? Palette.blue).opacity(0.6) : .clear, radius: 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("أقل هدف ٧ آلاف، والإشعارات تمشي على هدفك.")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Palette.text3)
        }
        .padding(16)
        .glassCard()
    }

    private var toggles: some View {
        VStack(spacing: 14) {
            Toggle(isOn: $settings.milestoneHaptics) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("📳 اهتزاز كل ١٠٠٠ خطوة")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("يهتز الجوال خفيف كل ما تزيد ألف خطوة")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Palette.text2)
                }
            }
        }
        .tint(Palette.cyan)
        .padding(16)
        .glassCard()
    }

    private var walkCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(get: { walk.isOn }, set: { _ in walk.toggle() })) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("🚶 وضع المشي")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("يخلي التطبيق شغال بالخلفية وتطلع خطواتك على شاشة القفل والجزيرة على طول. ياكل بطارية شوي.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Palette.text2)
                }
            }
            .tint(Palette.cyan)
            if let msg = walk.message {
                Text(msg)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Palette.orange)
            }
        }
        .padding(16)
        .glassCard()
    }

    /// حالة الربط مع «صحتي»: لو مو مربوط يقرأ آخر ٧ أيام بس من عداد الجوال
    private var healthCard: some View {
        let s = healthStatus
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: s.icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(s.color)
                VStack(alignment: .leading, spacing: 3) {
                    Text(s.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(s.detail)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Palette.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let err = health.authError, health.access != .ok {
                Text("رد الجوال: \(err)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Palette.text3)
                    .textSelection(.enabled)
                    .environment(\.layoutDirection, .leftToRight)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if health.access == .noHistory || health.access == .blocked {
                HStack(spacing: 8) {
                    if health.access == .noHistory {
                        Button {
                            if let url = URL(string: "x-apple-health://") { openURL(url) }
                        } label: {
                            Label("افتح الصحة", systemImage: "heart.fill")
                        }
                        .buttonStyle(SoftButtonStyle(color: Palette.pink))
                    }
                    Button {
                        Haptics.tap()
                        health.retryHealth()
                    } label: {
                        Label("جرب مرة ثانية", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(SoftButtonStyle(color: Palette.cyan))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(tint: s.color)
    }

    private var healthStatus: (icon: String, color: Color, title: String, detail: String) {
        switch health.access {
        case .ok:
            return ("heart.text.square.fill", Palette.green, "مربوط بالصحة ✓",
                    "يقرأ كل سجلك من الجوال والساعة.")
        case .checking:
            return ("hourglass", Palette.text2, "يتحقق من الصحة…", "لحظات.")
        case .noHistory:
            return ("exclamationmark.triangle.fill", Palette.orange, "الصحة مو مربوطة",
                    "يقرأ آخر ٧ أيام بس من عداد الجوال، فمستواك ودروعك القديمة ما تنحسب.\nالحل: افتح تطبيق الصحة ← صورتك فوق ← التطبيقات ← دربك ← شغل «الكل».")
        case .blocked:
            return ("xmark.shield.fill", Palette.pink, "الصحة مقفلة على التطبيق",
                    "البرنامج اللي ثبت فيه دربك شال صلاحية الصحة، فيقرأ آخر ٧ أيام بس.\nالحل: ثبته ببرنامج أو شهادة تدعم الصحة (HealthKit).")
        case .unavailable:
            return ("iphone.slash", Palette.text2, "الجهاز ما يدعم الصحة",
                    "يقرأ من عداد الجوال بس.")
        }
    }

    private var about: some View {
        VStack(spacing: 8) {
            Image(systemName: "hexagon.fill")
                .font(.system(size: 30))
                .foregroundStyle(LinearGradient(colors: [Palette.cyan, Palette.violet, Palette.pink],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: Palette.violet.opacity(0.7), radius: 10)
            Text("دربك")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("عداد خطوات: مستويات وتحديات وتنافس مع شلتك")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Palette.text2)
                .multilineTextAlignment(.center)
            Text("الإصدار \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.1")")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Palette.text3)
            Text("المطور: 0xF8D")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [Palette.cyan, Palette.violet], startPoint: .leading, endPoint: .trailing))
            SaudiMadeBadge()
                .padding(.vertical, 6)
            Text("© 2026 0xF8D — جميع الحقوق محفوظة")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Palette.text3)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassCard()
    }
}
