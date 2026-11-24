import SwiftUI

struct BadgesView: View {
    @EnvironmentObject var health: HealthStore
    @State private var selected: BadgeTier?

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("الدروع")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.top, 10)

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(BadgeTier.all) { tier in
                            let count = health.count(for: tier)
                            Button { selected = tier } label: {
                                VStack(spacing: 14) {
                                    NeonBadge(tier: tier, size: 112, earned: count > 0, count: count)
                                        .padding(.top, 8)
                                    Text("\(Fmt.num(tier.steps)) خطوة")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text(count > 0 ? "حققته \(Fmt.num(count)) مرة" : "ما حققته بعد")
                                        .font(.system(size: 13, design: .rounded))
                                        .foregroundStyle(count > 0 ? tier.primary : Color.white.opacity(0.45))
                                }
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity)
                                .glassCard()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
        }
        .sheet(item: $selected) { tier in
            BadgeDetailView(tier: tier)
                .environmentObject(health)
                .environment(\.layoutDirection, .rightToLeft)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

struct BadgeDetailView: View {
    let tier: BadgeTier
    @EnvironmentObject var health: HealthStore

    var body: some View {
        let days = health.days(for: tier)
        let remaining = max(tier.steps - health.todaySteps, 0)
        let progress = min(Double(health.todaySteps) / Double(tier.steps), 1)

        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 18) {
                    NeonBadge(tier: tier, size: 170, earned: !days.isEmpty)
                        .padding(.top, 30)

                    Text(days.isEmpty ? "ما حققته بعد" : "حققته \(Fmt.num(days.count)) مرة")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("تقدم اليوم")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.6))
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.1))
                                Capsule().fill(tier.gradient)
                                    .frame(width: g.size.width * progress)
                                    .shadow(color: tier.primary.opacity(0.7), radius: 8)
                            }
                        }
                        .frame(height: 10)
                        Text(remaining == 0 ? "حققته اليوم ✓" : "باقي \(Fmt.num(remaining)) خطوة")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(tier.primary)
                    }
                    .padding(16)
                    .glassCard()

                    VStack(alignment: .leading, spacing: 0) {
                        Text("سجل الإنجاز")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.bottom, 12)

                        if days.isEmpty {
                            Text("لما توصل \(Fmt.num(tier.steps)) خطوة في يوم، يتسجل هنا.")
                                .font(.system(size: 14, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.55))
                        } else {
                            ForEach(days) { d in
                                HStack {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundStyle(tier.gradient)
                                    Text(Fmt.longDate(d.date))
                                        .font(.system(size: 15, design: .rounded))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text(Fmt.num(d.steps))
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Color.white.opacity(0.6))
                                }
                                .padding(.vertical, 10)
                                Divider().overlay(Color.white.opacity(0.08))
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
        }
        .preferredColorScheme(.dark)
    }
}
