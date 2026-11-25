// دربك — © 0xF8D
//
// وضع المشي: زر تشغيل/إيقاف.
// - يبقي التطبيق شغال بالخلفية عن طريق الموقع (بدقة منخفضة)، فعداد الجوال يكمل يرسل الخطوات
// - يعرض الخطوات مباشرة على شاشة القفل والجزيرة (Live Activity)

import Foundation
import CoreLocation
import ActivityKit

final class WalkMode: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = WalkMode()

    @Published private(set) var isOn = false
    @Published private(set) var message: String?

    private let location = CLLocationManager()
    private var activity: Activity<WalkActivityAttributes>?
    private var lastPush = Date.distantPast
    private var lastState: WalkActivityAttributes.ContentState?

    override init() {
        super.init()
        location.delegate = self
        // أي نشاط باقي من تشغيل سابق نقفله
        for a in Activity<WalkActivityAttributes>.activities {
            Task { await a.end(nil, dismissalPolicy: .immediate) }
        }
    }

    func toggle() {
        if isOn { stop() } else { start() }
    }

    func start() {
        isOn = true
        message = nil
        switch location.authorizationStatus {
        case .notDetermined:
            location.requestWhenInUseAuthorization()
        case .denied, .restricted:
            message = "الموقع مقفل، فالتحديث بالخلفية ممكن يوقف. فعله من الإعدادات > دربك > الموقع."
        default:
            beginLocation()
        }
        startActivity()
    }

    func stop() {
        isOn = false
        location.stopUpdatingLocation()
        location.allowsBackgroundLocationUpdates = false
        if let activity {
            let endState = lastState
            Task {
                if let endState {
                    await activity.end(ActivityContent(state: endState, staleDate: nil), dismissalPolicy: .immediate)
                } else {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
        }
        activity = nil
        lastState = nil
    }

    /// يستدعى من HealthStore كل ما تغيرت الخطوات
    func update(steps: Int, goal: Int, distanceKm: Double) {
        guard isOn, let activity else { return }
        let state = WalkActivityAttributes.ContentState(steps: steps, goal: goal, distanceKm: distanceKm)
        guard state != lastState else { return }
        guard Date().timeIntervalSince(lastPush) > 2 else { return }
        lastPush = Date()
        lastState = state
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    // MARK: - Location

    private func beginLocation() {
        guard isOn else { return }
        let s = location.authorizationStatus
        guard s == .authorizedWhenInUse || s == .authorizedAlways else { return }
        location.desiredAccuracy = kCLLocationAccuracyHundredMeters
        location.distanceFilter = 200
        location.activityType = .fitness
        location.pausesLocationUpdatesAutomatically = false
        location.allowsBackgroundLocationUpdates = true
        location.showsBackgroundLocationIndicator = true
        location.startUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let s = manager.authorizationStatus
        if s == .denied || s == .restricted, isOn {
            message = "الموقع مقفل، فالتحديث بالخلفية ممكن يوقف. فعله من الإعدادات > دربك > الموقع."
        }
        beginLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {}

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    // MARK: - Live Activity

    private func startActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            message = "فعل «الأنشطة المباشرة» من الإعدادات > دربك عشان تطلع خطواتك على شاشة القفل."
            return
        }
        let h = HealthStore.shared
        let state = WalkActivityAttributes.ContentState(steps: h.todaySteps,
                                                         goal: AppSettings.shared.goal,
                                                         distanceKm: h.todayDistanceKm)
        do {
            activity = try Activity.request(attributes: WalkActivityAttributes(startedAt: Date()),
                                            content: ActivityContent(state: state, staleDate: nil),
                                            pushType: nil)
            lastState = state
            lastPush = Date()
        } catch {
            message = "ما قدرت أشغل العرض على شاشة القفل: \(error.localizedDescription)"
        }
    }
}
