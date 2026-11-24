// دربك — © 0xF8D

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var health: HealthStore
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var walk: WalkMode

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

                    walkButton

                    Button {
                        showShare = true
                    } label: {
                        Label("شارك إنجازك", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(NeonButtonStyle(colors: [Palette.violet, Palette.pink]))

                    if let msg = health.errorMessage, !health.hasAnyData {
                        hint(msg)
                    } else if !health.isLoading && !health.hasAnyData {
                        hint("ما وصلتني خطوات. روح الإعدادات > الصحة > الوصول للبيانات والأجهزة > دربك وفعّل كل شي.")
                    }

                    Text("© 0xF8D")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.text3)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 18)
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
                                               streak: health.streak,
                                               longest: health.longestStreak,
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
            }
            Spacer()
            streakChip
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

    private var streakChip: some View {
        let on = health.streak > 0
        return VStack(spacing: 1) {
            HStack(spacing: 4) {
                Text("🔥")
                    .font(.system(size: 18))
                    .saturation(on ? 1 : 0)
                Text(Fmt.num(health.streak))
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(on ? Palette.orange : Palette.text2)
                    .contentTransition(.numericText())
            }
            Text("أطول \(Fmt.num(health.longestStreak))")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.text2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Palette.orange.opacity(on ? 0.12 : 0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Palette.orange.opacity(on ? 0.45 : 0.1), lineWidth: 1)
        )
        .shadow(color: on ? Palette.orange.opacity(0.35) : .clear, radius: 8)
    }

    // MARK: - Pieces

    @ViewBuilder
    private func nextTierLine(steps: Int, goal: Int) -> some View {
        if let next = BadgeTier.next(after: steps) {
            HStack(spacing: 6) {
                Circle().fill(next.gradient).frame(width: 8, height: 8)
                Text("الدرع الجاي \(next.label) — باقي \(Fmt.num(next.steps - steps)) خطوة")
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(next.primary)
        } else {
            Text("جبت كل دروع اليوم 👑")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.gold)
        }
    }

    private func weekCard(goal: Int) -> some View {
        let week = health.week(offset: 0)
        let t = health.today
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("هذا الأسبوع")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Text("اضغط على أي يوم")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Palette.text3)
            }
            HStack(spacing: 0) {
                ForEach(week) { day in
                    Button {
                        if !day.isFuture {
                            Haptics.tap()
                            selectedDay = day
                        }
                    } label: {
                        WeekDayCircle(day: day, goal: goal, isToday: day.date == t)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .glassCard()
    }

    private var walkButton: some View {
        Button {
            Haptics.tap()
            walk.toggle()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(walk.isOn ? Palette.green.opacity(0.2) : Palette.cyan.opacity(0.12))
                    Image(systemName: walk.isOn ? "stop.fill" : "figure.walk.motion")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(walk.isOn ? Palette.green : Palette.cyan)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 3) {
                    Text(walk.isOn ? "وضع المشي شغّال" : "شغّل وضع المشي")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(walk.isOn ? "خطواتك تتحدث على شاشة القفل · اضغط للإيقاف"
                                   : "يعرض خطواتك مباشرة على شاشة القفل (يستهلك بطارية)")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Palette.text2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Circle()
                    .fill(walk.isOn ? Palette.green : Color.white.opacity(0.15))
                    .frame(width: 10, height: 10)
                    .shadow(color: walk.isOn ? Palette.green : .clear, radius: 6)
            }
            .padding(14)
            .glassCard(tint: walk.isOn ? Palette.green : Palette.cyan)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            if let msg = walk.message {
                Text(msg)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Palette.orange)
                    .offset(y: 22)
            }
        }
        .padding(.bottom, walk.message == nil ? 0 : 18)
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
            .overlay(alignment: .topTrailing) {
                if day.frozen {
                    Text("❄️")
                        .font(.system(size: 10))
                        .offset(x: 4, y: -4)
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
