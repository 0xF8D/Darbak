import Foundation
import HealthKit

struct DayStat: Identifiable {
    let date: Date
    let steps: Int
    let isFuture: Bool
    var id: Date { date }
}

final class HealthStore: ObservableObject {
    @Published private(set) var dailySteps: [Date: Int] = [:]
    @Published private(set) var now = Date()
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    private let store = HKHealthStore()
    private let stepType = HKQuantityType(.stepCount)
    private var query: HKStatisticsCollectionQuery?
    private var queryDay = Date.distantPast
    private var started = false

    // MARK: - Start

    func start() {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "الصحة غير متاحة على هذا الجهاز"
            isLoading = false
            return
        }
        store.requestAuthorization(toShare: [], read: [stepType]) { [weak self] _, error in
            DispatchQueue.main.async {
                if let error { self?.errorMessage = error.localizedDescription }
                self?.startQuery()
            }
        }
    }

    /// يستدعى كل شوي وعند فتح التطبيق: إذا تغير اليوم (12 منتصف الليل بتوقيت السعودية) نعيد الحساب
    func tick() {
        now = Date()
        guard started else { return }
        if AppCalendar.riyadh.startOfDay(for: now) != queryDay {
            startQuery()
        }
    }

    private func startQuery() {
        started = true
        if let query { store.stop(query) }

        let cal = AppCalendar.riyadh
        let todayStart = cal.startOfDay(for: Date())
        queryDay = todayStart
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
        query = q
    }

    private func handle(_ results: HKStatisticsCollection?, _ error: Error?) {
        var map: [Date: Int] = [:]
        let ok = results != nil
        let message = error?.localizedDescription
        if let results {
            let cal = AppCalendar.riyadh
            for s in results.statistics() {
                let v = s.sumQuantity()?.doubleValue(for: .count()) ?? 0
                map[cal.startOfDay(for: s.startDate)] = Int(v.rounded())
            }
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if ok {
                self.dailySteps = map
                self.errorMessage = nil
            } else if let message {
                self.errorMessage = message
            }
            self.isLoading = false
            self.now = Date()
        }
    }

    // MARK: - Derived data

    var today: Date { AppCalendar.riyadh.startOfDay(for: now) }
    var todaySteps: Int { dailySteps[today] ?? 0 }
    var hasAnyData: Bool { dailySteps.values.contains { $0 > 0 } }

    func count(for tier: BadgeTier) -> Int {
        dailySteps.values.filter { $0 >= tier.steps }.count
    }

    func days(for tier: BadgeTier) -> [DayStat] {
        dailySteps
            .filter { $0.value >= tier.steps }
            .map { DayStat(date: $0.key, steps: $0.value, isFuture: false) }
            .sorted { $0.date > $1.date }
    }

    /// أسبوع كامل (الأحد إلى السبت) بتوقيت السعودية. offset = 0 هذا الأسبوع، -1 الأسبوع الماضي
    func week(offset: Int) -> [DayStat] {
        let cal = AppCalendar.riyadh
        guard let interval = cal.dateInterval(of: .weekOfYear, for: now),
              let start = cal.date(byAdding: .weekOfYear, value: offset, to: interval.start)
        else { return [] }
        let t = today
        return (0..<7).compactMap { i in
            guard let d = cal.date(byAdding: .day, value: i, to: start) else { return nil }
            return DayStat(date: d, steps: dailySteps[d] ?? 0, isFuture: d > t)
        }
    }
}
