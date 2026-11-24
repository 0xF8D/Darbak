// دربك — © 0xF8D

import SwiftUI
import Charts

struct StatsView: View {
    @EnvironmentObject var health: HealthStore
    @EnvironmentObject var settings: AppSettings
    @State var weekOffset = 0

    var body: some View {
        let goal = settings.goal
        let week = health.week(offset: weekOffset)
        let prev = health.week(offset: weekOffset - 1)
        let past = week.filter { !$0.isFuture }
        let total = past.reduce(0) { $0 + $1.steps }
        let avg = total / max(past.count, 1)
        let best = past.max { $0.steps < $1.steps }
        let goalDays = past.filter { $0.steps >= goal }.count
        let prevAvg = prev.reduce(0) { $0 + $1.steps } / 7
        let maxSteps = week.map(\.steps).max() ?? 0

        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenTitle(title: "إحصائيات")

                    weekSwitcher(week)

                    Chart {
                        ForEach(week) { d in
                            BarMark(x: .value("اليوم", Fmt.weekday(d.date)),
                                    y: .value("الخطوات", d.steps))
                                .foregroundStyle(barGradient(d.steps))
                                .cornerRadius(7)
                        }
                        RuleMark(y: .value("الهدف", goal))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundStyle(Palette.gold.opacity(0.7))
                    }
                    .chartYScale(domain: 0...max(goal * 12 / 10, maxSteps + 1_000))
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisValueLabel().foregroundStyle(Color.white.opacity(0.7))
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                            AxisValueLabel().foregroundStyle(Color.white.opacity(0.5))
                        }
                    }
                    .frame(height: 230)
                    .padding(16)
                    .glassCard()

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                        stat("المجموع", Fmt.num(total), "خطوة", Palette.cyan)
                        stat("معدلك باليوم", Fmt.num(avg), changeText(avg, prevAvg), Palette.blue)
                        stat("أفضل يوم", Fmt.num(best?.steps ?? 0), best.map { Fmt.weekday($0.date) } ?? "-", Palette.violet)
                        stat("أيام قفلت الهدف", Fmt.num(goalDays), "من \(Fmt.num(past.count)) أيام", Palette.pink)
                        stat("الستريك 🔥", Fmt.num(health.streak), "يوم متتالي", Palette.orange)
                        stat("أطول ستريك", Fmt.num(health.longestStreak), "أعلى رقم وصلته", Palette.gold)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
        }
    }

    private func weekSwitcher(_ week: [DayStat]) -> some View {
        HStack {
            Button {
                weekOffset -= 1
            } label: {
                Image(systemName: "chevron.right")
            }
            Spacer()
            VStack(spacing: 2) {
                Text(weekOffset == 0 ? "هذا الأسبوع" : (weekOffset == -1 ? "الأسبوع الماضي" : "قبل \(Fmt.num(-weekOffset)) أسابيع"))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                if let first = week.first, let last = week.last {
                    Text("\(Fmt.dayMonth(first.date)) – \(Fmt.dayMonth(last.date))")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Palette.text2)
                }
            }
            Spacer()
            Button {
                weekOffset += 1
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(weekOffset >= 0)
            .opacity(weekOffset >= 0 ? 0.3 : 1)
        }
        .font(.system(size: 16, weight: .bold))
        .foregroundStyle(Palette.cyan)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassCard()
    }

    private func barGradient(_ steps: Int) -> LinearGradient {
        let colors = BadgeTier.highest(for: steps)?.colors ?? [Palette.blue.opacity(0.7), Palette.blue.opacity(0.35)]
        return LinearGradient(colors: Array(colors.reversed()), startPoint: .bottom, endPoint: .top)
    }

    private func changeText(_ avg: Int, _ prev: Int) -> String {
        guard prev > 0 else { return "خطوة / يوم" }
        let pct = Int((Double(avg - prev) / Double(prev) * 100).rounded())
        let arrow = pct >= 0 ? "▲" : "▼"
        return "\(arrow) \(Fmt.num(abs(pct)))٪ عن الأسبوع اللي قبله"
    }

    private func stat(_ title: String, _ value: String, _ sub: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Palette.text2)
            Text(value)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.6), radius: 8)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(sub)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Palette.text3)
                .lineLimit(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 20, tint: color)
    }
}
