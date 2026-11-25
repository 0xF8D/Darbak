// دربك — © 0xF8D
//
// المستويات (XP) والتحديات الأسبوعية والشهرية.
//
// كل شي يتحسب من سجل خطواتك نفسه، فما يضيع لو حذفت التطبيق ورجعت ثبته:
// - كل ١٠٠ خطوة = ١ XP (لين ٣٠ ألف خطوة باليوم)
// - كل درع تجيبه باليوم (٧ / ٨ / ٩ / ١٠ آلاف) = +٢٥ XP
// - كل تحدي أسبوعي تخلصه = +١٥٠ XP، وكل تحدي شهري = +٤٠٠ XP
//
// التحديات تتغير كل أسبوع وكل شهر، وأرقامها مبنية على معدلك بآخر ٤ أسابيع
// (فتكون صعبة شوي بس مو مستحيلة).

import SwiftUI

// MARK: - المستوى

/// الرتب: مبتدئ (١-٩)، متوسط (١٠-٢٩)، متقدم (٣٠-٤٩)، بطل (٥٠-٧٩)، أسطوري (٨٠-١٠٠)
struct Rank: Identifiable {
    let title: String
    let colors: [Color]
    let from: Int
    let to: Int

    var id: Int { from }
    var primary: Color { colors[0] }
    var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    func contains(_ level: Int) -> Bool { level >= from && level <= to }

    static let all: [Rank] = [
        Rank(title: "مبتدئ", colors: [Color(hex: 0x22E1FF), Color(hex: 0x1E8BFF)], from: 1, to: 9),
        Rank(title: "متوسط", colors: [Color(hex: 0x4D8BFF), Color(hex: 0x6A4DFF)], from: 10, to: 29),
        Rank(title: "متقدم", colors: [Color(hex: 0xA66BFF), Color(hex: 0xD04DFF)], from: 30, to: 49),
        Rank(title: "بطل", colors: [Color(hex: 0xFF4FD8), Color(hex: 0xFF7A45)], from: 50, to: 79),
        Rank(title: "أسطوري", colors: [Color(hex: 0xFFD066), Color(hex: 0xD99117)], from: 80, to: LevelInfo.maxLevel)
    ]

    static func of(level: Int) -> Rank {
        all.last { level >= $0.from } ?? all[0]
    }
}

struct LevelInfo: Equatable {
    static let maxLevel = 100

    let level: Int
    let xp: Int        // مجموع نقاطك
    let into: Int      // نقاطك داخل المستوى الحالي
    let need: Int      // كم يحتاج المستوى الحالي عشان تطلع للي بعده

    var isMax: Bool { level >= Self.maxLevel }
    var fraction: Double { isMax ? 1 : (need > 0 ? min(Double(into) / Double(need), 1) : 0) }
    var remaining: Int { isMax ? 0 : max(need - into, 0) }
    var rank: Rank { Rank.of(level: level) }

    /// كم XP تحتاج عشان تطلع من هذا المستوى
    static func cost(of level: Int) -> Int { 150 * level + 50 }

    init(xp: Int) {
        let total = max(xp, 0)
        var lvl = 1
        var left = total
        while lvl < Self.maxLevel && left >= Self.cost(of: lvl) {
            left -= Self.cost(of: lvl)
            lvl += 1
        }
        level = lvl
        self.xp = total
        into = left
        need = Self.cost(of: lvl)
    }
}

// MARK: - التحديات

enum ChallengePeriod: Equatable {
    case week, month
}

struct Challenge: Identifiable, Equatable {
    let id: String
    let period: ChallengePeriod
    let icon: String
    let title: String
    let detail: String
    let value: Int
    let target: Int
    let xp: Int
    /// نكتب التقدم بالخطوات ولا بالأيام
    let countsDays: Bool

    var done: Bool { value >= target }
    var fraction: Double { target > 0 ? min(Double(value) / Double(target), 1) : 0 }

    var progressText: String {
        if countsDays {
            return "\(Fmt.num(min(value, target))) / \(Fmt.num(target)) يوم"
        }
        return "\(Fmt.num(min(value, target))) / \(Fmt.num(target))"
    }
}

struct ProgressState: Equatable {
    var level = LevelInfo(xp: 0)
    var todayXP = 0
    var week: [Challenge] = []
    var month: [Challenge] = []
    var weekEnd = Date()
    var monthEnd = Date()

