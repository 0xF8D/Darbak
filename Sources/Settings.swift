// دربك — © 0xF8D

import SwiftUI

final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    static let goals = [7_000, 8_000, 9_000, 10_000]

    private let d = UserDefaults.standard

    @Published var goal: Int { didSet { d.set(goal, forKey: "goal") } }
    @Published var reminderEnabled: Bool { didSet { d.set(reminderEnabled, forKey: "reminderEnabled") } }
    @Published var reminderHour: Int { didSet { d.set(reminderHour, forKey: "reminderHour") } }
    @Published var reminderMinute: Int { didSet { d.set(reminderMinute, forKey: "reminderMinute") } }
    @Published var milestoneHaptics: Bool { didSet { d.set(milestoneHaptics, forKey: "milestoneHaptics") } }

    init() {
        let g = d.integer(forKey: "goal")
        goal = Self.goals.contains(g) ? g : 8_000
        reminderEnabled = d.object(forKey: "reminderEnabled") as? Bool ?? true
        reminderHour = d.object(forKey: "reminderHour") as? Int ?? 20
        reminderMinute = d.object(forKey: "reminderMinute") as? Int ?? 0
        milestoneHaptics = d.object(forKey: "milestoneHaptics") as? Bool ?? true
    }

    var reminderTime: Date {
        get {
            AppCalendar.local.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0,
                                    of: Date()) ?? Date()
        }
        set {
            let c = AppCalendar.local.dateComponents([.hour, .minute], from: newValue)
            reminderHour = c.hour ?? 20
            reminderMinute = c.minute ?? 0
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var walk: WalkMode
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        goalCard
                        toggles
                        reminderCard
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
            Text("أقل هدف ٧ آلاف، والتذكير يمشي على هدفك.")
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

    private var reminderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $settings.reminderEnabled) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("🔔 نذكرك بخطواتك")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .tint(Palette.cyan)
            if settings.reminderEnabled {
                HStack {
                    Text("الوقت")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(Palette.text2)
                    Spacer()
                    DatePicker("", selection: $settings.reminderTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
            }
        }
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
