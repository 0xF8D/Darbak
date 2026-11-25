// دربك — © 0xF8D
//
// الشلة: مجموعات بكود من ٨ خانات.
// - تنشئ مجموعة ويطلع لك كود، تعطيه أخوياك ويدخلون، وكلكم تشوفون بعض.
// - اسمك وخطواتك يتحدثون كل دقيقة والتطبيق مفتوح (وبالخلفية لما iOS يسمح).
// - صاحب المجموعة بس يقدر يطلع أحد منها.
// السيرفر: Supabase (الدوال في supabase/schema.sql).

import SwiftUI
import UIKit

// MARK: - الاتصال بالسيرفر

enum Cloud {
    struct Failure: Error {
        let code: String
    }

    static var isConfigured: Bool {
        !CloudSecrets.url.isEmpty && !CloudSecrets.anonKey.isEmpty
    }

    static func call(_ fn: String, _ params: [String: Any]) async throws -> Data {
        try await call(fn, body: try JSONSerialization.data(withJSONObject: params))
    }

    static func call(_ fn: String, body: Data) async throws -> Data {
        var base = CloudSecrets.url
        while base.hasSuffix("/") { base.removeLast() }
        guard isConfigured, let url = URL(string: base + "/rest/v1/rpc/" + fn) else {
            throw Failure(code: "not_configured")
        }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(CloudSecrets.anonKey, forHTTPHeaderField: "apikey")
        if CloudSecrets.anonKey.hasPrefix("eyJ") {
            req.setValue("Bearer \(CloudSecrets.anonKey)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = body

        let result: (Data, URLResponse)
        do {
            result = try await URLSession.shared.data(for: req)
        } catch {
            throw Failure(code: "offline")
        }
        let (data, response) = result
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            throw Failure(code: (obj?["message"] as? String) ?? "http_\(status)")
        }
        return data
    }

    static func message(for error: Error) -> String {
        switch (error as? Failure)?.code ?? "" {
        case "offline": return "ما فيه اتصال بالإنترنت"
        case "not_found": return "الكود غلط، تأكد منه"
        case "banned": return "صاحب المجموعة طلعك منها"
        case "full": return "المجموعة مليانة (٥٠ شخص)"
        case "too_many": return "وصلت الحد: ١٠ مجموعات"
        case "name_required": return "اكتب اسمك أول"
        case "not_owner": return "صاحب المجموعة بس يقدر يطلع أحد"
        case "not_configured": return "المجموعات مو مفعلة في هذي النسخة"
        default: return "صار خطأ، جرب مرة ثانية"
        }
    }
}

// MARK: - البيانات

struct GroupMember: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let emoji: String
    let level: Int
    let week: String?
    let days: [Int]
    let updated: Double

    var updatedAt: Date { Date(timeIntervalSince1970: updated) }
}

struct CloudGroup: Codable, Identifiable, Equatable {
    let code: String
    let name: String
    let owner: String
    let members: [GroupMember]

    var id: String { code }
}

// MARK: - المخزن

final class FriendStore: ObservableObject {
    static let shared = FriendStore()

    static let emojis = ["⭐️", "🚀", "🦁", "🦅", "🐎", "👑", "🏃", "👧", "👦", "💪"]

    private let d = UserDefaults.standard
    private let groupsKey = "cloudGroups"

    @Published var name: String {
        didSet {
            d.set(name, forKey: "profileName")
            profileChanged()
        }
    }
    @Published var emoji: String {
        didSet {
            d.set(emoji, forKey: "profileEmoji")
            profileChanged()
        }
    }
    @Published private(set) var groups: [CloudGroup] = []
    @Published private(set) var busy = false
    @Published private(set) var offline = false
    @Published private(set) var lastSync: Date?
    /// يزيد لما تفتح رابط مجموعة (عشان ننقلك لصفحة الشلة)
    @Published private(set) var importTick = 0
    @Published var pendingCode = ""
    @Published var toast: String?

    let myID: String
    private let secret: String
    private var timer: Timer?
    private var syncing = false
    private var dirty = true
    private var lastPush = Date.distantPast
    private var nameWork: DispatchWorkItem?
    private var bgTask: UIBackgroundTaskIdentifier = .invalid

