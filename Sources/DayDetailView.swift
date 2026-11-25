// دربك — © 0xF8D

import SwiftUI

struct DayDetailView: View {
    let day: DayStat
    @EnvironmentObject var health: HealthStore
    @EnvironmentObject var settings: AppSettings
    @State var extras: DayExtras?

    var body: some View {
        let goal = settings.goal
        let tier = BadgeTier.highest(for: day.steps)
        let p = min(Double(day.steps) / Double(max(goal, 1)), 1)

        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 16) {
                    Text(Fmt.longDate(day.date))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.text2)
                        .padding(.top, 24)

                    if let tier {
                        CrystalBadge(tier: tier, size: 110)
                    } else {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundStyle(Palette.text3)
                            .frame(height: 110)
                    }

                    VStack(spacing: 2) {
                        Text(Fmt.num(day.steps))
                            .font(.system(size: 44, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text("خطوة")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(Palette.text2)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.08))
                                Capsule()
                                    .fill(LinearGradient(colors: tier?.colors ?? [Palette.cyan, Palette.blue],
                                                         startPoint: .leading, endPoint: .trailing))
                                    .frame(width: g.size.width * p)
                            }
                        }
                        .frame(height: 10)
                        Text(day.steps >= goal ? "وصلت هدفك ✓" : "ناقصك \(Fmt.num(goal - day.steps)) خطوة على الهدف")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(day.steps >= goal ? Palette.green : Palette.text2)
                        Text("+\(Fmt.num(Progression.dayXP(day.steps))) XP بهذا اليوم")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.gold)
                    }
                    .padding(16)
                    .glassCard()

                    HStack(spacing: 12) {
                        StatBox(icon: "location.north.line.fill",
                                value: extras.map { Fmt.dec($0.distanceKm) } ?? "…",
                                unit: "كم", color: Palette.cyan)
                        StatBox(icon: "flame.fill",
                                value: extras.map { Fmt.num($0.kcal) } ?? "…",
                                unit: "سعرة حرارية", color: Palette.orange)
                        StatBox(icon: "figure.stairs",
                                value: extras.map { Fmt.num($0.floors) } ?? "…",
                                unit: "طابق", color: Palette.violet)
                    }

                    HStack(spacing: 10) {
                        ForEach(BadgeTier.all) { t in
                            CrystalBadge(tier: t, size: 52, earned: day.steps >= t.steps, animated: false)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 14)
                    .glassCard()
                }
                .padding(.horizontal, 18)
                .screenWidth()
                .padding(.bottom, 30)
            }
        }
        .task {
            if day.date == health.today {
                extras = DayExtras(distanceKm: health.todayDistanceKm, kcal: health.todayKcal, floors: health.todayFloors)
            } else {
                extras = await health.dayExtras(for: day.date, steps: day.steps)
            }
        }
    }
}
