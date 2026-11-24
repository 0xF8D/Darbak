// دربك — © 0xF8D
// ملف مشترك بين التطبيق والويدجت

import SwiftUI
import ActivityKit

// MARK: - الألوان

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

/// ثيم كحلي نيون
enum Palette {
    static let bgTop = Color(hex: 0x030820)
    static let bgBottom = Color(hex: 0x081335)
    static let card = Color(hex: 0x0E1C45)
    static let cardDeep = Color(hex: 0x09142F)

    static let cyan = Color(hex: 0x22E1FF)
    static let blue = Color(hex: 0x3D7BFF)
    static let violet = Color(hex: 0x9B5CFF)
    static let pink = Color(hex: 0xFF4FD8)
    static let orange = Color(hex: 0xFF8A3D)
    static let green = Color(hex: 0x3DFFB0)

    static let goldLight = Color(hex: 0xFFF1B0)
    static let gold = Color(hex: 0xFFD066)
    static let goldDeep = Color(hex: 0xD99117)

    static let text2 = Color.white.opacity(0.62)
    static let text3 = Color.white.opacity(0.4)

    static let ring: [Color] = [cyan, blue, violet, pink]
}

// MARK: - الوقت (حسب توقيت جوال الشخص، اليوم يبدأ ١٢ الليل)

enum AppCalendar {
    static let local: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .autoupdatingCurrent
        c.firstWeekday = 1
        c.locale = Locale(identifier: "ar_SA")
        return c
    }()

    static func startOfToday() -> Date { local.startOfDay(for: Date()) }
}

// MARK: - تنسيق الأرقام والتواريخ

enum Fmt {
    static let locale = Locale(identifier: "ar_SA")

    private static func numberFormatter(maxFraction: Int) -> NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = locale
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = maxFraction
        return f
    }

    private static let int0 = numberFormatter(maxFraction: 0)
    private static let dec1 = numberFormatter(maxFraction: 1)

    static func num(_ n: Int) -> String {
        int0.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    static func num(_ x: Double) -> String {
        int0.string(from: NSNumber(value: x.rounded())) ?? "\(Int(x.rounded()))"
    }

    static func dec(_ x: Double) -> String {
        dec1.string(from: NSNumber(value: x)) ?? String(format: "%.1f", x)
    }

    /// 7,960 → "٧٫٩" (بالآلاف، مقصوصة لتحت عشان ما توحي إنك وصلت 8)
    static func thousands(_ n: Int) -> String {
        if n < 1000 { return num(n) }
        return dec(Double(n / 100) / 10)
    }

    private static func make(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = AppCalendar.local
        f.timeZone = .autoupdatingCurrent
        f.locale = locale
        f.dateFormat = format
        return f
    }

    private static let longDay = make("EEEE، d MMMM yyyy")
    private static let shortDay = make("EEE")
    private static let dayMonthF = make("d MMMM")
    private static let timeF = make("h:mm a")

    static func longDate(_ d: Date) -> String { longDay.string(from: d) }
    static func weekday(_ d: Date) -> String { shortDay.string(from: d) }
    static func dayMonth(_ d: Date) -> String { dayMonthF.string(from: d) }
    static func time(_ d: Date) -> String { timeF.string(from: d) }
}

// MARK: - الدروع

struct BadgeTier: Identifiable {
    let steps: Int
    let colors: [Color]
    var id: Int { steps }
    var label: String { "\(steps / 1000)K" }
    var primary: Color { colors[0] }
    var secondary: Color { colors[1] }
    var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static let all: [BadgeTier] = [
        BadgeTier(steps: 7_000,  colors: [Color(hex: 0x22E1FF), Color(hex: 0x1E8BFF)]),
        BadgeTier(steps: 8_000,  colors: [Color(hex: 0x4D8BFF), Color(hex: 0x6A4DFF)]),
        BadgeTier(steps: 9_000,  colors: [Color(hex: 0xA66BFF), Color(hex: 0xD04DFF)]),
        BadgeTier(steps: 10_000, colors: [Color(hex: 0xFF4FD8), Color(hex: 0xFF7A45)])
    ]

    static func tier(_ steps: Int) -> BadgeTier? { all.first { $0.steps == steps } }
    static func highest(for steps: Int) -> BadgeTier? { all.last { steps >= $0.steps } }
    static func next(after steps: Int) -> BadgeTier? { all.first { $0.steps > steps } }
}

// MARK: - بيانات الويدجت (تنحفظ في App Group)

enum SharedStore {
    static let appGroup = "group.com.f8d.steps"
    static let snapshotKey = "stepsSnapshot"
    static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }
}

struct StepsSnapshot: Codable {
    var day: Date
    var steps: Int
    var goal: Int
    var distanceKm: Double
    var kcal: Int
    var floors: Int
    var streak: Int
    var updated: Date

    var progress: Double { min(Double(steps) / Double(max(goal, 1)), 1) }

    static let placeholder = StepsSnapshot(day: Date(), steps: 6_480, goal: 8_000, distanceKm: 4.8,
                                           kcal: 260, floors: 3, streak: 5, updated: Date())

    static func load() -> StepsSnapshot? {
        guard let data = SharedStore.defaults.data(forKey: SharedStore.snapshotKey) else { return nil }
        return try? JSONDecoder().decode(StepsSnapshot.self, from: data)
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            SharedStore.defaults.set(data, forKey: SharedStore.snapshotKey)
        }
    }

    /// نسخة فاضية ليوم جديد (نحتفظ بالهدف والستريك)
    func resetting(for day: Date) -> StepsSnapshot {
        StepsSnapshot(day: AppCalendar.local.startOfDay(for: day), steps: 0, goal: goal,
                      distanceKm: 0, kcal: 0, floors: 0, streak: streak, updated: day)
    }
}

// MARK: - وضع المشي (Live Activity)

struct WalkActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var steps: Int
        var goal: Int
        var distanceKm: Double
    }
    var startedAt: Date
}