    init() {
        name = d.string(forKey: "profileName") ?? ""
        emoji = d.string(forKey: "profileEmoji") ?? "🦁"
        if let id = d.string(forKey: "profileID"), UUID(uuidString: id) != nil {
            myID = id.lowercased()
        } else {
            let id = UUID().uuidString.lowercased()
            d.set(id, forKey: "profileID")
            myID = id
        }
        if let s = d.string(forKey: "profileSecret"), s.count >= 16 {
            secret = s
        } else {
            let s = (UUID().uuidString + UUID().uuidString).replacingOccurrences(of: "-", with: "")
            d.set(s, forKey: "profileSecret")
            secret = s
        }
        if let data = d.data(forKey: groupsKey),
           let list = try? JSONDecoder().decode([CloudGroup].self, from: data) {
            groups = list
        }
    }

    var trimmedName: String {
        String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24))
    }

    var hasName: Bool { !trimmedName.isEmpty }

    func isOwner(_ g: CloudGroup) -> Bool { g.owner.lowercased() == myID }

    func isMe(_ m: GroupMember) -> Bool { m.id.lowercased() == myID }

    /// بداية الأسبوع (الأحد) بصيغة 2026-11-22
    static var weekKey: String {
        let start = AppCalendar.local.dateInterval(of: .weekOfYear, for: Date())?.start ?? AppCalendar.startOfToday()
        return keyFormatter.string(from: start)
    }

    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .autoupdatingCurrent
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: التحديث كل دقيقة

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { await self?.sync() }
        }
        Task { await sync(force: true) }
    }

    /// يرسل خطواتك واسمك، ويجيب آخر أرقام الشلة
    func sync(force: Bool = false) async {
        guard Cloud.isConfigured else { return }
        let plan: (Bool, Data)? = await MainActor.run {
            guard self.hasName, !self.syncing else { return nil }
            self.syncing = true
            let push = force || self.dirty || Date().timeIntervalSince(self.lastPush) > 50
            return (push, self.profilePayload())
        }
        guard let plan else { return }
        do {
            if plan.0 {
                _ = try await Cloud.call("darbak_save_profile", body: plan.1)
                await MainActor.run {
                    self.lastPush = Date()
                    self.dirty = false
                }
            }
            try await refreshGroups()
        } catch {
            let isOffline = (error as? Cloud.Failure)?.code == "offline"
            await MainActor.run { self.offline = isOffline }
        }
        await MainActor.run { self.syncing = false }
    }

    /// التطبيق انقفل: نرسل آخر خطواتك قبل ما iOS يوقفه (ياخذ ثواني)
    func syncOnClose() {
        guard Cloud.isConfigured, hasName else { return }
        endBackgroundTask()
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "darbak.sync") { [weak self] in
            self?.endBackgroundTask()
        }
        Task {
            await self.sync(force: true)
            await MainActor.run { self.endBackgroundTask() }
        }
    }

    private func endBackgroundTask() {
        guard bgTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(bgTask)
        bgTask = .invalid
    }

    private func refreshGroups() async throws {
        let data = try await Cloud.call("darbak_my_groups", auth())
        let list = try JSONDecoder().decode([CloudGroup].self, from: data)
        await MainActor.run {
            if list != self.groups {
                self.groups = list
                if let encoded = try? JSONEncoder().encode(list) {
                    self.d.set(encoded, forKey: self.groupsKey)
                }
            }
            self.offline = false
            self.lastSync = Date()
        }
    }

    private func auth() -> [String: Any] {
        ["p_id": myID, "p_secret": secret]
    }

    /// بياناتك جاهزة للإرسال (JSON)
    private func profilePayload() -> Data {
        let h = HealthStore.shared
        let params: [String: Any] = [
            "p_id": myID,
            "p_secret": secret,
            "p_name": trimmedName,
            "p_emoji": emoji,
            "p_level": h.progress.level.level,
            "p_week_start": Self.weekKey,
            "p_days": h.week(offset: 0).map { $0.isFuture ? 0 : $0.steps }
        ]
        return (try? JSONSerialization.data(withJSONObject: params)) ?? Data()
    }

    /// غيرت اسمك أو رمزك: نرسله بعد ثانية ونص (عشان ما نرسل مع كل حرف)
    private func profileChanged() {
        dirty = true
        nameWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { await self?.sync(force: true) }
        }
        nameWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    // MARK: إنشاء ودخول وخروج

    @discardableResult
    func createGroup(named groupName: String) async -> Bool {
        await run {
            let params = self.auth().merging(["p_name": groupName]) { _, new in new }
            let data = try await Cloud.call("darbak_create_group", params)
            let code = ((try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)) as? String) ?? ""
            try await self.refreshGroups()
            return "انشأت المجموعة، الكود: \(code)"
        }
    }

    @discardableResult
    func joinGroup(code raw: String) async -> Bool {
        let code = String(raw.uppercased().filter { $0.isLetter || $0.isNumber })
        guard code.count == 8 else {
            await show("الكود ٨ خانات (حروف وأرقام)")
            return false
        }
        return await run {
            let params = self.auth().merging(["p_code": code]) { _, new in new }
            let data = try await Cloud.call("darbak_join_group", params)
            let groupName = ((try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)) as? String) ?? ""
            try await self.refreshGroups()
            await MainActor.run { self.pendingCode = "" }
            return "دخلت «\(groupName)» 🎉"
        }
    }

    func leave(_ g: CloudGroup) async {
        let owner = isOwner(g)
        await run {
            let params = self.auth().merging(["p_code": g.code]) { _, new in new }
            _ = try await Cloud.call("darbak_leave_group", params)
            try await self.refreshGroups()
            return owner ? "انحذفت المجموعة" : "طلعت من «\(g.name)»"
        }
    }

    func kick(_ member: GroupMember, from g: CloudGroup) async {
        await run {
            let params = self.auth().merging(["p_code": g.code, "p_member": member.id]) { _, new in new }
            _ = try await Cloud.call("darbak_kick", params)
            try await self.refreshGroups()
            return "طلعت \(member.name) من المجموعة"
        }
    }

    /// يرسل حسابك أول (لازم قبل أي مجموعة)، بعدين ينفذ الطلب
    @discardableResult
    private func run(_ action: @escaping () async throws -> String) async -> Bool {
        let payload: Data? = await MainActor.run {
            guard self.hasName else { return nil }
            self.busy = true
            return self.profilePayload()
        }
        guard let payload else {
            await show(Cloud.message(for: Cloud.Failure(code: "name_required")))
            return false
        }
        var ok = false
        do {
            _ = try await Cloud.call("darbak_save_profile", body: payload)
            await MainActor.run {
                self.lastPush = Date()
                self.dirty = false
            }
            let message = try await action()
            await show(message)
            ok = true
        } catch {
            await show(Cloud.message(for: error))
        }
        await MainActor.run { self.busy = false }
        if ok { await MainActor.run { Haptics.success() } }
        return ok
    }

    private func show(_ message: String) async {
        await MainActor.run { self.toast = message }
    }

    // MARK: روابط الدعوة: darbak://join/ABCD1234

    func handleURL(_ url: URL) {
        guard url.scheme == "darbak", url.host == "join" else { return }
        let code = url.lastPathComponent.uppercased().filter { $0.isLetter || $0.isNumber }
        guard code.count == 8 else { return }
        pendingCode = String(code)
        importTick += 1
        if hasName {
            Task { await joinGroup(code: String(code)) }
        }
    }

    static func inviteText(_ g: CloudGroup) -> String {
        """
        يا شباب تحدوني في دربك 👑
        ادخلوا مجموعتي «\(g.name)» بالكود: \(g.code)

        darbak://join/\(g.code)
        """
    }
}

