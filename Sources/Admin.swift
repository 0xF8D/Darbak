// دربك — © 0xF8D
//
// لوحة الأدمن: تطلع بس للي رقمه في جدول darbak_admins في Supabase.
// السيرفر يتأكد من كل أمر (رقمك + سر جهازك)، فحتى لو أحد فتح الشاشة ما يقدر يسوي شي.

import SwiftUI
import UIKit

struct AdminStats: Decodable {
    struct Version: Decodable, Identifiable {
        let version: String
        let count: Int
        var id: String { version }
    }

    struct User: Decodable, Identifiable {
        let id: String
        let name: String
        let emoji: String
        let level: Int
        let version: String
        let updated: Double
        let groups: Int
        let weekSteps: Int
        let admin: Bool
    }

    struct Group: Decodable, Identifiable {
        let code: String
        let name: String
        let owner: String
        let members: Int
        let created: Double
        var id: String { code }
    }

    struct Config: Decodable {
        let minVersion: String?
        let updateMessage: String?
        let title: String?
        let body: String?
        let active: Bool
        let announcementId: Int
    }

    let users: Int
    let activeDay: Int
    let activeWeek: Int
    let newWeek: Int
    let groups: Int
    let memberships: Int
    let weekSteps: Int
    let versions: [Version]
    let users_list: [User]
    let groups_list: [Group]
    let config: Config
}

struct AdminView: View {
    @EnvironmentObject var friends: FriendStore
    @ObservedObject var updates = UpdateChecker.shared
    @Environment(\.dismiss) private var dismiss

    @State private var stats: AdminStats?
    @State private var loading = false
    @State private var error: String?
    @State private var filled = false
    @State private var tab = 0
    @State private var search = ""

    @State private var minVersion = ""
    @State private var updateMessage = ""
    @State private var annTitle = ""
    @State private var annBody = ""
    @State private var annActive = false

