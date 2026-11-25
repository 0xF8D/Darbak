// دربك — © 0xF8D
//
// ويدجت الشاشة الرئيسية وشاشة القفل. يقرأ آخر بيانات حفظها التطبيق في App Group.
// iOS هو اللي يقرر متى يحدثه (تقريبا كل ١٥-٣٠ دقيقة)، والتطبيق يطلب تحديث كل ما تغيرت الخطوات.

import WidgetKit
import SwiftUI

@main
struct DarbakWidgets: WidgetBundle {
    var body: some Widget {
        StepsWidget()
        WalkLiveActivity()
    }
}

struct StepsEntry: TimelineEntry {
    let date: Date
    let snap: StepsSnapshot
}

struct StepsProvider: TimelineProvider {
    func placeholder(in context: Context) -> StepsEntry {
        StepsEntry(date: Date(), snap: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (StepsEntry) -> Void) {
        if context.isPreview {
            completion(StepsEntry(date: Date(), snap: .placeholder))
        } else {
            completion(StepsEntry(date: Date(), snap: current(at: Date())))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StepsEntry>) -> Void) {
        let now = Date()
        let snap = current(at: now)
        var entries = [StepsEntry(date: now, snap: snap)]
        let cal = AppCalendar.local
        if let midnight = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) {
            entries.append(StepsEntry(date: midnight, snap: snap.resetting(for: midnight)))
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(15 * 60))))
    }

    private func current(at date: Date) -> StepsSnapshot {
        let today = AppCalendar.local.startOfDay(for: date)
        guard let s = StepsSnapshot.load() else {
            return StepsSnapshot(day: today, steps: 0, goal: 8_000, distanceKm: 0, kcal: 0,
                                 floors: 0, level: 1, updated: date)
        }
        return s.day == today ? s : s.resetting(for: date)
    }
}

struct StepsWidget: Widget {
    let kind = "DarbakSteps"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StepsProvider()) { entry in
            StepsWidgetView(entry: entry)
        }
        .configurationDisplayName("دربك")
        .description("خطواتك اليوم وهدفك ومستواك")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct StepsWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: StepsEntry

    private var s: StepsSnapshot { entry.snap }
    private var tier: BadgeTier? { BadgeTier.highest(for: s.steps) }

    private var isAccessory: Bool {
        family == .accessoryCircular || family == .accessoryRectangular || family == .accessoryInline
    }

    var body: some View {
        if #available(iOS 17.0, *) {
            content
                .environment(\.layoutDirection, .rightToLeft)
                .containerBackground(for: .widget) { background }
        } else if isAccessory {
            // iOS 16: ويدجت شاشة القفل بدون خلفية
            content
                .environment(\.layoutDirection, .rightToLeft)
        } else {
            // iOS 16: نرسم الخلفية بأنفسنا ونضيف هوامش
            ZStack {
                background
                content
                    .padding(14)
            }
            .environment(\.layoutDirection, .rightToLeft)
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(colors: [Palette.bgTop, Palette.bgBottom], startPoint: .top, endPoint: .bottom)
            Circle()
                .fill(Palette.violet.opacity(0.3))
                .frame(width: 160, height: 160)
                .blur(radius: 50)
                .offset(x: 60, y: -60)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: s.progress) {
                Image(systemName: "figure.walk")
            } currentValueLabel: {
                Text(Fmt.thousands(s.steps))
            }
            .gaugeStyle(.accessoryCircular)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "figure.walk")
                    Text("دربك")
                    Spacer()
                    Text("⭐\(Fmt.num(s.level))")
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                Text(Fmt.num(s.steps))
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                ProgressView(value: s.progress)
            }
        case .accessoryInline:
            Text("👣 \(Fmt.num(s.steps)) / \(Fmt.num(s.goal))")
        case .systemMedium:
            medium
        default:
            small
        }
    }

    private var small: some View {
        VStack(spacing: 6) {
            WidgetRing(progress: s.progress, lineWidth: 9) {
                VStack(spacing: 0) {
                    Text(Fmt.num(s.steps))
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text("من \(Fmt.num(s.goal))")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.text2)
                }
                .padding(.horizontal, 12)
            }
            HStack(spacing: 6) {
                Text("⭐ \(Fmt.num(s.level))")
                    .foregroundStyle(Palette.gold)
                if let tier {
                    Text(tier.label)
                        .foregroundStyle(tier.primary)
                }
            }
            .font(.system(size: 12, weight: .bold, design: .rounded))
        }
    }

    private var medium: some View {
        HStack(spacing: 16) {
            WidgetRing(progress: s.progress, lineWidth: 11) {
                VStack(spacing: 0) {
                    Text(Fmt.num(s.steps))
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text("من \(Fmt.num(s.goal))")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.text2)
                }
                .padding(.horizontal, 14)
            }
            .frame(width: 120, height: 120)

            VStack(alignment: .leading, spacing: 7) {
                Text("دربك")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                row("location.north.line.fill", "\(Fmt.dec(s.distanceKm)) كم", Palette.cyan)
                row("flame.fill", "\(Fmt.num(s.kcal)) سعرة", Palette.orange)
                row("figure.stairs", "\(Fmt.num(s.floors)) طابق", Palette.violet)
                Text("⭐ مستوى \(Fmt.num(s.level))")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.gold)
            }
            Spacer(minLength: 0)
        }
    }

    private func row(_ icon: String, _ text: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 16)
            Text(text)
                .foregroundStyle(.white)
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded))
    }
}

struct WidgetRing<Center: View>: View {
    let progress: Double
    let lineWidth: CGFloat
    @ViewBuilder let center: () -> Center

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(progress, 0.002))
                .stroke(AngularGradient(colors: Palette.ring, center: .center,
                                        startAngle: .degrees(0), endAngle: .degrees(360 * max(progress, 0.05))),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: Palette.cyan.opacity(0.5), radius: 5)
                .environment(\.layoutDirection, .leftToRight)
            center()
        }
        .padding(lineWidth / 2)
    }
}
