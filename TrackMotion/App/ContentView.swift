import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            RecordView()
                .tabItem {
                    Label("Record", systemImage: "video.circle.fill")
                }
                .tag(AppState.Tab.record)

            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(AppState.Tab.dashboard)

            AthletesView()
                .tabItem {
                    Label("Athletes", systemImage: "person.2.fill")
                }
                .tag(AppState.Tab.athletes)

            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical.fill")
                }
                .tag(AppState.Tab.library)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(AppState.Tab.settings)
        }
        .tint(Color.brandOrange)
        .onAppear {
            configureTabBar()
        }
    }

    private func configureTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.backgroundPrimary)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
