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
                    Reminder.requestAuthorization()
                }
                .onReceive(timer) { _ in health.tick() }
                .onChange(of: phase) { _, new in
                    if new == .active { health.tick(force: true) }
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

struct RootView: View {
    @EnvironmentObject var health: HealthStore

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("خطواتي", systemImage: "figure.walk") }
            BadgesView()
                .tabItem { Label("الدروع", systemImage: "hexagon.fill") }
            CaloriesView()
                .tabItem { Label("السعرات", systemImage: "fork.knife") }
            StatsView()
                .tabItem { Label("إحصائيات", systemImage: "chart.bar.fill") }
        }
        .tint(Palette.cyan)
        .overlay {
            if let tier = health.celebration {
                CelebrationView(tier: tier) {
                    health.celebration = nil
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: health.celebration?.steps)
    }
}
