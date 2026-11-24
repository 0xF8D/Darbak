import SwiftUI

@main
struct F8DApp: App {
    @StateObject private var health = HealthStore()
    @Environment(\.scenePhase) private var phase
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(health)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "ar_SA"))
                .preferredColorScheme(.dark)
                .task { health.start() }
                .onReceive(timer) { _ in health.tick() }
                .onChange(of: phase) { _, new in
                    if new == .active { health.tick() }
                }
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            StepsView()
                .tabItem { Label("الخطوات", systemImage: "figure.walk") }
            BadgesView()
                .tabItem { Label("الدروع", systemImage: "rosette") }
            StatsView()
                .tabItem { Label("إحصائيات", systemImage: "chart.bar.fill") }
        }
        .tint(Color(hex: 0x38BDF8))
    }
}
