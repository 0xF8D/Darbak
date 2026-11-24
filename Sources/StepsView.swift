import SwiftUI

struct StepsView: View {
    @EnvironmentObject var health: HealthStore

    private var earnedToday: [BadgeTier] {
        BadgeTier.all.filter { health.todaySteps >= $0.steps }
    }
    private var nextTier: BadgeTier? {
        BadgeTier.all.first { $0.steps > health.todaySteps }
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 22) {
                    StepRing(steps: health.todaySteps, goal: BadgeTier.dailyGoal)
                        .frame(maxWidth: 330)
                        .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("دروع اليوم")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Spacer()
                        }

                        if earnedToday.isEmpty {
                            Text("حقق \(Fmt.num(BadgeTier.all[0].steps)) خطوة وياخذ أول درع 🔥")
                                .font(.system(size: 15, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.6))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                        } else {
                            HStack(spacing: 12) {
                                ForEach(earnedToday) { tier in
                                    NeonBadge(tier: tier, size: 62)
                                        .transition(.scale(scale: 0.2).combined(with: .opacity))
                                }
                                Spacer(minLength: 0)
                            }
                            .animation(.spring(response: 0.6, dampingFraction: 0.65), value: earnedToday.count)
                        }

                        if let next = nextTier {
                            Text("الدرع القادم \(next.label) — باقي \(Fmt.num(next.steps - health.todaySteps)) خطوة")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(next.primary)
                        } else {
                            Text("جبت كل دروع اليوم 👑")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(Color(hex: 0xD946EF))
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity)
                    .glassCard()

                    if let msg = health.errorMessage {
                        hint(msg)
                    } else if !health.isLoading && !health.hasAnyData {
                        hint("ما وصلتني خطوات. روح الإعدادات > الصحة > الوصول للبيانات والأجهزة > 0xF8D وفعّل الخطوات.")
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.7))
            .multilineTextAlignment(.leading)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(radius: 18)
    }
}
