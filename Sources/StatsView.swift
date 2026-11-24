import SwiftUI
import Charts

struct StatsView: View {
    @EnvironmentObject var health: HealthStore

    var body: some View {
        let week = health.week(offset: 0)
        let prev = health.week(offset: -1)
        let past = week.filter { !$0.isFuture }
        let total = past.reduce(0) { $0 + $1.steps }
        let avg = total / max(past.count, 1)
        let best = past.max { $0.steps < $1.steps }
        let goalDays = past.filter { $0.steps >= BadgeTier.dailyGoal }.count
        let prevAvg = prev.reduce(0) { $0 + $1.steps } / 7
        let maxSteps = week.map(\.steps).max() ?? 0

        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("إحصائيات الأسبوع")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.top, 10)

                    Chart {
                        ForEach(week) { d in
                            BarMark(x: .value("اليوم", Fmt.weekday(d.date)),
                                    y: .value("الخطوات", d.steps))
                                .foregroundStyle(LinearGradient(colors: [Color(hex: 0x22D3EE), Color(hex: 0x8B5CF6)],
                                                                startPoint: .bottom, endPoint: .top))
                                .cornerRadius(6)
                        }
                        RuleMark(y: .value("الهدف", BadgeTier.dailyGoal))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                    .chartYScale(domain: 0...max(12_000, maxSteps + 1_000))
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
                        stat("المجموع", Fmt.num(total), "خطوة", Color(hex: 0x22D3EE))
                        stat("المتوسط اليومي", Fmt.num(avg), changeText(avg, prevAvg), Color(hex: 0x6366F1))
                        stat("أفضل يوم", Fmt.num(best?.steps ?? 0), best.map { Fmt.weekday($0.date) } ?? "-", Color(hex: 0xA855F7))
                        stat("أيام الهدف", Fmt.num(goalDays), "من \(Fmt.num(past.count)) أيام", Color(hex: 0xD946EF))
                    }

                    Text("الإحصائيات تتحدث تلقائيًا، واليوم الجديد يبدأ الساعة 12 منتصف الليل بتوقيت السعودية.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.45))
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
        }
    }

    private func changeText(_ avg: Int, _ prev: Int) -> String {
        guard prev > 0 else { return "خطوة / يوم" }
        let pct = Int((Double(avg - prev) / Double(prev) * 100).rounded())
        let arrow = pct >= 0 ? "▲" : "▼"
        return "\(arrow) \(Fmt.num(abs(pct)))٪ عن الأسبوع الماضي"
    }

    private func stat(_ title: String, _ value: String, _ sub: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.6))
            Text(value)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.6), radius: 8)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(sub)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.5))
                .lineLimit(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 20)
    }
}
