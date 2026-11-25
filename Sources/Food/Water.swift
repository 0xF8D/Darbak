// دربك — © 0xF8D
//
// مويتي: تسجل كم شربت مويه بالمل، والعداد يتصفر ١٢ الليل.
// كل يوم ينحفظ لحاله (آخر ٦٠ يوم) عشان تشوف أسبوعك.

import SwiftUI

final class WaterStore: ObservableObject {
    static let shared = WaterStore()

    static let goals = [2_000, 2_500, 3_000, 3_500, 4_000]
    struct Quick: Identifiable {
        let ml: Int
        var id: Int { ml }
    }

    static let quick = [Quick(ml: 150), Quick(ml: 250), Quick(ml: 330), Quick(ml: 500)]

    struct DayTotal: Identifiable {
        let date: Date
        let ml: Int
        var id: Date { date }
    }

    struct Entry: Codable, Identifiable, Equatable {
        var id = UUID()
        let ml: Int
        let time: Date
    }

    private let d = UserDefaults.standard
    private let logKey = "water.log"
    private var log: [String: [Entry]] = [:]

    @Published var goal: Int { didSet { d.set(goal, forKey: "water.goal") } }
    @Published private(set) var entries: [Entry] = []
    @Published private(set) var dayKey: String

    init() {
        let g = d.integer(forKey: "water.goal")
        goal = g >= 500 ? g : 2_500
        dayKey = Self.key(for: Date())
        if let data = d.data(forKey: logKey),
           let saved = try? JSONDecoder().decode([String: [Entry]].self, from: data) {
            log = saved
        }
        entries = log[dayKey] ?? []
    }

    var total: Int { entries.reduce(0) { $0 + $1.ml } }

    /// هدف تكتبه بنفسك (بين ٥٠٠ و ١٠٬٠٠٠ مل)
    func setGoal(_ ml: Int) {
        goal = min(max(ml, 500), 10_000)
        Haptics.tap()
    }
    var progress: Double { min(Double(total) / Double(max(goal, 1)), 1) }
    var remaining: Int { max(goal - total, 0) }

    /// دخل يوم جديد؟ نبدأ من صفر
    func refreshDay() {
        let k = Self.key(for: Date())
        guard k != dayKey else { return }
        dayKey = k
        entries = log[k] ?? []
    }

    func add(_ ml: Int) {
        refreshDay()
        guard ml > 0, ml <= 3_000 else { return }
        let before = total
        entries.append(Entry(ml: ml, time: Date()))
        save()
        if before < goal && total >= goal {
            Haptics.success()
        } else {
            Haptics.tap()
        }
    }

    func remove(_ e: Entry) {
        entries.removeAll { $0.id == e.id }
        save()
    }

    func undo() {
        guard !entries.isEmpty else { return }
        entries.removeLast()
        save()
        Haptics.tap()
    }

    func total(on date: Date) -> Int {
        let k = Self.key(for: date)
        let list = k == dayKey ? entries : (log[k] ?? [])
        return list.reduce(0) { $0 + $1.ml }
    }

    private func save() {
        log[dayKey] = entries
        if let cutoff = AppCalendar.local.date(byAdding: .day, value: -60, to: Date()) {
            let c = Self.key(for: cutoff)
            log = log.filter { $0.key >= c }
        }
        if let data = try? JSONEncoder().encode(log) {
            d.set(data, forKey: logKey)
        }
    }

    static func key(for date: Date) -> String { keyFormatter.string(from: date) }

    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .autoupdatingCurrent
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

// MARK: - الشاشة

struct WaterSection: View {
    @ObservedObject var water = WaterStore.shared
    @State private var custom = ""

    private let blue = [Palette.cyan, Palette.blue]

    var body: some View {
        VStack(spacing: 16) {
            ringCard
            quickCard
            entriesCard
            weekCard
        }
        .onAppear { water.refreshDay() }
    }

    // MARK: الحلقة

