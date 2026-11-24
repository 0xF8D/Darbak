// دربك — © 0xF8D
//
// وضع المشي على شاشة القفل والجزيرة الديناميكية

import WidgetKit
import SwiftUI
import ActivityKit

struct WalkLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WalkActivityAttributes.self) { context in
            WalkLockView(state: context.state)
                .activityBackgroundTint(Palette.bgTop.opacity(0.92))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let st = context.state
            let p = min(Double(st.steps) / Double(max(st.goal, 1)), 1)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.walk")
                            .foregroundStyle(Palette.cyan)
                        Text(Fmt.num(st.steps))
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(Fmt.dec(st.distanceKm)) كم")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.cyan)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        ProgressView(value: p)
                            .tint(Palette.cyan)
                        Text(st.steps >= st.goal ? "حققت هدفك 🔥" : "باقي \(Fmt.num(st.goal - st.steps)) خطوة على هدفك")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.text2)
                    }
                }
            } compactLeading: {
                Image(systemName: "figure.walk")
                    .foregroundStyle(Palette.cyan)
            } compactTrailing: {
                Text(Fmt.thousands(st.steps))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            } minimal: {
                Image(systemName: "figure.walk")
                    .foregroundStyle(Palette.cyan)
            }
        }
    }
}

struct WalkLockView: View {
    let state: WalkActivityAttributes.ContentState

    private var progress: Double { min(Double(state.steps) / Double(max(state.goal, 1)), 1) }
    private var remaining: Int { max(state.goal - state.steps, 0) }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: max(progress, 0.002))
                    .stroke(AngularGradient(colors: Palette.ring, center: .center, startAngle: .degrees(0), endAngle: .degrees(360)),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "figure.walk")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Palette.cyan)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 2) {
                Text("وضع المشي · دربك")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.text2)
                Text(Fmt.num(state.steps))
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text(remaining > 0 ? "باقي \(Fmt.num(remaining)) على هدفك" : "حققت هدفك 🔥")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.cyan)
            }

            Spacer(minLength: 0)

            VStack(spacing: 0) {
                Text(Fmt.dec(state.distanceKm))
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("كم")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Palette.text2)
            }
        }
        .padding(16)
        .environment(\.layoutDirection, .rightToLeft)
    }
}
