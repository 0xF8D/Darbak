// دربك — © 0xF8D
//
// تذكير الخطوات. الإشعار يتجهز مسبقا، ونحدث نصه كل ما تتغير الخطوات
// (وأنت فاتح التطبيق، أو لما الصحة توقظ التطبيق بالخلفية).

import Foundation
import UserNotifications

enum Reminder {
    private static let todayID = "darbak.reminder.today"
    private static let tomorrowID = "darbak.reminder.tomorrow"

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func reschedule(steps: Int, goal: Int) {
        let s = AppSettings.shared
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [todayID, tomorrowID])
        guard s.reminderEnabled else { return }

        let cal = AppCalendar.local
        let now = Date()
        let todayStart = cal.startOfDay(for: now)

        if steps < goal,
           let fire = cal.date(bySettingHour: s.reminderHour, minute: s.reminderMinute, second: 0, of: todayStart),
           fire > now {
            add(id: todayID, at: fire,
                body: "باقيلك \(Fmt.num(goal - steps)) خطوة على هدفك يا وحش 💪")
        }

        if let tomorrow = cal.date(byAdding: .day, value: 1, to: todayStart),
           let fire = cal.date(bySettingHour: s.reminderHour, minute: s.reminderMinute, second: 0, of: tomorrow) {
            add(id: tomorrowID, at: fire,
                body: "لا تنسى هدفك اليوم \(Fmt.num(goal)) خطوة يا وحش 🔥 افتح دربك وشوف كم باقي لك")
        }
    }

    private static func add(id: String, at date: Date, body: String) {
        let interval = date.timeIntervalSinceNow
        guard interval > 1 else { return }
        let content = UNMutableNotificationContent()
        content.title = "دربك"
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