// MARK: - الشاشة

struct FriendsView: View {
    @EnvironmentObject var friends: FriendStore
    @EnvironmentObject var health: HealthStore
    @State private var editingProfile = false
    @State private var newGroupName = ""
    @State private var leaveTarget: CloudGroup?
    @State private var kickTarget: KickTarget?
    @State private var weekMember: WeekSheet?

    struct WeekSheet: Identifiable {
        let id: String
        let name: String
        let emoji: String
        let days: [Int]
    }

    struct KickTarget {
        let member: GroupMember
        let group: CloudGroup
    }

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "ar_SA")
        f.unitsStyle = .short
        return f
    }()

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScreenTitle(title: "الشلة", subtitle: "نافس شلتك على خطوات اليوم")

                    if !Cloud.isConfigured {
                        notice("المجموعات مو مفعلة في هذي النسخة.")
                    } else {
                        if editingProfile || !friends.hasName {
                            profileEditor
                        } else {
                            profileCard
                        }

                        ForEach(friends.groups) { g in
                            groupCard(g)
                        }

                        joinCreateCard

                        if friends.offline {
                            notice("ما فيه اتصال بالإنترنت. الأرقام تتحدث أول ما يرجع.")
                        }
                    }
                }
                .padding(.horizontal, 18)
                .screenWidth()
                .padding(.bottom, 30)
            }
            .refreshable { await friends.sync(force: true) }
        }
        .overlay(alignment: .top) { toastView }
        .animation(.easeInOut(duration: 0.25), value: friends.toast)
        .confirmationDialog(leaveTarget.map { friends.isOwner($0) ? "تحذف المجموعة لكل الأعضاء؟" : "تطلع من المجموعة؟" } ?? "",
                            isPresented: Binding(get: { leaveTarget != nil }, set: { if !$0 { leaveTarget = nil } }),
                            titleVisibility: .visible,
                            presenting: leaveTarget) { g in
            Button(friends.isOwner(g) ? "احذف المجموعة" : "اطلع", role: .destructive) {
                Task { await friends.leave(g) }
            }
            Button("إلغاء", role: .cancel) {}
        }
        .sheet(item: $weekMember) { m in
            MemberWeekView(name: m.name, emoji: m.emoji, days: m.days)
                .appEnvironment()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog(kickTarget.map { "تطلع \($0.member.name) من المجموعة؟" } ?? "",
                            isPresented: Binding(get: { kickTarget != nil }, set: { if !$0 { kickTarget = nil } }),
                            titleVisibility: .visible,
                            presenting: kickTarget) { t in
            Button("طلعه", role: .destructive) {
                Task { await friends.kick(t.member, from: t.group) }
            }
            Button("إلغاء", role: .cancel) {}
        }
    }

    // MARK: - البروفايل

    private var profileEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("عرف بنفسك")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            InputField(title: "اسمك (يطلع لشلتك)", text: $friends.name, placeholder: "مثلا: أبو فهد")
            if !friends.hasName {
                Text("لازم تكتب اسمك عشان تنشئ مجموعة أو تدخل وحدة")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Palette.orange)
            }
            Text("اختار رمزك")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.text2)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: FriendStore.emojis.count), spacing: 4) {
                ForEach(FriendStore.emojis, id: \.self) { e in
                    Button {
                        Haptics.tap()
                        friends.emoji = e
                    } label: {
                        Text(e)
                            .font(.system(size: 22))
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .background(Color.white.opacity(friends.emoji == e ? 0.16 : 0.04),
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(friends.emoji == e ? Palette.cyan : .clear, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            if editingProfile && friends.hasName {
                Button("تم") {
                    hideKeyboard()
                    editingProfile = false
                }
                .buttonStyle(SoftButtonStyle(color: Palette.cyan))
            }
        }
        .padding(16)
        .glassCard()
    }

    private var profileCard: some View {
        let level = health.progress.level.level
        return HStack(spacing: 12) {
            Text(friends.emoji)
                .font(.system(size: 36))
                .frame(width: 56, height: 56)
                .background(Color.white.opacity(0.06), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(friends.trimmedName)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("مستوى \(Fmt.num(level)) · \(Rank.of(level: level).title)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.gold)
            }
            Spacer(minLength: 0)
            Button {
                editingProfile = true
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.07), in: Circle())
            }
        }
        .padding(14)
        .glassCard()
    }

    // MARK: - المجموعة

    private struct Row: Identifiable {
        let member: GroupMember
        let name: String
        let emoji: String
        let level: Int
        let total: Int      // خطوات اليوم
        let days: [Int]     // الأسبوع كامل (الأحد ← السبت)
        let isMe: Bool
        let current: Bool
        var id: String { member.id }
    }

    /// ترتيب اليوم في مصفوفة الأسبوع (الأحد = ٠)
    private var todayIndex: Int {
        let cal = AppCalendar.local
        let start = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? AppCalendar.startOfToday()
        let n = cal.dateComponents([.day], from: start, to: AppCalendar.startOfToday()).day ?? 0
        return min(max(n, 0), 6)
    }

    private func rows(for g: CloudGroup) -> [Row] {
        let week = FriendStore.weekKey
        let myDays = health.week(offset: 0).map { $0.isFuture ? 0 : $0.steps }
        let t = todayIndex
        return g.members.map { m in
            let me = friends.isMe(m)
            let current = me || m.week == week
            let days = me ? myDays : (current ? m.days : Array(repeating: 0, count: 7))
            let total = t < days.count ? days[t] : 0
            return Row(member: m,
                       name: me ? friends.trimmedName : m.name,
                       emoji: me ? friends.emoji : m.emoji,
                       level: me ? health.progress.level.level : m.level,
                       total: total,
                       days: days,
                       isMe: me,
                       current: current)
        }
        .sorted { $0.total > $1.total }
    }

    private func groupCard(_ g: CloudGroup) -> some View {
        let list = rows(for: g)
        let leader = max(list.first?.total ?? 1, 1)
        let owner = friends.isOwner(g)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(g.name)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if owner {
                    Text("المسؤول")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.gold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Palette.gold.opacity(0.14), in: Capsule())
                }
                Spacer()
                Text("\(Fmt.num(g.members.count)) أعضاء")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Palette.text3)
            }

            codeRow(g)
                .padding(.bottom, 4)

            Text("ترتيب اليوم · اضغط على أي واحد تشوف أسبوعه")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.text2)

            ForEach(Array(list.enumerated()), id: \.element.id) { i, r in
                row(r, place: i + 1, leader: leader,
                    king: i == 0 && list.count > 1 && r.total > 0,
                    canKick: owner && !r.isMe, group: g)
                if i < list.count - 1 {
                    Divider().overlay(Color.white.opacity(0.08))
                }
            }

            if list.count == 1 {
                Text("باقي ما دخل أحد. أرسل الكود لشلتك 👆")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Palette.text2)
                    .padding(.top, 4)
            }

            HStack {
                Text(syncText)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Palette.text3)
                Spacer()
                Button(owner ? "احذف المجموعة" : "اطلع من المجموعة") {
                    leaveTarget = g
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.pink)
            }
            .padding(.top, 6)
        }
        .padding(16)
        .glassCard(tint: Palette.gold)
    }

    private var syncText: String {
        guard let last = friends.lastSync else { return "يتحدث كل دقيقة" }
        return "يتحدث كل دقيقة · آخر تحديث \(Self.relative.localizedString(for: last, relativeTo: Date()))"
    }

    private func codeRow(_ g: CloudGroup) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("كود المجموعة")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Palette.text3)
                Text(g.code)
                    .font(.system(size: 22, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Palette.cyan)
                    .tracking(2)
                    .environment(\.layoutDirection, .leftToRight)
            }
            Spacer()
            Button {
                UIPasteboard.general.string = g.code
                Haptics.tap()
                friends.toast = "نسخت الكود ✓"
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.07), in: Circle())
            }
            .foregroundStyle(.white)
            ShareLink(item: FriendStore.inviteText(g)) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .background(LinearGradient(colors: [Palette.violet, Palette.pink],
                                                startPoint: .leading, endPoint: .trailing),
                                in: Circle())
            }
            .foregroundStyle(.white)
        }
        .padding(12)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func medal(_ place: Int) -> String {
        switch place {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return Fmt.num(place)
        }
    }

    private func row(_ r: Row, place: Int, leader: Int, king: Bool, canKick: Bool, group: CloudGroup) -> some View {
        let frac = min(Double(r.total) / Double(max(leader, 1)), 1)
        let colors = r.isMe ? [Palette.cyan, Palette.blue] : Rank.of(level: r.level).colors
        return HStack(spacing: 10) {
            Text(medal(place))
                .font(.system(size: place <= 3 ? 22 : 15, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.text2)
                .frame(width: 30)
            Text(r.emoji)
                .font(.system(size: 26))
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(r.isMe ? "\(r.name) (أنت)" : r.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(r.isMe ? Palette.cyan : .white)
                        .lineLimit(1)
                    Text("مستوى \(Fmt.num(r.level))")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.gold)
                }
                if king {
                    Text("ملك اليوم 👑")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(Palette.gold)
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(g.size.width * frac, 4))
                    }
                }
                .frame(height: 6)
                if !r.isMe {
                    Text(r.current
                         ? "حدث \(Self.relative.localizedString(for: r.member.updatedAt, relativeTo: Date()))"
                         : "ما فتح دربك اليوم")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Palette.text3)
                }
            }
            Text(Fmt.num(r.total))
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if canKick {
                Menu {
                    Button(role: .destructive) {
                        kickTarget = KickTarget(member: r.member, group: group)
                    } label: {
                        Label("طلعه من المجموعة", systemImage: "person.fill.xmark")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Palette.text2)
                        .frame(width: 26, height: 30)
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.tap()
            weekMember = WeekSheet(id: r.id, name: r.name, emoji: r.emoji, days: r.days)
        }
    }

    // MARK: - إنشاء ودخول

    private var joinCreateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(friends.groups.isEmpty ? "ابدأ مع شلتك" : "مجموعة ثانية؟")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            HStack(alignment: .bottom, spacing: 8) {
                InputField(title: "عندك كود؟", text: $friends.pendingCode, placeholder: "ABCD1234")
                Button("ادخل") {
                    hideKeyboard()
                    Task { await friends.joinGroup(code: friends.pendingCode) }
                }
                .buttonStyle(SoftButtonStyle(color: Palette.cyan))
                .padding(.bottom, 6)
            }

            HStack {
                Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                Text("أو")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Palette.text3)
                Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
            }

            HStack(alignment: .bottom, spacing: 8) {
                InputField(title: "أنشئ مجموعة جديدة", text: $newGroupName, placeholder: "اسم المجموعة (مثلا: شلة المشي)")
                Button("أنشئ") {
                    hideKeyboard()
                    Task {
                        if await friends.createGroup(named: newGroupName) {
                            newGroupName = ""
                        }
                    }
                }
                .buttonStyle(SoftButtonStyle(color: Palette.pink))
                .padding(.bottom, 6)
            }

            if friends.busy {
                ProgressView().tint(.white)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .glassCard()
        .disabled(!friends.hasName || friends.busy)
        .opacity(friends.hasName ? 1 : 0.5)
    }

    private func notice(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.8))
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(radius: 18, tint: Palette.orange)
    }

    @ViewBuilder
    private var toastView: some View {
        if let t = friends.toast {
            Text(t)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Palette.card.opacity(0.95), in: Capsule())
                .overlay(Capsule().strokeBorder(Palette.cyan.opacity(0.5), lineWidth: 1))
                .shadow(color: Palette.cyan.opacity(0.3), radius: 10)
                .padding(.top, 8)
                .padding(.horizontal, 20)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onTapGesture { friends.toast = nil }
                .task(id: t) {
                    try? await Task.sleep(nanoseconds: 2_800_000_000)
                    if friends.toast == t { friends.toast = nil }
                }
        }
    }
}