    static let empty = ProgressState()
}

enum Progression {
    static let dailyCapSteps = 30_000
    static let tierBonus = 25
    static let weeklyXP = 150
    static let monthlyXP = 400

    static func dayXP(_ steps: Int) -> Int {
        guard steps > 0 else { return 0 }
        let base = min(steps, dailyCapSteps) / 100
        let bonus = BadgeTier.all.filter { steps >= $0.steps }.count * tierBonus
        return base + bonus
    }

    /// ٨٠٠٠ → "٨ آلاف"، ١٥٠٠٠ → "١٥ ألف"
    static func k(_ n: Int) -> String {
        let t = n / 1000
        return "\(Fmt.num(t)) \(t >= 3 && t <= 10 ? "آلاف" : "ألف")"
    }

    private static func roundUp(_ x: Int, _ step: Int) -> Int {
        ((x + step - 1) / step) * step
    }

    private static func clamp(_ x: Int, _ lo: Int, _ hi: Int) -> Int {
        min(max(x, lo), hi)
    }

    /// معدلك اليومي بآخر ٢٨ يوم قبل بداية التحدي (الأيام اللي فيها خطوات بس)
    static func baseline(before start: Date, steps: [Date: Int]) -> Int {
        let cal = AppCalendar.local
        var total = 0
        var n = 0
        for i in 1...28 {
            guard let d = cal.date(byAdding: .day, value: -i, to: start),
                  let s = steps[d], s > 0 else { continue }
            total += s
            n += 1
        }
        return n >= 3 ? total / n : 6_000
    }

    /// خطوات أيام الفترة (لين اليوم)
    private static func values(from start: Date, to end: Date, today: Date, steps: [Date: Int]) -> [Int] {
        let cal = AppCalendar.local
        var out: [Int] = []
        var d = start
        while d < end && d <= today {
            out.append(steps[d] ?? 0)
            guard let next = cal.date(byAdding: .day, value: 1, to: d) else { break }
            d = next
        }
        return out
    }

    static func weekChallenges(start: Date, end: Date, today: Date, steps: [Date: Int]) -> [Challenge] {
        let b = baseline(before: start, steps: steps)
        let v = values(from: start, to: end, today: today, steps: steps)
        let key = "w\(Int(start.timeIntervalSince1970))"

        let total = clamp(roundUp(b * 7 * 11 / 10, 5_000), 35_000, 140_000)
        let thr = clamp(roundUp(b, 1_000), 7_000, 15_000)
        let big = clamp(roundUp(b * 3 / 2, 1_000), 10_000, 25_000)

        return [
            Challenge(id: "\(key)-total", period: .week, icon: "figure.walk",
                      title: "امش \(Fmt.num(total)) خطوة هذا الأسبوع",
                      detail: "مجموع خطواتك من الأحد إلى السبت",
                      value: v.reduce(0, +), target: total, xp: weeklyXP, countsDays: false),
            Challenge(id: "\(key)-days", period: .week, icon: "calendar",
                      title: "امش \(Fmt.num(thr)) خطوة في ٤ أيام",
                      detail: "أي ٤ أيام من الأسبوع",
                      value: v.filter { $0 >= thr }.count, target: 4, xp: weeklyXP, countsDays: true),
            Challenge(id: "\(key)-big", period: .week, icon: "bolt.fill",
                      title: "يوم الأسبوع: امش \(Fmt.num(big)) خطوة",
                      detail: "في يوم واحد من الأسبوع",
                      value: v.max() ?? 0, target: big, xp: weeklyXP, countsDays: false)
        ]
    }

