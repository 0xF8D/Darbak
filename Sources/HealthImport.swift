// دربك — © 0xF8D
//
// ١) أرشيف الخطوات: كل يوم يمر ينحفظ في الجوال، عشان اللي الصحة مقفلة عنده
//    ما تضيع أيامه بعد ٧ أيام (عداد الجوال يحفظ أسبوع بس).
// ٢) استيراد سجل الصحة: تصدّر بياناتك من تطبيق الصحة (export.xml) وتختاره هنا،
//    فتنحسب كل أيامك القديمة حتى لو التطبيق ما يقدر يقرأ من الصحة مباشرة.

import Foundation

enum StepArchive {
    private static let key = "stepArchive"

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .autoupdatingCurrent
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayKey(_ d: Date) -> String { formatter.string(from: d) }

    static func date(from key: String) -> Date? {
        guard let d = formatter.date(from: key) else { return nil }
        return AppCalendar.local.startOfDay(for: d)
    }

    static func load() -> [Date: Int] {
        guard let raw = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] else { return [:] }
        var out: [Date: Int] = [:]
        for (k, v) in raw {
            if let d = date(from: k), v > 0 { out[d] = v }
        }
        return out
    }

    static func save(_ days: [Date: Int]) {
        var raw: [String: Int] = [:]
        for (d, v) in days where v > 0 { raw[dayKey(d)] = v }
        UserDefaults.standard.set(raw, forKey: key)
    }
}

/// يقرأ export.xml من تطبيق الصحة ويطلع مجموع الخطوات لكل يوم.
/// الجوال والساعة يسجلون نفس المشي، فناخذ أكبر مصدر لكل يوم (قريب جدا من رقم الصحة).
final class HealthExportParser: NSObject, XMLParserDelegate {
    private var perDay: [String: [String: Double]] = [:]
    private(set) var records = 0

    func parse(url: URL) -> [Date: Int]? {
        guard let parser = XMLParser(contentsOf: url) else { return nil }
        parser.delegate = self
        parser.shouldResolveExternalEntities = false
        let ok = parser.parse()
        guard ok || records > 0 else { return nil }
        var out: [Date: Int] = [:]
        for (day, sources) in perDay {
            guard let d = StepArchive.date(from: day) else { continue }
            let v = Int((sources.values.max() ?? 0).rounded())
            if v > 0 { out[d] = min(v, 150_000) }
        }
        return out
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        guard elementName == "Record",
              attributeDict["type"] == "HKQuantityTypeIdentifierStepCount",
              let start = attributeDict["startDate"], start.count >= 10,
              let value = Double(attributeDict["value"] ?? "") else { return }
        let day = String(start.prefix(10))
        let source = attributeDict["sourceName"] ?? "?"
        perDay[day, default: [:]][source, default: 0] += value
        records += 1
    }
}