// MARK: - أسبوع الشخص (لما تضغط عليه)

struct MemberWeekView: View {
    let name: String
    let emoji: String
    let days: [Int]
    @EnvironmentObject var health: HealthStore
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        let dates = health.week(offset: 0)
        let top = max(days.max() ?? 0, settings.goal, 1)
        ZStack {
            AppBackground()
            VStack(spacing: 14) {
                Text(emoji)
                    .font(.system(size: 44))
                    .padding(.top, 28)
                Text(name)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("مجموع الأسبوع \(Fmt.num(days.reduce(0, +))) خطوة")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.text2)

                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(0..<7, id: \.self) { i in
                        let v = i < days.count ? days[i] : 0
                        let future = i < dates.count ? dates[i].isFuture : false
                        let colors = BadgeTier.highest(for: v)?.colors ?? [Palette.cyan, Palette.blue]
                        VStack(spacing: 6) {
                            Text(future ? "–" : Fmt.thousands(v))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            Capsule()
                                .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
                                .frame(height: max(6, 120 * CGFloat(v) / CGFloat(top)))
                            Text(i < dates.count ? Fmt.weekday(dates[i].date) : "")
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(Palette.text2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .frame(maxWidth: .infinity)
                        .opacity(future ? 0.3 : 1)
                    }
                }
                .frame(height: 170, alignment: .bottom)
                .padding(16)
                .glassCard()

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .screenWidth()
        }
    }
}
