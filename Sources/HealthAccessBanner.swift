// دربك — © 0xF8D
//
// لو التطبيق ما يقدر يقرأ سجل الصحة، نوضح للشخص السبب وكيف يحله.
// (بدون إذن الصحة نعتمد على عداد الجوال، وهو يحفظ آخر ٧ أيام بس، فالدروع القديمة ما تطلع)

import SwiftUI

struct HealthAccessBanner: View {
    @EnvironmentObject var health: HealthStore
    @Environment(\.openURL) var openURL

    var body: some View {
        switch health.access {
        case .noHistory:
            card(icon: "heart.text.square.fill",
                 title: "سجلك القديم مو طالع؟",
                 text: "دربك ما عنده إذن يقرأ من «الصحة»، فشايف آخر ٧ أيام بس من عداد الجوال.\nعشان تطلع كل أيامك ودروعك القديمة:\nافتح تطبيق الصحة ← صورتك فوق ← التطبيقات ← دربك ← شغّل «الكل».",
                 showOpenHealth: true)
        case .blocked:
            card(icon: "exclamationmark.shield.fill",
                 title: "الصحة مقفلة على التطبيق",
                 text: "البرنامج اللي ثبّت فيه دربك شال صلاحية «الصحة» من التطبيق، فما نقدر نقرأ سجلك القديم (شايفين آخر ٧ أيام بس).\nجرّب تثبته ببرنامج توقيع أو شهادة ثانية تدعم الصحة (HealthKit).",
                 showOpenHealth: false)
        default:
            EmptyView()
        }
    }

    private func card(icon: String, title: String, text: String, showOpenHealth: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Palette.pink)
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Text(text)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                if showOpenHealth {
                    Button {
                        if let url = URL(string: "x-apple-health://") { openURL(url) }
                    } label: {
                        Label("افتح الصحة", systemImage: "heart.fill")
                    }
                    .buttonStyle(SoftButtonStyle(color: Palette.pink))
                }
                Button {
                    Haptics.tap()
                    health.retryHealth()
                } label: {
                    Label("جرّب مرة ثانية", systemImage: "arrow.clockwise")
                }
                .buttonStyle(SoftButtonStyle(color: Palette.cyan))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(tint: Palette.pink)
    }
}