    static func monthChallenges(start: Date, end: Date, today: Date, steps: [Date: Int]) -> [Challenge] {
        let cal = AppCalendar.local
        let b = baseline(before: start, steps: steps)
        let v = values(from: start, to: end, today: today, steps: steps)
        let days = cal.dateComponents([.day], from: start, to: end).day ?? 30
        let key = "m\(Int(start.timeIntervalSince1970))"

        let total = clamp(roundUp(b * days * 11 / 10, 10_000), 150_000, 600_000)
        let active = max(days * 2 / 3, 15)
        let big = clamp(roundUp(b * 2, 1_000), 15_000, 30_000)

        return [
            Challenge(id: "\(key)-total", period: .month, icon: "map.fill",
                      title: "امش \(k(total)) خطوة هذا الشهر",
                      detail: "مجموع خطواتك من أول الشهر إلى آخره",
                      value: v.reduce(0, +), target: total, xp: monthlyXP, countsDays: false),
            Challenge(id: "\(key)-active", period: .month, icon: "checkmark.circle.fill",
                      title: "امش ٧٬٠٠٠ خطوة في \(Fmt.num(active)) يوم",
                      detail: "أي \(Fmt.num(active)) يوم من الشهر",
                      value: v.filter { $0 >= 7_000 }.count, target: active, xp: monthlyXP, countsDays: true),
            Challenge(id: "\(key)-big", period: .month, icon: "crown.fill",
                      title: "يوم الشهر: امش \(Fmt.num(big)) خطوة",
                      detail: "في يوم واحد من الشهر",
                      value: v.max() ?? 0, target: big, xp: monthlyXP, countsDays: false)
        ]
    }
}

/// يحسب المستوى والتحديات. الجزء الثقيل (كل السجل القديم) يتحسب بس لما السجل يتغير،
/// والتحديث المباشر وأنت تمشي يحسب اليوم والأسبوع والشهر الحاليين بس.
final class ProgressEngine {
    private var cacheKey: Int?
    private var cachedPastXP = 0

    func compute(steps: [Date: Int], today: Date) -> ProgressState {
        let cal = AppCalendar.local
        guard let weekInt = cal.dateInterval(of: .weekOfYear, for: today),
              let monthInt = cal.dateInterval(of: .month, for: today) else { return .empty }

        let key = historyKey(steps, today: today)
        if key != cacheKey {
            cachedPastXP = pastXP(steps: steps, today: today)
            cacheKey = key
        }

        let week = Progression.weekChallenges(start: weekInt.start, end: weekInt.end, today: today, steps: steps)
        let month = Progression.monthChallenges(start: monthInt.start, end: monthInt.end, today: today, steps: steps)
        let todayXP = Progression.dayXP(steps[today] ?? 0)
        let currentChallengeXP = (week + month).filter(\.done).reduce(0) { $0 + $1.xp }

        var p = ProgressState()
        p.level = LevelInfo(xp: cachedPastXP + todayXP + currentChallengeXP)
        p.todayXP = todayXP
        p.week = week
        p.month = month
        p.weekEnd = weekInt.end
        p.monthEnd = monthInt.end
        return p
    }

    /// بصمة للسجل كله ما عدا اليوم (اليوم يتغير كل ثانيتين وأنت تمشي)
    private func historyKey(_ steps: [Date: Int], today: Date) -> Int {
        var h = Int(today.timeIntervalSince1970)
        for (d, s) in steps where d != today {
            let t = Int(d.timeIntervalSince1970)
            h = h &+ ((t &* 2_654_435_761) ^ (s &* 40_503))
        }
        return h &+ steps.count
    }

    /// XP الأيام اللي قبل اليوم + التحديات اللي فتراتها خلصت
    private func pastXP(steps: [Date: Int], today: Date) -> Int {
        let cal = AppCalendar.local
        var xp = 0
        for (d, s) in steps where d < today {
            xp += Progression.dayXP(s)
        }

        guard let first = steps.filter({ $0.value > 0 && $0.key < today }).keys.min() else { return xp }

        // الأسابيع اللي خلصت
        var ws = cal.dateInterval(of: .weekOfYear, for: first)?.start ?? first
        var guardCount = 0
        while guardCount < 600 {
            guardCount += 1
            guard let we = cal.date(byAdding: .weekOfYear, value: 1, to: ws), we <= today else { break }
            let cs = Progression.weekChallenges(start: ws, end: we, today: today, steps: steps)
            xp += cs.filter(\.done).reduce(0) { $0 + $1.xp }
            ws = we
        }

        // الشهور اللي خلصت
        var ms = cal.dateInterval(of: .month, for: first)?.start ?? first
        guardCount = 0
        while guardCount < 150 {
            guardCount += 1
            guard let me = cal.date(byAdding: .month, value: 1, to: ms), me <= today else { break }
            let cs = Progression.monthChallenges(start: ms, end: me, today: today, steps: steps)
            xp += cs.filter(\.done).reduce(0) { $0 + $1.xp }
            ms = me
        }
        return xp
    }
}
