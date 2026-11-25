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

// MARK: - إعدادات من الأدمن: تحديث إجباري ورسالة للكل

final class RemoteConfig: ObservableObject {
    static let shared = RemoteConfig()

    struct Announcement: Decodable, Equatable {
        let id: Int
        let title: String
        let body: String
    }

    private struct Payload: Decodable {
        let minVersion: String?
        let updateMessage: String?
        let announcement: Announcement?
    }

    @Published private(set) var minVersion: String?
    @Published private(set) var updateMessage: String?
    @Published private(set) var announcement: Announcement?
    @Published var dismissedAnnouncement: Int {
        didSet { UserDefaults.standard.set(dismissedAnnouncement, forKey: "announcement.dismissed") }
    }

    private var lastFetch = Date.distantPast

    init() {
        dismissedAnnouncement = UserDefaults.standard.integer(forKey: "announcement.dismissed")
    }

    func refresh(force: Bool = false) {
        guard Cloud.isConfigured else { return }
        guard force || Date().timeIntervalSince(lastFetch) > 5 * 60 else { return }
        lastFetch = Date()
        Task {
            guard let data = try? await Cloud.call("darbak_config_public", [:]),
                  let p = try? JSONDecoder().decode(Payload.self, from: data) else { return }
            await MainActor.run {
                self.minVersion = p.minVersion
                self.updateMessage = p.updateMessage
                self.announcement = p.announcement
            }
        }
    }

    /// نسختك أقدم من المطلوب؟
    var mustUpdate: Bool {
        guard let m = minVersion, !m.isEmpty else { return false }
        return UpdateChecker.isNewer(m, than: UpdateChecker.shared.current)
    }

    var visibleAnnouncement: Announcement? {
        guard let a = announcement, a.id != dismissedAnnouncement else { return nil }
        return a
    }
}

/// شاشة «لازم تحدث» (تغطي التطبيق كامل). الأدمن ما تقفل عليه عشان يقدر يلغيها.
struct ForceUpdateGate: View {
    @ObservedObject var config = RemoteConfig.shared
    @ObservedObject var friends = FriendStore.shared
    @Environment(\.openURL) private var openURL

    var body: some View {
        if config.mustUpdate && !friends.isAdmin {
            ZStack {
                AppBackground()
                VStack(spacing: 18) {
                    Image(systemName: "arrow.down.app.fill")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [Palette.cyan, Palette.blue],
                                                        startPoint: .top, endPoint: .bottom))
                        .shadow(color: Palette.cyan.opacity(0.6), radius: 16)
                    Text("لازم تحدث دربك")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(config.updateMessage ?? "فيه نسخة جديدة لازم تثبتها عشان تكمل.")
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(Palette.text2)
                        .multilineTextAlignment(.center)
                    Text("نسختك \(UpdateChecker.shared.current) · المطلوب \(config.minVersion ?? "") أو أحدث")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Palette.text3)
                    Button {
                        openURL(UpdateChecker.pageURL)
                    } label: {
                        Label("حمل التحديث", systemImage: "arrow.down.circle.fill")
                    }
                    .buttonStyle(NeonButtonStyle())
                    .padding(.top, 6)
                    Text("ثبته فوق القديم، وبياناتك ما تروح")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Palette.text3)
                }
                .padding(32)
                .screenWidth()
            }
            .transition(.opacity)
        }
    }
}

/// رسالة الأدمن للكل (تطلع في الصفحة الرئيسية لين تقفلها)
struct AnnouncementBanner: View {
    @ObservedObject var config = RemoteConfig.shared

    var body: some View {
        if let a = config.visibleAnnouncement {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "megaphone.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Palette.gold)
                VStack(alignment: .leading, spacing: 4) {
                    Text(a.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    if !a.body.isEmpty {
                        Text(a.body)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(Palette.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 4)
                Button {
                    config.dismissedAnnouncement = a.id
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.text3)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(radius: 18, tint: Palette.gold)
        }
    }
}
