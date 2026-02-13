import AppIntents
import Foundation

// MARK: - Siri Shortcuts

/// "Hey Siri, start sprint recording"
struct StartRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Sprint Recording"
    static var description = IntentDescription("Start recording a sprint session in TrackMotion")

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // Navigate to Record tab and begin recording
        if let appState = AppState.current {
            appState.selectedTab = .record
            // Trigger recording start via notification
            NotificationCenter.default.post(name: .startRecordingFromShortcut, object: nil)
        }
        return .result()
    }
}

/// "Hey Siri, view last sprint session"
struct ViewLastSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "View Last Sprint Session"
    static var description = IntentDescription("Open the most recent training session in TrackMotion")

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        if let appState = AppState.current {
            appState.selectedTab = .dashboard
        }
        return .result()
    }
}

/// "Hey Siri, analyze my last sprint"
struct AnalyzeLastSprintIntent: AppIntent {
    static var title: LocalizedStringResource = "Analyze Last Sprint"
    static var description = IntentDescription("Review the AI analysis of your most recent sprint run")

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        if let appState = AppState.current {
            appState.selectedTab = .dashboard
        }
        return .result()
    }
}

// MARK: - App Shortcuts Provider
struct TrackMotionShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRecordingIntent(),
            phrases: [
                "Start recording with \(.applicationName)",
                "Start sprint recording in \(.applicationName)",
                "Record sprint with \(.applicationName)"
            ],
            shortTitle: "Start Recording",
            systemImageName: "video.circle.fill"
        )

        AppShortcut(
            intent: ViewLastSessionIntent(),
            phrases: [
                "View last session in \(.applicationName)",
                "Show my last sprint in \(.applicationName)"
            ],
            shortTitle: "Last Session",
            systemImageName: "clock.arrow.circlepath"
        )

        AppShortcut(
            intent: AnalyzeLastSprintIntent(),
            phrases: [
                "Analyze my last sprint with \(.applicationName)",
                "Show sprint analysis in \(.applicationName)"
            ],
            shortTitle: "Analyze Sprint",
            systemImageName: "chart.line.uptrend.xyaxis"
        )
    }
}

// MARK: - Home Screen Quick Actions
extension UIApplicationShortcutItem {
    static let startRecording = UIApplicationShortcutItem(
        type: "com.trackmotion.startRecording",
        localizedTitle: "Start Recording",
        localizedSubtitle: "Begin sprint analysis",
        icon: UIApplicationShortcutIcon(systemImageName: "video.circle.fill"),
        userInfo: nil
    )

    static let viewLastSession = UIApplicationShortcutItem(
        type: "com.trackmotion.lastSession",
        localizedTitle: "Last Session",
        localizedSubtitle: "View recent analysis",
        icon: UIApplicationShortcutIcon(systemImageName: "clock.arrow.circlepath"),
        userInfo: nil
    )

    static let compareAthletes = UIApplicationShortcutItem(
        type: "com.trackmotion.compare",
        localizedTitle: "Compare Athletes",
        localizedSubtitle: "Side-by-side analysis",
        icon: UIApplicationShortcutIcon(systemImageName: "person.2.fill"),
        userInfo: nil
    )
}

// MARK: - Notification Names
extension Notification.Name {
    static let startRecordingFromShortcut = Notification.Name("com.trackmotion.startRecording")
    static let viewLastSessionFromShortcut = Notification.Name("com.trackmotion.viewLastSession")
}

// MARK: - AppState extension for shortcuts
extension AppState {
    // Weak singleton for use in intents
    static weak var current: AppState?
}

// MARK: - UIApplication Shortcut Handler
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        handleShortcut(shortcutItem, completionHandler: completionHandler)
    }

    private func handleShortcut(
        _ shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        switch shortcutItem.type {
        case "com.trackmotion.startRecording":
            NotificationCenter.default.post(name: .startRecordingFromShortcut, object: nil)
            completionHandler(true)
        case "com.trackmotion.lastSession":
            NotificationCenter.default.post(name: .viewLastSessionFromShortcut, object: nil)
            completionHandler(true)
        default:
            completionHandler(false)
        }
    }
}
