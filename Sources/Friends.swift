// دربك — © 0xF8D
//
// منافسة الشلة (بدون سيرفر):
// كل واحد يرسل «كوده» (رابط فيه اسمه وخطواته هالأسبوع ومستواه) بالقروب.
// تنسخ الرسالة وتضغط «الصق كود صديق»، أو تفتح الرابط، ويطلع بالترتيب.
// الأرقام تتحدث كل ما صديقك يرسل كود جديد.

import SwiftUI
import UIKit

// MARK: - كود الصديق

struct FriendCard: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var emoji: String
    var week: Int        // بداية الأسبوع (unix)
    var days: [Int]      // خطوات الأحد → السبت
    var level: Int
    var updated: Int     // وقت إرسال الكود (unix)

    enum CodingKeys: String, CodingKey {
        case id = "i", name = "n", emoji = "e", week = "w", days = "d", level = "l", updated = "u"
    }

    static let linkPrefix = "darbak://f/"

    var total: Int { days.reduce(0, +) }
    var updatedAt: Date { Date(timeIntervalSince1970: TimeInterval(updated)) }

    var code: String {
        guard let data = try? JSONEncoder().encode(self) else { return "" }
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    var link: String { Self.linkPrefix + code }

    /// يدور على الكود داخل أي نص (رسالة واتساب كاملة، رابط، أو الكود بروحه)
    static func decode(_ text: String) -> FriendCard? {
        var candidates: [String] = []
        if let r = text.range(of: linkPrefix) {
            let rest = text[r.upperBound...]
            candidates.append(String(rest.prefix { !$0.isWhitespace && !$0.isNewline }))
        }
        candidates += text
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .map(String.init)
        for c in candidates {
            if let card = fromCode(c) { return card }
        }
        return nil
    }

    private static func fromCode(_ raw: String) -> FriendCard? {
        var b = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if b.hasPrefix(linkPrefix) { b.removeFirst(linkPrefix.count) }
        guard b.count >= 20, b.count < 4_000 else { return nil }
        b = b.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b.count % 4 != 0 { b += "=" }
        guard let data = Data(base64Encoded: b),
              var card = try? JSONDecoder().decode(FriendCard.self, from: data),
              card.days.count == 7, !card.id.isEmpty else { return nil }
        card.name = String(card.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24))
        if card.name.isEmpty { card.name = "صديق" }
        card.emoji = card.emoji.isEmpty ? "🙂" : String(card.emoji.prefix(1))
        card.days = card.days.map { min(max($0, 0), 150_000) }
        card.level = min(max(card.level, 1), 999)
        return card
    }
}

// MARK: - المخزن

final class FriendStore: ObservableObject {
    static let shared = FriendStore()

    static let emojis = ["⭐️", "🚀", "🦁", "🦅", "🐎", "👑", "🏃", "👧", "👦", "💪"]

    private let d = UserDefaults.standard
    private let friendsKey = "friends"

    @Published var name: String { didSet { d.set(name, forKey: "profileName") } }
    @Published var emoji: String { didSet { d.set(emoji, forKey: "profileEmoji") } }
    @Published private(set) var friends: [FriendCard] = []
    /// يزيد كل ما انضاف/تحدث صديق (عشان ننقلك لصفحة الشلة)
    @Published private(set) var importTick = 0
    @Published var toast: String?

    let myID: String

    init() {
        name = d.string(forKey: "profileName") ?? ""
        emoji = d.string(forKey: "profileEmoji") ?? "🦁"
        if let id = d.string(forKey: "profileID") {
            myID = id
        } else {
            let id = UUID().uuidString
            d.set(id, forKey: "profileID")
            myID = id
        }
        if let data = d.data(forKey: friendsKey),
           let list = try? JSONDecoder().decode([FriendCard].self, from: data) {
            friends = list
        }
    }

    var displayName: String {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "أنا" : String(n.prefix(24))
    }

    var weekStart: Date {
        AppCalendar.local.dateInterval(of: .weekOfYear, for: Date())?.start ?? AppCalendar.startOfToday()
    }

    func isCurrent(_ c: FriendCard) -> Bool {
        abs(c.week - Int(weekStart.timeIntervalSince1970)) < 12 * 3600
    }

