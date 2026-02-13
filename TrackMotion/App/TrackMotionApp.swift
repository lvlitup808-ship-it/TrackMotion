import SwiftUI
import CoreData

@main
struct TrackMotionApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - App State
final class AppState: ObservableObject {
    @Published var selectedTab: Tab = .record
    @Published var selectedAthlete: AthleteProfile?
    @Published var isRecording: Bool = false
    @Published var activeSession: TrainingSession?
    @Published var showOnboarding: Bool = false

    enum Tab: Int, CaseIterable {
        case record = 0
        case dashboard = 1
        case athletes = 2
        case library = 3
        case settings = 4

        var title: String {
            switch self {
            case .record:    return "Record"
            case .dashboard: return "Dashboard"
            case .athletes:  return "Athletes"
            case .library:   return "Library"
            case .settings:  return "Settings"
            }
        }

        var icon: String {
            switch self {
            case .record:    return "video.circle.fill"
            case .dashboard: return "chart.line.uptrend.xyaxis"
            case .athletes:  return "person.2.fill"
            case .library:   return "books.vertical.fill"
            case .settings:  return "gearshape.fill"
            }
        }
    }
}