    private var ringCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.07), lineWidth: 16)
                Circle()
                    .trim(from: 0, to: max(water.progress, 0.002))
                    .stroke(AngularGradient(colors: blue + [Palette.cyan], center: .center, startAngle: .degrees(0), endAngle: .degrees(360)),
                            style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Palette.cyan.opacity(0.5), radius: 10)
                    .animation(.spring(response: 0.7, dampingFraction: 0.8), value: water.progress)
                VStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: blue, startPoint: .top, endPoint: .bottom))
                    Text(Fmt.num(water.total))
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: water.total)
                    Text("من \(Fmt.num(water.goal)) مل")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.text2)
                }
                .environment(\.layoutDirection, .rightToLeft)
            }
            // الحلقة تمشي مع عقارب الساعة من فوق
            .environment(\.layoutDirection, .leftToRight)
            .frame(width: 200, height: 200)
            .padding(.top, 6)

            Text(water.total >= water.goal ? "كفو، وصلت هدفك 💧" : "باقي \(Fmt.num(water.remaining)) مل على هدفك")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(water.total >= water.goal ? Palette.green : Palette.cyan)
            Text("العداد يتصفر ١٢ الليل · الهدف تغيره من الإعدادات")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Palette.text3)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .glassCard(tint: Palette.cyan)
    }

    // MARK: إضافة سريعة

    private var quickCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("كم شربت؟")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(WaterStore.quick) { q in
                    Button {
                        water.add(q.ml)
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 12 + CGFloat(q.ml) / 40, weight: .bold))
                                .foregroundStyle(LinearGradient(colors: blue, startPoint: .top, endPoint: .bottom))
                                .frame(height: 28)
                            Text("\(Fmt.num(q.ml))")
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                            Text("مل")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(Palette.text2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Palette.cyan.opacity(0.25), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(alignment: .bottom, spacing: 8) {
                InputField(title: "كمية ثانية", text: $custom, placeholder: "مثلا ٤٠٠", keyboard: .numberPad, suffix: "مل")
                Button("أضف") {
                    if let v = Num.parse(custom) {
                        water.add(Int(v.rounded()))
                    }
                    custom = ""
                    hideKeyboard()
                }
                .buttonStyle(SoftButtonStyle(color: Palette.cyan))
                .disabled(Num.parse(custom) == nil)
                .padding(.bottom, 6)
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: سجل اليوم

    private var entriesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("شربت اليوم")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                if !water.entries.isEmpty {
                    Button {
                        water.undo()
                    } label: {
                        Label("تراجع", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(SoftButtonStyle(color: Palette.text2))
                }
            }
            if water.entries.isEmpty {
                Text("باقي ما سجلت شي اليوم")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Palette.text2)
            } else {
                ForEach(water.entries.reversed()) { e in
                    HStack(spacing: 10) {
                        Image(systemName: "drop.fill")
                            .foregroundStyle(Palette.cyan)
                        Text("\(Fmt.num(e.ml)) مل")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(Fmt.time(e.time))
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(Palette.text2)
                        Button {
                            water.remove(e)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(Palette.pink.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    // MARK: آخر ٧ أيام

    private var weekCard: some View {
        let cal = AppCalendar.local
        let today = AppCalendar.startOfToday()
        let days: [WaterStore.DayTotal] = (0..<7).reversed().compactMap { i in
            guard let d = cal.date(byAdding: .day, value: -i, to: today) else { return nil }
            return WaterStore.DayTotal(date: d, ml: water.total(on: d))
        }
        let top = max(days.map { $0.ml }.max() ?? 0, water.goal, 1)
        return VStack(alignment: .leading, spacing: 12) {
            Text("آخر ٧ أيام")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(days) { item in
                    let day = item.date
                    let ml = item.ml
                    VStack(spacing: 6) {
                        Text(ml >= 1000 ? Fmt.dec(Double(ml) / 1000) : Fmt.num(ml))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(ml >= water.goal ? Palette.green : Palette.text2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Capsule()
                            .fill(ml >= water.goal
                                  ? AnyShapeStyle(Palette.green)
                                  : AnyShapeStyle(LinearGradient(colors: blue, startPoint: .top, endPoint: .bottom)))
                            .frame(height: max(6, 90 * CGFloat(ml) / CGFloat(top)))
                            .opacity(ml > 0 ? 1 : 0.25)
                        Text(Fmt.weekday(day))
                            .font(.system(size: 10, weight: day == today ? .bold : .medium, design: .rounded))
                            .foregroundStyle(day == today ? Color.white : Palette.text3)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 130, alignment: .bottom)
            Text("الأرقام فوق بالألف مل (لتر)")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Palette.text3)
        }
        .padding(16)
        .glassCard()
    }
}

// MARK: - هدف المويه (في الإعدادات)

struct WaterGoalCard: View {
    @ObservedObject var water = WaterStore.shared
    @State private var customGoal = ""

    private let blue = [Palette.cyan, Palette.blue]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("هدف المويه اليومي", systemImage: "drop.fill")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            HStack(spacing: 8) {
                ForEach(WaterStore.goals, id: \.self) { g in
                    let on = water.goal == g
                    Button {
                        water.goal = g
                        Haptics.tap()
                    } label: {
                        VStack(spacing: 2) {
                            Text(Fmt.dec(Double(g) / 1000))
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text("لتر")
                                .font(.system(size: 11, design: .rounded))
                        }
                        .foregroundStyle(on ? Color.white : Palette.text2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(on ? AnyShapeStyle(LinearGradient(colors: blue, startPoint: .topLeading, endPoint: .bottomTrailing))
                                         : AnyShapeStyle(Color.white.opacity(0.05)))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(alignment: .bottom, spacing: 8) {
                InputField(title: "أو اكتب هدفك", text: $customGoal,
                           placeholder: "مثلا ٢٨٠٠", keyboard: .numberPad, suffix: "مل")
                Button("حفظ") {
                    if let v = Num.parse(customGoal) {
                        water.setGoal(Int(v.rounded()))
                    }
                    customGoal = ""
                    hideKeyboard()
                }
                .buttonStyle(SoftButtonStyle(color: Palette.cyan))
                .disabled(Num.parse(customGoal) == nil)
                .padding(.bottom, 6)
            }
            if !WaterStore.goals.contains(water.goal) {
                Text("هدفك الحين: \(Fmt.num(water.goal)) مل")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.cyan)
            }
        }
        .padding(16)
        .glassCard()
    }
}