    func myCard() -> FriendCard {
        let h = HealthStore.shared
        return FriendCard(id: myID,
                          name: displayName,
                          emoji: emoji,
                          week: Int(weekStart.timeIntervalSince1970),
                          days: h.week(offset: 0).map { $0.isFuture ? 0 : $0.steps },
                          level: h.progress.level.level,
                          updated: Int(Date().timeIntervalSince1970))
    }

    func shareText() -> String {
        let me = myCard()
        return """
        يا شباب تحدوني في دربك 👑
        \(me.emoji) \(me.name): \(Fmt.num(me.total)) خطوة هذا الأسبوع · مستوى \(Fmt.num(me.level))

        عشان تضيفني: انسخ الرسالة كاملة، وافتح دربك ← الشلة ← اضغط «لصق».
        \(me.link)
        """
    }

    func importText(_ text: String) {
        defer { importTick += 1 }
        guard let card = FriendCard.decode(text) else {
            show("ما لقيت كود صحيح. انسخ رسالة صديقك كاملة وجرب مرة ثانية.")
            return
        }
        if card.id == myID {
            show("هذا كودك أنت 😄")
            return
        }
        if let i = friends.firstIndex(where: { $0.id == card.id }) {
            if card.updated < friends[i].updated {
                show("عندك تحديث أجدد من \(friends[i].name)")
                return
            }
            friends[i] = card
            save()
            show("تحدثت خطوات \(card.emoji) \(card.name) ✓")
        } else {
            friends.append(card)
            save()
            show("انضاف \(card.emoji) \(card.name) للشلة 🎉")
        }
        Haptics.success()
    }

    func remove(_ id: String) {
        friends.removeAll { $0.id == id }
        save()
    }

    private func show(_ message: String) {
        toast = message
    }

    private func save() {
        if let data = try? JSONEncoder().encode(friends) {
            d.set(data, forKey: friendsKey)
        }
    }
}

// MARK: - الشاشة