    @State private var deleteGroup: AdminStats.Group?
    @State private var deleteUser: AdminStats.User?
    @State private var toast: String?

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "ar_SA")
        f.unitsStyle = .short
        return f
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("", selection: $tab) {
                            Text("نظرة عامة").tag(0)
                            Text("التحكم").tag(1)
                            Text("الناس").tag(2)
                            Text("المجموعات").tag(3)
                        }
                        .pickerStyle(.segmented)

                        if let error {
                            notice(error)
                        }

                        if let s = stats {
                            switch tab {
                            case 0: overview(s)
                            case 1:
                                updateCard(s)
                                announceCard
                            case 2: usersList(s)
                            default: groupsList(s)
                            }
                        } else if loading {
                            ProgressView().tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        }
                    }
                    .padding(.horizontal, 18)
                    .screenWidth()
                    .padding(.vertical, 12)
                }
                .refreshable { await load() }
            }
            .navigationTitle("لوحة الأدمن")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("تم") { dismiss() }
                        .fontWeight(.bold)
                }
            }
        }
        .task { await load() }
        .overlay(alignment: .top) { toastView }
        .animation(.easeInOut(duration: 0.25), value: toast)
        .confirmationDialog(deleteGroup.map { "تحذف مجموعة «\($0.name)» لكل أعضائها؟" } ?? "",
                            isPresented: Binding(get: { deleteGroup != nil }, set: { if !$0 { deleteGroup = nil } }),
                            titleVisibility: .visible,
                            presenting: deleteGroup) { g in
            Button("احذف المجموعة", role: .destructive) {
                Task { await act("darbak_admin_delete_group", ["p_code": g.code], done: "انحذفت المجموعة") }
            }
            Button("إلغاء", role: .cancel) {}
        }
        .confirmationDialog(deleteUser.map { "تحذف حساب «\($0.name)»؟ يطلع من كل المجموعات" } ?? "",
                            isPresented: Binding(get: { deleteUser != nil }, set: { if !$0 { deleteUser = nil } }),
                            titleVisibility: .visible,
                            presenting: deleteUser) { u in
            Button("احذف الحساب", role: .destructive) {
                Task { await act("darbak_admin_delete_user", ["p_member": u.id], done: "انحذف الحساب") }
            }
            Button("إلغاء", role: .cancel) {}
        }
    }

    // MARK: - التحميل والأوامر

    private func load() async {
        loading = true
        do {
            let data = try await friends.adminCall("darbak_admin_stats")
            let s = try JSONDecoder().decode(AdminStats.self, from: data)
            stats = s
            error = nil
            if !filled {
                filled = true
                minVersion = s.config.minVersion ?? ""
                updateMessage = s.config.updateMessage ?? ""
                annTitle = s.config.title ?? ""
                annBody = s.config.body ?? ""
                annActive = s.config.active
            }
        } catch {
            self.error = Cloud.message(for: error)
        }
        loading = false
    }

    private func act(_ fn: String, _ params: [String: Any], done: String) async {
        do {
            _ = try await friends.adminCall(fn, params)
            toast = done
            Haptics.success()
            await load()
            RemoteConfig.shared.refresh(force: true)
        } catch {
            toast = Cloud.message(for: error)
        }
    }

    // MARK: - نظرة عامة

    private func overview(_ s: AdminStats) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                tile("المستخدمين", s.users, "person.2.fill", Palette.cyan)
                tile("نشطين اليوم", s.activeDay, "bolt.fill", Palette.green)
                tile("نشطين الأسبوع", s.activeWeek, "calendar", Palette.blue)
                tile("جدد هذا الأسبوع", s.newWeek, "sparkles", Palette.violet)
                tile("المجموعات", s.groups, "person.3.fill", Palette.pink)
                tile("العضويات", s.memberships, "link", Palette.orange)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("خطوات الكل هذا الأسبوع")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Palette.text2)
                Text(Fmt.num(s.weekSteps))
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.gold)
                    .shadow(color: Palette.gold.opacity(0.5), radius: 8)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(tint: Palette.gold)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("النسخ عند الناس")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("آخر نسخة: \(updates.latest ?? updates.current)")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Palette.text3)
                }
                let top = max(s.versions.map(\.count).max() ?? 1, 1)
                ForEach(s.versions) { v in
                    HStack(spacing: 10) {
                        Text(v.version)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .frame(width: 64, alignment: .leading)
                        GeometryReader { g in
                            Capsule()
                                .fill(LinearGradient(colors: [Palette.cyan, Palette.blue], startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(g.size.width * CGFloat(v.count) / CGFloat(top), 4))
                        }
                        .frame(height: 8)
                        Text(Fmt.num(v.count))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.text2)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
                Text("«قديمة» = نسخ قبل 2.8 (ما ترسل رقمها)")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Palette.text3)
            }
            .padding(16)
            .glassCard()
        }
    }

    private func tile(_ title: String, _ value: Int, _ icon: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.text2)
            Text(Fmt.num(value))
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.5), radius: 6)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 18, tint: color)
    }

    // MARK: - التحكم

    private func updateCard(_ s: AdminStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("تحديث إجباري", systemImage: "arrow.down.app.fill")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("اللي نسخته أقدم من الرقم هذا يطلع له شاشة «لازم تحدث» وما يقدر يكمل. أنت ما تقفل عليك.")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Palette.text2)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .bottom, spacing: 8) {
                InputField(title: "أقل نسخة مسموحة", text: $minVersion, placeholder: "مثلا 2.8", keyboard: .decimalPad)
                Button("آخر نسخة") {
                    minVersion = updates.latest ?? updates.current
                }
                .buttonStyle(SoftButtonStyle(color: Palette.text2))
                .padding(.bottom, 6)
            }
            InputField(title: "الرسالة (اختياري)", text: $updateMessage, placeholder: "مثلا: حدث عشان تشتغل الشلة")
            HStack(spacing: 10) {
                Button {
                    hideKeyboard()
                    Task {
                        await act("darbak_admin_set_update",
                                  ["p_min_version": minVersion, "p_message": updateMessage],
                                  done: minVersion.isEmpty ? "انشال التحديث الإجباري" : "صار التحديث إجباري")
                    }
                } label: {
                    Label("حفظ", systemImage: "checkmark")
                }
                .buttonStyle(SoftButtonStyle(color: Palette.cyan))
                if s.config.minVersion != nil {
                    Button {
                        minVersion = ""
                        updateMessage = ""
                        Task {
                            await act("darbak_admin_set_update", ["p_min_version": "", "p_message": ""],
                                      done: "انشال التحديث الإجباري")
                        }
                    } label: {
                        Label("شيل الإجبار", systemImage: "xmark")
                    }
                    .buttonStyle(SoftButtonStyle(color: Palette.pink))
                }
            }
            Text(s.config.minVersion.map { "شغال الحين: أقل نسخة \($0)" } ?? "الحين: ما فيه تحديث إجباري")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(s.config.minVersion == nil ? Palette.text3 : Palette.orange)
        }
        .padding(16)
        .glassCard()
    }

    private var announceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("رسالة لكل الناس", systemImage: "megaphone.fill")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("تطلع في الصفحة الرئيسية عند الكل لين يقفلونها. لو غيرت الكلام تطلع لهم من جديد.")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Palette.text2)
                .fixedSize(horizontal: false, vertical: true)
            InputField(title: "العنوان", text: $annTitle, placeholder: "مثلا: تحدي جديد 🔥")
            InputField(title: "النص", text: $annBody, placeholder: "مثلا: الأول اليوم ياخذ لقب ملك اليوم")
            Toggle(isOn: $annActive) {
                Text("ظاهرة للناس")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .tint(Palette.gold)
            Button {
                hideKeyboard()
                Task {
                    await act("darbak_admin_set_announcement",
                              ["p_title": annTitle, "p_body": annBody, "p_active": annActive],
                              done: annActive ? "انشرت الرسالة" : "انشالت الرسالة")
                }
            } label: {
                Label(annActive ? "انشر" : "حفظ", systemImage: "paperplane.fill")
            }
            .buttonStyle(NeonButtonStyle(colors: [Palette.gold, Palette.orange]))
            .disabled(annActive && annTitle.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(16)
        .glassCard(tint: Palette.gold)
    }

    // MARK: - الناس

    private func usersList(_ s: AdminStats) -> some View {
        let q = search.trimmingCharacters(in: .whitespaces)
        let list = q.isEmpty ? s.users_list : s.users_list.filter { $0.name.localizedCaseInsensitiveContains(q) }
        return VStack(alignment: .leading, spacing: 10) {
            InputField(title: "دور بالاسم", text: $search, placeholder: "اسم الشخص")
            Text("\(Fmt.num(list.count)) شخص · الأحدث نشاطا فوق")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Palette.text3)
            ForEach(list) { u in
                HStack(spacing: 10) {
                    Text(u.emoji)
                        .font(.system(size: 24))
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(u.name)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            if u.admin {
                                Text("أدمن")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(Palette.gold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Palette.gold.opacity(0.15), in: Capsule())
                            }
                        }
                        Text("مستوى \(Fmt.num(u.level)) · نسخة \(u.version) · \(Fmt.num(u.groups)) مجموعات")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Palette.text2)
                        Text("آخر ظهور \(Self.relative.localizedString(for: Date(timeIntervalSince1970: u.updated), relativeTo: Date()))")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(Palette.text3)
                    }
                    Spacer(minLength: 4)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(Fmt.num(u.weekSteps))
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text("هذا الأسبوع")
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(Palette.text3)
                    }
                    if !u.admin {
                        Menu {
                            Button {
                                UIPasteboard.general.string = u.id
                                toast = "نسخت رقمه"
                            } label: {
                                Label("انسخ رقمه", systemImage: "doc.on.doc")
                            }
                            Button(role: .destructive) {
                                deleteUser = u
                            } label: {
                                Label("احذف الحساب", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Palette.text2)
                                .frame(width: 26, height: 30)
                        }
                    }
                }
                .padding(12)
                .glassCard(radius: 16)
            }
        }
    }

    // MARK: - المجموعات

    private func groupsList(_ s: AdminStats) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(Fmt.num(s.groups_list.count)) مجموعة · الأحدث فوق")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Palette.text3)
            ForEach(s.groups_list) { g in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(g.name)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(g.code)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(Palette.cyan)
                            .environment(\.layoutDirection, .leftToRight)
                        Text("المسؤول: \(g.owner) · \(Fmt.num(g.members)) أعضاء")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Palette.text2)
                        Text("انشأت \(Self.relative.localizedString(for: Date(timeIntervalSince1970: g.created), relativeTo: Date()))")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(Palette.text3)
                    }
                    Spacer()
                    Button {
                        deleteGroup = g
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(Palette.pink)
                            .frame(width: 36, height: 36)
                            .background(Palette.pink.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .glassCard(radius: 16)
            }
            if s.groups_list.isEmpty {
                notice("ما فيه مجموعات للحين.")
            }
        }
    }

    // MARK: - أشياء صغيرة

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
        if let t = toast {
            Text(t)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Palette.card.opacity(0.95), in: Capsule())
                .overlay(Capsule().strokeBorder(Palette.gold.opacity(0.5), lineWidth: 1))
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: t) {
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    if toast == t { toast = nil }
                }
        }
    }
}
