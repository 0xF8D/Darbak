// دربك — © 0xF8D
//
// مصادر الخطوات:
// 1) HealthKit: السجل الكامل (الجوال + الساعة) — يتحدث على دفعات
// 2) CoreMotion (عداد الجوال): تحديث مباشر كل ثانيتين وأنت تمشي
// ناخذ الأكبر بينهم لكل يوم، فالرقم ما يعلق ولا يضيع السجل القديم.

import Foundation
import HealthKit
import CoreMotion
import WidgetKit
import Combine
import UIKit

struct DayStat: Identifiable {
    let date: Date
    let steps: Int
    let isFuture: Bool
    var frozen: Bool = false
    var id: Date { date }
}

struct DayExtras {
    var distanceKm: Double
    var kcal: Int
    var floors: Int
}

final class HealthStore: ObservableObject {
    static let shared = HealthStore()

    @Published private(set) var steps: [Date: Int] = [:]
    @Published private(set) var now = Date()
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?
    @Published private(set) var streak = 0
    @Published private(set) var longestStreak = 0
    @Published private(set) var frozenDays: Set<Date> = []
    @Published private(set) var liveDistanceM = 0.0
    @Published private(set) var liveFloors = 0
    @Published private(set) var hkDistanceKm = 0.0
    @Published private(set) var hkKcal = 0.0
    @Published private(set) var hkFloors = 0
    @Published var celebration: BadgeTier?

    private let settings = AppSettings.shared
    private let store = HKHealthStore()
    private let stepType = HKQuantityType(.stepCount)
    private let livePedometer = CMPedometer()
    private let historyPedometer = CMPedometer()

    private var hkSteps: [Date: Int] = [:]
    private var pedSteps: [Date: Int] = [:]
    private var liveDay = Date.distantPast
    private var liveSteps = 0
    private var activeDay = Date.distantPast
    private var collectionQuery: HKStatisticsCollectionQuery?
    private var healthReady = false
    private var observerStarted = false
    private var started = false
    private var lastExtras = Date.distantPast
    private var lastWidgetPush = Date.distantPast
    private var lastWidgetSteps = -1
    private var baselineUntil = Date.distantFuture
    private var lastThousand = 0
    private var milestoneDay = Date.distantPast
    private var streakKey = ""
    private var bag = Set<AnyCancellable>()

    private var readTypes: Set<HKObjectType> {
        [HKQuantityType(.stepCount),
         HKQuantityType(.distanceWalkingRunning),
         HKQuantityType(.activeEnergyBurned),
         HKQuantityType(.flightsClimbed)]
    }

