// دربك — © 0xF8D

import SwiftUI
import BackgroundTasks
import UIKit

@main
struct DarbakApp: App {
    @StateObject private var settings = AppSettings.shared
    @StateObject private var health = HealthStore.shared
    @StateObject private var walk = WalkMode.shared
    @StateObject private var food = FoodStore.shared
    @StateObject private var friends = FriendStore.shared
    @Environment(\.scenePhase) var phase
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    init() {
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(Palette.bgTop)
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
        UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(Palette.blue)
        UISegmentedControl.appearance().backgroundColor = UIColor(Palette.card)
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white.withAlphaComponent(0.7)], for: .normal)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .appEnvironment()
                .task {
                    health.start()
                    friends.start()
                    Reminder.requestAuthorization()
                }
                .onReceive(timer) { _ in health.tick() }
                .onOpenURL { url in
                    // رابط دعوة: darbak://join/ABCD1234
                    friends.handleURL(url)
                }
                .onChange(of: phase) { new in
                    if new == .active {
                        health.tick(force: true)
                        Task { await friends.sync(force: true) }
                    }
                    if new == .background {
                        health.pushWidget(force: true)
                        BackgroundRefresh.schedule()
                    }
                }
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.id)) {
            BackgroundRefresh.schedule()
            await HealthStore.shared.backgroundRefresh()
        }
    }
}

enum BackgroundRefresh {
    static let id = "com.f8d.steps.refresh"

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: id)
        request.earliestBeginDate = Date().addingTimeInterval(20 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}

enum AppTab: Hashable {
    case home, progress, friends, calories, stats
}

struct RootView: View {
    @EnvironmentObject var friends: FriendStore
    @State private var tab: AppTab = .home

    var body: some View {
        TabView(selection: $tab) {
            HomeView(openProgress: { tab = .progress })
                .tabItem { Label("خطواتي", systemImage: "figure.walk") }
                .tag(AppTab.home)
            BadgesView()
                .tabItem { Label("إنجازاتي", systemImage: "star.circle.fill") }
                .tag(AppTab.progress)
            FriendsView()
                .tabItem { Label("الشلة", systemImage: "person.3.fill") }
                .tag(AppTab.friends)
            CaloriesView()
                .tabItem { Label("السعرات", systemImage: "fork.knife") }
                .tag(AppTab.calories)
            StatsView()
                .tabItem { Label("أرقامي", systemImage: "chart.bar.fill") }
                .tag(AppTab.stats)
        }
        .tint(Palette.cyan)
        .overlay { CelebrationHost() }
        .onChange(of: friends.importTick) { _ in
            // فتحت رابط دعوة: نوديك لصفحة الشلة
            tab = .friends
        }
    }
}

/// منفصل عشان تحديثات الخطوات ما تعيد رسم التطبيق كله
struct CelebrationHost: View {
    @EnvironmentObject var health: HealthStore

    var body: some View {
        ZStack {
            if let event = health.celebration {
                CelebrationView(event: event) {
                    health.dismissCelebration(event.id)
                }
                .id(event.id)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: health.celebration?.id)
        .allowsHitTesting(health.celebration != nil)
    }
}
