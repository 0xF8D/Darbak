// دربك — © 0xF8D

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var health: HealthStore
    @EnvironmentObject var settings: AppSettings
    var openProgress: () -> Void = {}

    @State var selectedDay: DayStat?
    @State var showSettings = false
    @State var showShare = false

    var body: some View {
        let goal = settings.goal
        let steps = health.todaySteps

        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 20) {
                    header

                    HealthAccessBanner()

                    StepRing(steps: steps, goal: goal)
                        .frame(maxWidth: 290)
                        .padding(.top, 30)

                    nextTierLine(steps: steps, goal: goal)

                    HStack(spacing: 12) {
                        StatBox(icon: "location.north.line.fill", value: Fmt.dec(health.todayDistanceKm),
                                unit: "كم", color: Palette.cyan)
                        StatBox(icon: "flame.fill", value: Fmt.num(health.todayKcal),
                                unit: "سعرة حرارية", color: Palette.orange)
                        StatBox(icon: "figure.stairs", value: Fmt.num(health.todayFloors),
                                unit: "طابق", color: Palette.violet)
                    }

                    weekCard(goal: goal)

                    challengesTeaser

                    Button {
                        showShare = true
                    } label: {
                        Label("شارك إنجازك", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(NeonButtonStyle(colors: [Palette.violet, Palette.pink]))

                    if let msg = health.errorMessage, !health.hasAnyData {
                        hint(msg)
                    } else if !health.isLoading && !health.hasAnyData {
                        hint("ما جتني خطوات. افتح تطبيق الصحة ← صورتك فوق ← التطبيقات ← دربك ← شغل «الكل».")
                    }

                    Text("© 0xF8D")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.text3)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 18)
                .screenWidth()
                .padding(.bottom, 30)
            }
        }
        .sheet(item: $selectedDay) { day in
            DayDetailView(day: day)
                .appEnvironment()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .appEnvironment()
        }
        .sheet(isPresented: $showShare) {
            ShareSheetView(card: ShareCardView(steps: steps,
                                               goal: goal,
                                               level: health.progress.level.level,
                                               distanceKm: health.todayDistanceKm,
                                               date: Date()))
                .appEnvironment()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("دربك")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.white, Color(hex: 0xA9C4FF)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: Palette.blue.opacity(0.6), radius: 10)
                Text(Fmt.longDate(health.now))
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Palette.text2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer()
            levelChip
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.07), in: Circle())
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
            }
        }
        .padding(.top, 8)
    }

    private var levelChip: some View {
        let level = health.progress.level
        let rank = level.rank
        return Button {
            Haptics.tap()
            openProgress()
        } label: {
            VStack(spacing: 3) {
                HStack(spacing: 4) {
                    Text("⭐")
                        .font(.system(size: 15))
                    Text(Fmt.num(level.level))
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.12))
                        Capsule().fill(rank.gradient)
                            .frame(width: max(g.size.width * level.fraction, 3))
                    }
                }
                .frame(width: 46, height: 4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(rank.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(rank.primary.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: rank.primary.opacity(0.35), radius: 8)
        }
        .buttonStyle(.plain)
    }

    private var challengesTeaser: some View {
        let week = health.progress.week
        let done = week.filter(\.done).count
        return Button {
            Haptics.tap()
            openProgress()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("تحديات الأسبوع")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("\(Fmt.num(done))/\(Fmt.num(week.count))")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.cyan)
                    Spacer()
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.text3)
                }
                ForEach(week) { c in
                    ChallengeRow(challenge: c, tint: Palette.cyan, compact: true)
                }
            }
            .padding(16)
            .glassCard(tint: Palette.cyan)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pieces

    @ViewBuilder
    private func nextTierLine(steps: Int, goal: Int) -> some View {
        if let next = BadgeTier.next(after: steps) {
            HStack(spacing: 6) {
                Circle().fill(next.gradient).frame(width: 8, height: 8)
                Text("هدفك الجاي \(Fmt.num(next.steps)) - باقي \(Fmt.num(next.steps - steps)) خطوة")
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(next.primary)
        } else {
            Text("فناااان، خلصت كل أهدافك 👑")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.gold)
        }
    }

    private func weekCard(goal: Int) -> some View {
        let days = health.lastDays(6)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("آخر ٦ أيام")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Text("اضغط على اليوم تشوف تفاصيله")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Palette.text3)
            }
            HStack(spacing: 0) {
                ForEach(days) { day in
                    Button {
                        Haptics.tap()
                        selectedDay = day
                    } label: {
                        WeekDayCircle(day: day, goal: goal, isToday: false)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .glassCard()
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.75))
            .multilineTextAlignment(.leading)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(radius: 18, tint: Palette.orange)
    }
}

// MARK: - دائرة اليوم في الأسبوع

struct WeekDayCircle: View {
    let day: DayStat
    let goal: Int
    let isToday: Bool

    var body: some View {
        let tier = BadgeTier.highest(for: day.steps)
        let ringColors = tier?.colors ?? [Palette.blue.opacity(0.8), Palette.blue.opacity(0.5)]
        let p = min(Double(day.steps) / Double(max(goal, 1)), 1)

        VStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(tier.map { $0.primary.opacity(0.2) } ?? Color.white.opacity(0.04))
                if day.isFuture {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                } else {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 3)
                        .padding(1.5)
                    Circle()
                        .trim(from: 0, to: max(p, 0.001))
                        .stroke(LinearGradient(colors: ringColors, startPoint: .top, endPoint: .bottom),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(1.5)
                }
                VStack(spacing: -1) {
                    Text(day.isFuture ? "–" : Fmt.thousands(day.steps))
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(day.isFuture ? Palette.text3 : .white)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    if !day.isFuture && day.steps >= 1000 {
                        Text("ألف")
                            .font(.system(size: 7.5, weight: .medium, design: .rounded))
                            .foregroundStyle(Palette.text2)
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(width: 42, height: 42)
            .shadow(color: tier?.primary.opacity(0.55) ?? .clear, radius: 6)
            .overlay {
                if isToday {
                    Circle()
                        .stroke(Color.white.opacity(0.85), lineWidth: 1)
                        .padding(-4)
                }
            }

            Text(Fmt.weekday(day.date))
                .font(.system(size: 10, weight: isToday ? .bold : .medium, design: .rounded))
                .foregroundStyle(isToday ? Color.white : Palette.text2)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}