struct FriendsView: View {
    @EnvironmentObject var friends: FriendStore
    @EnvironmentObject var health: HealthStore
    @State private var editingProfile = false
    @State private var manualCode = ""

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "ar_SA")
        f.unitsStyle = .short
        return f
    }()

    var body: some View {
        let me = friends.myCard()
        let current = friends.friends.filter { friends.isCurrent($0) }
        let stale = friends.friends.filter { !friends.isCurrent($0) }
        let board = ([me] + current).sorted { $0.total > $1.total }
        let leader = max(board.first?.total ?? 1, 1)

        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScreenTitle(title: "الشلة", subtitle: "نافس شلتك على خطوات الأسبوع")

                    if editingProfile || friends.name.trimmingCharacters(in: .whitespaces).isEmpty {
                        profileEditor
                    } else {
                        profileCard(me)
                    }

                    leaderboard(board, leader: leader)

                    actions

                    if !stale.isEmpty {
                        staleCard(stale)
                    }

                    howTo
                }
                .padding(.horizontal, 18)
                .screenWidth()
                .padding(.bottom, 30)
            }
        }
        .overlay(alignment: .top) { toastView }
        .animation(.easeInOut(duration: 0.25), value: friends.toast)
    }

    // MARK: - البروفايل

    private var profileEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("عرف بنفسك")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            InputField(title: "اسمك (يطلع لشلتك)", text: $friends.name, placeholder: "مثلا: أبو فهد")
            Text("اختار رمزك")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.text2)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: FriendStore.emojis.count), spacing: 4) {
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
            if editingProfile {
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

    private func profileCard(_ me: FriendCard) -> some View {
        HStack(spacing: 12) {
            Text(me.emoji)
                .font(.system(size: 36))
                .frame(width: 56, height: 56)
                .background(Color.white.opacity(0.06), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(me.name)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("⭐ مستوى \(Fmt.num(me.level)) · \(Rank.of(level: me.level).title)")
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

    // MARK: - الترتيب

    private func leaderboard(_ board: [FriendCard], leader: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("ترتيب هذا الأسبوع")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Text("من الأحد للسبت")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Palette.text3)
            }
            .padding(.bottom, 6)

            ForEach(Array(board.enumerated()), id: \.element.id) { i, c in
                row(c, place: i + 1, leader: leader, isMe: c.id == friends.myID,
                    king: i == 0 && board.count > 1 && c.total > 0)
                if i < board.count - 1 {
                    Divider().overlay(Color.white.opacity(0.08))
                }
            }

            if board.count == 1 {
                Text("لسه ما أضفت أحد. أرسل كودك لشلتك وخلهم يرسلون لك أكوادهم 👇")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Palette.text2)
                    .padding(.top, 8)
            } else {
                Text("اضغط مطول على صديق عشان تحذفه")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Palette.text3)
                    .padding(.top, 6)
            }
        }
        .padding(16)
        .glassCard(tint: Palette.gold)
    }

    private func medal(_ place: Int) -> String {
        switch place {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return Fmt.num(place)
        }
    }

    private func row(_ c: FriendCard, place: Int, leader: Int, isMe: Bool, king: Bool) -> some View {
        let frac = min(Double(c.total) / Double(max(leader, 1)), 1)
        let colors = isMe ? [Palette.cyan, Palette.blue] : Rank.of(level: c.level).colors
        return HStack(spacing: 10) {
            Text(medal(place))
                .font(.system(size: place <= 3 ? 22 : 15, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.text2)
                .frame(width: 30)
            Text(c.emoji)
                .font(.system(size: 26))
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(isMe ? "\(c.name) (أنت)" : c.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(isMe ? Palette.cyan : .white)
                        .lineLimit(1)
                    Text("⭐\(Fmt.num(c.level))")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.gold)
                }
                if king {
                    Text("ملك القروب 👑")
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
                if !isMe {
                    Text("حدث \(Self.relative.localizedString(for: c.updatedAt, relativeTo: Date()))")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Palette.text3)
                }
            }
            Text(Fmt.num(c.total))
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .contextMenu {
            if !isMe {
                Button(role: .destructive) {
                    friends.remove(c.id)
                } label: {
                    Label("احذف من الشلة", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - الأزرار

    private var actions: some View {
        VStack(spacing: 12) {
            ShareLink(item: friends.shareText()) {
                Label("أرسل كودي للقروب", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(NeonButtonStyle(colors: [Palette.violet, Palette.pink]))

            HStack(spacing: 10) {
                Text("نسخت كود صديق؟")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                PasteButton(payloadType: String.self) { strings in
                    let text = strings.joined(separator: "\n")
                    DispatchQueue.main.async { friends.importText(text) }
                }
                .buttonBorderShape(.capsule)
                .labelStyle(.titleAndIcon)
                .tint(Palette.cyan)
            }

            HStack(spacing: 8) {
                InputField(title: "أو الصق الكود هنا", text: $manualCode, placeholder: "darbak://f/…")
                Button {
                    hideKeyboard()
                    friends.importText(manualCode)
                    manualCode = ""
                } label: {
                    Text("أضف")
                }
                .buttonStyle(SoftButtonStyle(color: Palette.cyan))
                .disabled(manualCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.top, 22)
            }
        }
        .padding(16)
        .glassCard()
    }

    private func staleCard(_ list: [FriendCard]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ما حدثوا هذا الأسبوع")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("اطلب منهم يرسلون كودهم الجديد عشان يدخلون الترتيب.")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Palette.text2)
            ForEach(list) { c in
                HStack(spacing: 10) {
                    Text(c.emoji).font(.system(size: 22))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(c.name)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("آخر كود: \(Fmt.num(c.total)) خطوة · \(Self.relative.localizedString(for: c.updatedAt, relativeTo: Date()))")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Palette.text3)
                    }
                    Spacer()
                    Button {
                        Haptics.tap()
                        friends.remove(c.id)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(Palette.pink)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var howTo: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("كيف تشتغل؟", systemImage: "questionmark.circle")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("١. اضغط «أرسل كودي للقروب» وأرسله بالقروب.\n٢. لما يرسل صديقك كوده: انسخ رسالته وارجع هنا واضغط «لصق».\n٣. الترتيب يتحدث كل ما أحد يرسل كود جديد، فأرسلوا أكوادكم كل يوم أو آخر الأسبوع.")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Palette.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 18)
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
