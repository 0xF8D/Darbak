// دربك — © 0xF8D
//
// الترتيب:
//  [ 7K ] [ 8K ]
//  [ 9K ] [ 10K ]
//  [ 👑 أفضل يوم لك — بعرض الصف ]

import SwiftUI

struct BadgesView: View {
    @EnvironmentObject var health: HealthStore
    @EnvironmentObject var settings: AppSettings
    @State var selected: BadgeTier?
    @State var bestSelected: DayStat?

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
    private let cardHeight: CGFloat = 210

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScreenTitle(title: "الدروع", subtitle: "كل يوم توصل فيه الرقم ينحسب لك درع")

                    HealthAccessBanner()

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(BadgeTier.all) { tier in
                            badgeCard(tier)
                        }
                    }

                    bestDayCard

                    streakCard
                }
                .padding(.horizontal, 18)
                .screenWidth()
                .padding(.bottom, 30)
            }
        }
        .sheet(item: $selected) { tier in
            BadgeDetailView(tier: tier)
                .appEnvironment()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $bestSelected) { day in
            DayDetailView(day: day)
                .appEnvironment()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func badgeCard(_ tier: BadgeTier) -> some View {
        let count = health.count(for: tier)
        return Button {
            Haptics.tap()
            selected = tier
        } label: {
            VStack(spacing: 12) {
                CrystalBadge(tier: tier, size: 104, earned: count > 0, count: count)
                Text("\(Fmt.num(tier.steps)) خطوة")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(count > 0 ? "جبته \(Fmt.num(count)) مرة" : "لسه ما جبته")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(count > 0 ? tier.primary : Palette.text3)
            }
            .frame(maxWidth: .infinity)
            .frame(height: cardHeight)
            .glassCard(tint: tier.primary)
        }
        .buttonStyle(.plain)
    }

    private var bestDayCard: some View {
        let best = health.bestDay
        return Button {
            if let best {
                Haptics.tap()
                bestSelected = best
            }
        } label: {
            HStack(spacing: 18) {
                CrystalBadge.best(size: 120, earned: best != nil)
                VStack(alignment: .leading, spacing: 6) {
                    Text("أفضل يوم لك")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.text2)
                    Text(best.map { Fmt.num($0.steps) } ?? "—")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [Palette.goldLight, Palette.gold],
                                                        startPoint: .top, endPoint: .bottom))
                        .shadow(color: Palette.gold.opacity(0.6), radius: 10)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(best.map { "خطوة · \(Fmt.longDate($0.date))" } ?? "امشِ وأول رقم قياسي لك يطلع هنا")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Palette.text2)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: cardHeight)
            .glassCard(tint: Palette.gold)
        }
        .buttonStyle(.plain)
    }

    private var streakCard: some View {
        HStack(spacing: 0) {
            streakItem("🔥", Fmt.num(health.streak), "الستريك الحالي", Palette.orange)
            Divider().frame(height: 44).overlay(Color.white.opacity(0.1))
            streakItem("🏆", Fmt.num(health.longestStreak), "أطول ستريك", Palette.gold)
            Divider().frame(height: 44).overlay(Color.white.opacity(0.1))
            streakItem("🎯", Fmt.num(settings.goal), "هدفك", Palette.cyan)
        }
        .padding(.vertical, 14)
        .glassCard()
    }

    private func streakItem(_ icon: String, _ value: String, _ title: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(icon) \(value)")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Palette.text2)
        }
        .frame(maxWidth: .infinity)
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
                    CrystalBadge(tier: tier, size: 170, earned: !days.isEmpty)
                        .padding(.top, 34)

                    Text(days.isEmpty ? "لسه ما جبته" : "جبته \(Fmt.num(days.count)) مرة")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("وين وصلت اليوم")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(Palette.text2)
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.1))
                                Capsule().fill(tier.gradient)
                                    .frame(width: g.size.width * progress)
                                    .shadow(color: tier.primary.opacity(0.7), radius: 8)
                            }
                        }
                        .frame(height: 10)
                        Text(remaining == 0 ? "جبته اليوم ✓" : "باقي \(Fmt.num(remaining)) خطوة")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(tier.primary)
                    }
                    .padding(16)
                    .glassCard(tint: tier.primary)

                    VStack(alignment: .leading, spacing: 0) {
                        Text("الأيام اللي جبته فيها")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.bottom, 12)

                        if days.isEmpty {
                            Text("لما توصل \(Fmt.num(tier.steps)) خطوة في يوم، يتسجل هنا.")
                                .font(.system(size: 14, design: .rounded))
                                .foregroundStyle(Palette.text2)
                        } else {
                            ForEach(days.prefix(120)) { d in
                                HStack {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundStyle(tier.gradient)
                                    Text(Fmt.longDate(d.date))
                                        .font(.system(size: 15, design: .rounded))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text(Fmt.num(d.steps))
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Palette.text2)
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
                .screenWidth()
                .padding(.bottom, 30)
            }
        }
    }
}
