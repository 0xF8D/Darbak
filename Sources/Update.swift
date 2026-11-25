// دربك — © 0xF8D
//
// يشيك على apps.json في GitHub (كل ٣ ساعات بالكثير)، ولو فيه نسخة أجدد
// يطلع شريط في الصفحة الرئيسية: «فيه تحديث جديد».

import SwiftUI

final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    static let sourceURL = URL(string: "https://raw.githubusercontent.com/0xF8D/Darbak/main/apps.json")!
    static let pageURL = URL(string: "https://github.com/0xF8D/Darbak/releases/latest")!

    @Published private(set) var latest: String?
    @Published var dismissed: String? {
        didSet { UserDefaults.standard.set(dismissed, forKey: "update.dismissed") }
    }

    private var lastCheck = Date.distantPast

    init() {
        dismissed = UserDefaults.standard.string(forKey: "update.dismissed")
    }

    var current: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// رقم النسخة الجديدة لو فيه (وما قفلت الشريط حقها)
    var available: String? {
        guard let latest, Self.isNewer(latest, than: current), latest != dismissed else { return nil }
        return latest
    }

    func check() {
        guard Date().timeIntervalSince(lastCheck) > 3 * 3600 else { return }
        lastCheck = Date()
        let req = URLRequest(url: Self.sourceURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data,
                  let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let apps = obj["apps"] as? [[String: Any]],
                  let versions = apps.first?["versions"] as? [[String: Any]],
                  let v = versions.first?["version"] as? String else { return }
            DispatchQueue.main.async { self.latest = v }
        }.resume()
    }

    static func isNewer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }
        let y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let p = i < x.count ? x[i] : 0
            let q = i < y.count ? y[i] : 0
            if p != q { return p > q }
        }
        return false
    }
}

struct UpdateBanner: View {
    @ObservedObject var updates = UpdateChecker.shared
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let v = updates.available {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Palette.cyan)
                VStack(alignment: .leading, spacing: 3) {
                    Text("فيه تحديث جديد v\(v)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("ثبته فوق القديم، وبياناتك ما تروح")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Palette.text2)
                }
                Spacer(minLength: 4)
                Button("حمله") {
                    openURL(UpdateChecker.pageURL)
                }
                .buttonStyle(SoftButtonStyle(color: Palette.cyan))
                Button {
                    updates.dismissed = v
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.text3)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .glassCard(radius: 18, tint: Palette.cyan)
        }
    }
}