    init() {
        settings.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.settingsChanged() }
            }
            .store(in: &bag)
    }

    // MARK: - Start

    func start() {
        guard !started else { return }
        started = true
        activeDay = today
        baselineUntil = Date().addingTimeInterval(4)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) { [weak self] in
            self?.checkMilestones()
        }

        startPedometer()
        loadPedometerHistory()

        guard HKHealthStore.isHealthDataAvailable() else {
            isLoading = false
            recompute()
            return
        }
        store.requestAuthorization(toShare: [], read: readTypes) { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
                self.healthReady = true
                self.startQuery()
                self.startObserver()
                self.refreshExtras()
            }
        }
    }

    /// يستدعى كل ٥ ثواني وعند فتح التطبيق
    func tick(force: Bool = false) {
        guard started else {
            now = Date()
            return
        }
        let t = today
        if t != activeDay {
            // دخل يوم جديد (١٢ الليل حسب ساعة الجوال): كل شي يتصفر ويبدأ من جديد
            now = Date()
            activeDay = t
            hkDistanceKm = 0
            hkKcal = 0
            hkFloors = 0
            startPedometer()
            loadPedometerHistory()
            if healthReady { startQuery() }
            streakKey = ""
            recompute()
            pushWidget(force: true)
        }
        if force || Date().timeIntervalSince(lastExtras) > 30 {
            refreshExtras()
        }
        if force { recompute() }
        pushWidget(force: force)
    }

    private func settingsChanged() {
        streakKey = ""
        recompute()
        pushWidget(force: true)
    }

    // MARK: - HealthKit

    private func startQuery() {
        if let collectionQuery { store.stop(collectionQuery) }

        let cal = AppCalendar.local
        let todayStart = cal.startOfDay(for: Date())
        let from = cal.date(byAdding: .year, value: -5, to: todayStart) ?? todayStart

        let predicate = HKQuery.predicateForSamples(withStart: from, end: nil, options: [])
        let q = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: todayStart,
            intervalComponents: DateComponents(day: 1)
        )
        q.initialResultsHandler = { [weak self] _, results, error in
            self?.handle(results, error)
        }
        q.statisticsUpdateHandler = { [weak self] _, _, results, error in
            self?.handle(results, error)
        }
        store.execute(q)
        collectionQuery = q
    }

    private func handle(_ results: HKStatisticsCollection?, _ error: Error?) {
        var map: [Date: Int] = [:]
        let ok = results != nil
        let message = error?.localizedDescription
        if let results {
            let cal = AppCalendar.local
            for s in results.statistics() {
                let v = s.sumQuantity()?.doubleValue(for: .count()) ?? 0
                if v > 0 { map[cal.startOfDay(for: s.startDate)] = Int(v.rounded()) }
            }
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if ok {
                self.hkSteps = map
                self.errorMessage = nil
            } else if let message {
                self.errorMessage = message
            }
            self.isLoading = false
            self.streakKey = ""
            self.recompute()
        }
    }

    private func startObserver() {
        guard !observerStarted else { return }
        observerStarted = true
        let q = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completion, error in
            guard error == nil, let self else {
                completion()
                return
            }
            Task {
                await self.backgroundRefresh()
                completion()
            }
        }
        store.execute(q)
        store.enableBackgroundDelivery(for: stepType, frequency: .hourly) { _, _ in }
    }

    private func sum(_ id: HKQuantityTypeIdentifier, _ unit: HKUnit, from: Date, to: Date) async -> Double {
        guard HKHealthStore.isHealthDataAvailable() else { return 0 }
        return await withCheckedContinuation { cont in
            let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: .strictStartDate)
            let q = HKStatisticsQuery(quantityType: HKQuantityType(id),
                                      quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { _, stats, _ in
                cont.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(q)
        }
    }

    /// المسافة والسعرات والطوابق لليوم من الصحة
    private func refreshExtras() {
        lastExtras = Date()
        guard healthReady else { return }
        let start = today
        Task { [weak self] in
            guard let self else { return }
            let end = Date()
            let d = await self.sum(.distanceWalkingRunning, .meterUnit(with: .kilo), from: start, to: end)
            let k = await self.sum(.activeEnergyBurned, .kilocalorie(), from: start, to: end)
            let f = await self.sum(.flightsClimbed, .count(), from: start, to: end)
            await MainActor.run {
                guard start == self.today else { return }
                self.hkDistanceKm = d
                self.hkKcal = k
                self.hkFloors = Int(f.rounded())
            }
        }
    }

    /// تفاصيل يوم سابق (لما تضغط على دائرة)
    func dayExtras(for day: Date, steps s: Int) async -> DayExtras {
        guard let end = AppCalendar.local.date(byAdding: .day, value: 1, to: day) else {
            return DayExtras(distanceKm: Double(s) * 0.00075, kcal: Int(Double(s) * 0.04), floors: 0)
        }
        let d = await sum(.distanceWalkingRunning, .meterUnit(with: .kilo), from: day, to: end)
        let k = await sum(.activeEnergyBurned, .kilocalorie(), from: day, to: end)
        let f = await sum(.flightsClimbed, .count(), from: day, to: end)
        return DayExtras(distanceKm: d > 0 ? d : Double(s) * 0.00075,
                         kcal: max(Int(k.rounded()), Int(Double(s) * 0.04)),
                         floors: Int(f.rounded()))
    }

    // MARK: - CoreMotion (التحديث المباشر)

    private func startPedometer() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        let day = today
        livePedometer.stopUpdates()
        liveDay = day
        liveSteps = 0
        liveDistanceM = 0
        liveFloors = 0
        livePedometer.startUpdates(from: day) { [weak self] data, _ in
            guard let data else { return }
            let s = data.numberOfSteps.intValue
            let dist = data.distance?.doubleValue ?? 0
            let fl = data.floorsAscended?.intValue ?? 0
            DispatchQueue.main.async {
                self?.applyLive(day: day, steps: s, distance: dist, floors: fl)
            }
        }
    }

    private func applyLive(day: Date, steps s: Int, distance: Double, floors: Int) {
        guard day == liveDay else { return }
        liveSteps = max(liveSteps, s)
        if distance > liveDistanceM { liveDistanceM = distance }
        if floors > liveFloors { liveFloors = floors }
        recompute()
    }

    /// الجوال يحفظ آخر ٧ أيام، نستخدمها لو الصحة متأخرة أو مقفلة
    private func loadPedometerHistory() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        let cal = AppCalendar.local
        let t = today
        for i in 1...6 {
            guard let s = cal.date(byAdding: .day, value: -i, to: t),
                  let e = cal.date(byAdding: .day, value: 1, to: s) else { continue }
            historyPedometer.queryPedometerData(from: s, to: e) { [weak self] data, _ in
                guard let n = data?.numberOfSteps.intValue else { return }
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.pedSteps[s] = n
                    self.streakKey = ""
                    self.recompute()
                }
            }
        }
    }

    private func pedometerSteps(from start: Date) async -> Int {
        guard CMPedometer.isStepCountingAvailable() else { return 0 }
        return await withCheckedContinuation { cont in
            historyPedometer.queryPedometerData(from: start, to: Date()) { data, _ in
                cont.resume(returning: data?.numberOfSteps.intValue ?? 0)
            }
        }
    }

    // MARK: - تحديث بالخلفية (الصحة توقظ التطبيق + Background App Refresh)

    func backgroundRefresh() async {
        let start = AppCalendar.startOfToday()
        let hk = await sum(.stepCount, .count(), from: start, to: Date())
        let ped = await pedometerSteps(from: start)
        let s = max(Int(hk.rounded()), ped)
        await MainActor.run {
            if self.liveDay != start {
                self.liveDay = start
                self.liveSteps = 0
                self.liveDistanceM = 0
                self.liveFloors = 0
            }
            self.liveSteps = max(self.liveSteps, s)
            self.recompute()
            self.pushWidget(force: true)
        }
    }

    // MARK: - الدمج والحسابات

    private func recompute() {
        var m = hkSteps
        for (d, n) in pedSteps where n > (m[d] ?? 0) {
            m[d] = n
        }
        let t = today
        if liveDay == t, liveSteps > (m[t] ?? 0) {
            m[t] = liveSteps
        }
        if m != steps { steps = m }

        updateStreaksIfNeeded()
        checkMilestones()
        pushWidget()
        WalkMode.shared.update(steps: todaySteps, goal: settings.goal, distanceKm: todayDistanceKm)
    }

    private func updateStreaksIfNeeded() {
        let t = today
        let goal = settings.goal
        let reached = (steps[t] ?? 0) >= goal
        let key = "\(t.timeIntervalSince1970)|\(goal)|\(reached)"
        guard key != streakKey else { return }
        streakKey = key
        computeStreaks()
    }

    /// الستريك: أيام متتالية وصلت فيها هدفك. اليوم ما يكسر الستريك لين ينتهي.
    /// التجميد (تلقائي): يوم واحد فائت بكل أسبوع (أحد إلى سبت) يحفظ الستريك بدون ما يزيده.
    private func computeStreaks() {
        let cal = AppCalendar.local
        let goal = settings.goal
        let freeze = true
        let t = today

        guard let first = steps.filter({ $0.value > 0 }).keys.min() else {
            streak = 0
            longestStreak = 0
            frozenDays = []
            return
        }

        var run = 0
        var best = 0
        var usedWeeks = Set<Date>()
        var frozen = Set<Date>()
        var d = first
        while d <= t {
            let n = steps[d] ?? 0
            if n >= goal {
                run += 1
            } else if d == t {
                // اليوم لسه ما خلص
            } else {
                let week = cal.dateInterval(of: .weekOfYear, for: d)?.start ?? d
                if freeze && run > 0 && !usedWeeks.contains(week) {
                    usedWeeks.insert(week)
                    frozen.insert(d)
                } else {
                    run = 0
                }
            }
            best = max(best, run)
            guard let next = cal.date(byAdding: .day, value: 1, to: d) else { break }
            d = next
        }

        if streak != run { streak = run }
        if longestStreak != best { longestStreak = best }
        if frozenDays != frozen { frozenDays = frozen }
    }

    // MARK: - الاهتزاز والاحتفال بالدروع

    private func celebratedKey(_ day: Date) -> String { "celebrated-\(Int(day.timeIntervalSince1970))" }

    private func checkMilestones() {
        let t = today
        let s = steps[t] ?? 0
        let k = s / 1000

        if milestoneDay != t || Date() < baselineUntil {
            milestoneDay = t
            lastThousand = k
            return
        }

        let active = UIApplication.shared.applicationState == .active

        if k > lastThousand {
            lastThousand = k
            if settings.milestoneHaptics { Haptics.light() }
        }

        if let tier = BadgeTier.highest(for: s), active {
            let done = UserDefaults.standard.integer(forKey: celebratedKey(t))
            if tier.steps > done {
                UserDefaults.standard.set(tier.steps, forKey: celebratedKey(t))
                celebration = tier
                Haptics.success()
            }
        }
    }

    // MARK: - الويدجت والتذكير

    func pushWidget(force: Bool = false) {
        let s = todaySteps
        let changed = s != lastWidgetSteps
        let crossed = s / 1000 != max(lastWidgetSteps, 0) / 1000
        guard force || (changed && (crossed || Date().timeIntervalSince(lastWidgetPush) > 90)) else { return }
        lastWidgetPush = Date()
        lastWidgetSteps = s
        snapshot().save()
        WidgetCenter.shared.reloadAllTimelines()
        Reminder.reschedule(steps: s, goal: settings.goal)
    }

    func snapshot() -> StepsSnapshot {
        StepsSnapshot(day: today, steps: todaySteps, goal: settings.goal, distanceKm: todayDistanceKm,
                      kcal: todayKcal, floors: todayFloors, streak: streak, updated: Date())
    }

    // MARK: - Derived data

    var today: Date { AppCalendar.startOfToday() }
    var todaySteps: Int { steps[today] ?? 0 }
    var hasAnyData: Bool { steps.values.contains { $0 > 0 } }

    var todayDistanceKm: Double {
        let live = liveDay == today ? liveDistanceM / 1000 : 0
        let v = max(hkDistanceKm, live)
        return v > 0 ? v : Double(todaySteps) * 0.00075
    }

    var todayKcal: Int { max(Int(hkKcal.rounded()), Int(Double(todaySteps) * 0.04)) }

    var todayFloors: Int { max(hkFloors, liveDay == today ? liveFloors : 0) }

    var yesterday: Date {
        AppCalendar.local.date(byAdding: .day, value: -1, to: today) ?? today
    }

    /// الستريك محفوظ بالتجميد: فاتك أمس، واليوم لسه ما قفلت هدفك
    var streakFrozen: Bool {
        streak > 0 && frozenDays.contains(yesterday) && todaySteps < settings.goal
    }

    /// آخر ٦ أيام قبل اليوم (من الأقدم لأمس). اليوم نفسه بالحلقة فوق.
    func lastDays(_ n: Int = 6) -> [DayStat] {
        let cal = AppCalendar.local
        let t = today
        return (1...n).reversed().compactMap { i in
            guard let d = cal.date(byAdding: .day, value: -i, to: t) else { return nil }
            return DayStat(date: d, steps: steps[d] ?? 0, isFuture: false, frozen: frozenDays.contains(d))
        }
    }

    var bestDay: DayStat? {
        guard let best = steps.max(by: { $0.value < $1.value }), best.value > 0 else { return nil }
        return DayStat(date: best.key, steps: best.value, isFuture: false)
    }

    func count(for tier: BadgeTier) -> Int {
        steps.values.filter { $0 >= tier.steps }.count
    }

    func days(for tier: BadgeTier) -> [DayStat] {
        steps
            .filter { $0.value >= tier.steps }
            .map { DayStat(date: $0.key, steps: $0.value, isFuture: false) }
            .sorted { $0.date > $1.date }
    }

    /// أسبوع كامل (الأحد إلى السبت). offset = 0 هذا الأسبوع، -1 الأسبوع الماضي
    func week(offset: Int) -> [DayStat] {
        let cal = AppCalendar.local
        guard let interval = cal.dateInterval(of: .weekOfYear, for: Date()),
              let start = cal.date(byAdding: .weekOfYear, value: offset, to: interval.start)
        else { return [] }
        let t = today
        return (0..<7).compactMap { i in
            guard let d = cal.date(byAdding: .day, value: i, to: start) else { return nil }
            return DayStat(date: d, steps: steps[d] ?? 0, isFuture: d > t, frozen: frozenDays.contains(d))
        }
    }
}
