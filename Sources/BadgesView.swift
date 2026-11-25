// دربك — © 0xF8D
//
// صفحة «التقدم»:
//  [ مستواك + XP ]
//  [ تحديات الأسبوع ] [ تحديات الشهر ]
//  الدروع:
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
                    ScreenTitle(title: "التقدم", subtitle: "مستواك وتحدياتك ودروعك")

                    HealthAccessBanner()

                    LevelCard(level: health.progress.level, todayXP: health.progress.todayXP)

                    ChallengesCard(title: "تحديات الأسبوع", challenges: health.progress.week,
                                   ends: health.progress.weekEnd, tint: Palette.cyan)

                    ChallengesCard(title: "تحديات الشهر", challenges: health.progress.month,
                                   ends: health.progress.monthEnd, tint: Palette.violet)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("الدروع")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text("كل يوم توصل فيه الرقم ينحسب لك درع (+٢٥ XP)")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(Palette.text2)
                    }
                    .padding(.top, 8)

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(BadgeTier.all) { tier in
                            badgeCard(tier)
                        }
                    }

                    bestDayCard

                    xpRules
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

    private var xpRules: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("كيف تجمع XP؟", systemImage: "sparkles")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            rule("👟", "كل ١٠٠ خطوة", "+١ XP")
            rule("💎", "كل درع تجيبه باليوم", "+٢٥ XP")
            rule("🏁", "تحدي أسبوعي", "+١٥٠ XP")
            rule("🏆", "تحدي شهري", "+٤٠٠ XP")
            Text("كل شي يتحسب من سجل خطواتك، فمستواك يشمل أيامك القديمة بعد.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Palette.text3)
                .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 18)
    }

    private func rule(_ icon: String, _ title: String, _ xp: String) -> some View {
        HStack {
            Text("\(icon)  \(title)")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Palette.text2)
            Spacer()
            Text(xp)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.gold)
        }
    }
}

// MARK: - بطاقة المستوى

struct LevelCard: View {
    let level: LevelInfo
    let todayXP: Int

    var body: some View {
        let rank = level.rank
        VStack(spacing: 14) {
            HStack(spacing: 16) {
                CrystalBadge(colors: rank.colors, label: Fmt.num(level.level), size: 92)
                VStack(alignment: .leading, spacing: 4) {
                    Text(rank.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(rank.primary)
                    Text("مستوى \(Fmt.num(level.level))")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: rank.primary.opacity(0.6), radius: 10)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("\(Fmt.num(level.xp)) XP")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.text2)
                }
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 7) {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.1))
                        Capsule()
                            .fill(rank.gradient)
                            .frame(width: max(g.size.width * level.fraction, 6))
                            .shadow(color: rank.primary.opacity(0.7), radius: 8)
                    }
                }
                .frame(height: 10)
                HStack {
                    Text("باقي \(Fmt.num(level.remaining)) XP للمستوى \(Fmt.num(level.level + 1))")
                    Spacer()
                    Text("اليوم +\(Fmt.num(todayXP))")
                        .foregroundStyle(Palette.green)
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.text2)
            }
        }
        .padding(16)
        .glassCard(tint: rank.primary)
    }
}

// MARK: - التحديات

struct ChallengesCard: View {
    let title: String
    let challenges: [Challenge]
    let ends: Date
    let tint: Color

    private var daysLeft: Int {
        let cal = AppCalendar.local
        return max(cal.dateComponents([.day], from: AppCalendar.startOfToday(), to: ends).day ?? 0, 0)
    }

    private var daysLeftText: String {
        switch daysLeft {
        case ...1: return "آخر يوم!"
        case 2: return "باقي يومين"
        case 3...10: return "باقي \(Fmt.num(daysLeft)) أيام"
        default: return "باقي \(Fmt.num(daysLeft)) يوم"
        }
    }

    var body: some View {
        let doneCount = challenges.filter(\.done).count
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(Fmt.num(doneCount))/\(Fmt.num(challenges.count))")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                Spacer()
                Text(daysLeftText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(daysLeft <= 1 ? Palette.orange : Palette.text3)
            }
            ForEach(challenges) { c in
                ChallengeRow(challenge: c, tint: tint)
            }
        }
        .padding(16)
        .glassCard(tint: tint)
    }
}

struct ChallengeRow: View {
    let challenge: Challenge
    let tint: Color
    var compact = false

    var body: some View {
        let c = challenge
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(c.done ? Palette.green.opacity(0.2) : tint.opacity(0.12))
                Image(systemName: c.done ? "checkmark" : c.icon)
                    .font(.system(size: compact ? 13 : 16, weight: .bold))
                    .foregroundStyle(c.done ? Palette.green : tint)
            }
            .frame(width: compact ? 32 : 40, height: compact ? 32 : 40)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(c.title)
                        .font(.system(size: compact ? 13 : 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer(minLength: 4)
                    Text("+\(Fmt.num(c.xp)) XP")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(c.done ? Palette.green : Palette.gold)
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(c.done ? AnyShapeStyle(Palette.green)
                                         : AnyShapeStyle(LinearGradient(colors: [tint, tint.opacity(0.6)],
                                                                         startPoint: .leading, endPoint: .trailing)))
                            .frame(width: max(g.size.width * c.fraction, 4))
                    }
                }
                .frame(height: 6)
                if !compact {
                    HStack {
                        Text(c.detail)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 4)
                        Text(c.done ? "خلّصته ✓" : c.progressText)
                            .foregroundStyle(c.done ? Palette.green : Palette.text2)
                    }
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Palette.text3)
                }
            }
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
