import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

/// كل الحسابات بتوقيت السعودية، واليوم الجديد يبدأ 12 منتصف الليل (الأسبوع يبدأ الأحد)
enum AppCalendar {
    static let tz = TimeZone(identifier: "Asia/Riyadh")!
    static let riyadh: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = tz
        c.firstWeekday = 1
        c.locale = Locale(identifier: "ar_SA")
        return c
    }()
}

enum Fmt {
    static let locale = Locale(identifier: "ar_SA")

    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = locale
        return f
    }()

    static func num(_ n: Int) -> String {
        numberFormatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private static func make(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = AppCalendar.riyadh
        f.timeZone = AppCalendar.tz
        f.locale = locale
        f.dateFormat = format
        return f
    }

    private static let longDay = make("EEEE، d MMMM yyyy")
    private static let shortDay = make("EEE")

    static func longDate(_ d: Date) -> String { longDay.string(from: d) }
    static func weekday(_ d: Date) -> String { shortDay.string(from: d) }
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x050B1A), Color(hex: 0x0B1530)],
                           startPoint: .top, endPoint: .bottom)
            Circle()
                .fill(Color(hex: 0x6366F1).opacity(0.25))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: 130, y: -300)
            Circle()
                .fill(Color(hex: 0x22D3EE).opacity(0.18))
                .frame(width: 300, height: 300)
                .blur(radius: 90)
                .offset(x: -140, y: 320)
        }
        .ignoresSafeArea()
    }
}

extension View {
    func glassCard(radius: CGFloat = 24) -> some View {
        self
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [Color.white.opacity(0.22), Color.white.opacity(0.04)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1)
            )
    }
}
