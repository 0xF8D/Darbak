// دربك — © 0xF8D
//
// الإشعارات بأوقات ثابتة (بتوقيت جوال الشخص):
//   ٨:٣٠ الصبح  — صباح الخير وهدف اليوم
//   ١:٠٠ الظهر  — لو أقل من نص الهدف
//   ٨:٠٠ الليل  — لو ما وصل الهدف
//   ١٠:٣٠ الليل — لو قريب من الهدف (باقي أقل من ٢٠٠٠)
// تتجهز مسبقًا، ونحدث أرقامها كل ما تتغير الخطوات (والتطبيق مفتوح أو بالخلفية).
// وصلت هدفك؟ ما يجيك تذكير خطوات باقي اليوم.

import Foundation
import UserNotifications

enum Reminder {
    private struct Slot {
        let id: String
        let hour: Int
        let minute: Int
    }

    private static let morning = Slot(id: "darbak.morning", hour: 8, minute: 30)
    private static let noon = Slot(id: "darbak.noon", hour: 13, minute: 0)
    private static let evening = Slot(id: "darbak.evening", hour: 20, minute: 0)
    private static let lastCall = Slot(id: "darbak.lastcall", hour: 22, minute: 30)
    private static let slots = [morning, noon, evening, lastCall]

    /// الإشعارات القديمة (قبل v2.7) نشيلها
    private static let legacyIDs = ["darbak.reminder.today", "darbak.reminder.tomorrow"]

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func reschedule(steps: Int, goal: Int) {
        let center = UNUserNotificationCenter.current()
        var ids = legacyIDs
        for s in slots {
            ids.append(s.id + ".today")
            ids.append(s.id + ".tomorrow")
        }
        center.removePendingNotificationRequests(withIdentifiers: ids)

        let cal = AppCalendar.local
        let now = Date()
        let today = cal.startOfDay(for: now)
        let remaining = max(goal - steps, 0)
        let goalText = Progression.k(goal)

        // اليوم: بالأرقام الحالية
        add(morning, on: today, tag: "today",
            body: "صباح الخير! هدفك اليوم \(goalText) خطوة، لا تنساه 🔥")
        if steps < goal / 2 {
            add(noon, on: today, tag: "today",
                body: "نص اليوم راح وأنت على \(Fmt.num(steps)) خطوة، قم تمشى شوي 🚶")
        }
        if remaining > 0 {
            add(evening, on: today, tag: "today",
                body: "باقيلك \(Fmt.num(remaining)) خطوة على هدفك يا وحش 💪")
        }
        if remaining > 0 && remaining < 2_000 {
            add(lastCall, on: today, tag: "today",
                body: "آخر فرصة! باقيلك \(Fmt.num(remaining)) خطوة وينقفل اليوم ⏳")
        }

        // بكرة: احتياط لو ما انفتح التطبيق (بدون أرقام)
        if let tomorrow = cal.date(byAdding: .day, value: 1, to: today) {
            add(morning, on: tomorrow, tag: "tomorrow",
                body: "صباح الخير! هدفك اليوم \(goalText) خطوة، لا تنساه 🔥")
            add(evening, on: tomorrow, tag: "tomorrow",
                body: "لا تنسى هدفك اليوم \(goalText) خطوة يا وحش 💪 افتح دربك وشوف كم باقي لك")
        }
    }

    private static func add(_ slot: Slot, on day: Date, tag: String, body: String) {
        guard let fire = AppCalendar.local.date(bySettingHour: slot.hour, minute: slot.minute, second: 0, of: day) else { return }
        let interval = fire.timeIntervalSinceNow
        guard interval > 1 else { return }
        let content = UNMutableNotificationContent()
        content.title = "دربك"
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: slot.id + "." + tag, content: content, trigger: trigger))
    }
}
