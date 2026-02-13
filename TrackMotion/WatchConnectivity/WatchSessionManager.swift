import Foundation
import WatchConnectivity

// MARK: - Watch Session Manager
/// Manages communication between iPhone and Apple Watch companion app
final class WatchSessionManager: NSObject, ObservableObject {
    static let shared = WatchSessionManager()

    @Published var isWatchReachable: Bool = false
    @Published var watchRecordingState: RecordingState = .idle
    @Published var watchMetrics: WatchMetrics?

    enum RecordingState: String {
        case idle      = "idle"
        case recording = "recording"
        case finished  = "finished"
    }

    struct WatchMetrics: Codable {
        var formScore: Double
        var phase: String
        var velocity: Double
        var distance: Double
        var timestamp: Date
    }

    private override init() {
        super.init()
        setupSession()
    }

    private func setupSession() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Send to Watch
    func sendRecordingState(_ state: RecordingState) {
        guard WCSession.default.isReachable else { return }
        let message: [String: Any] = ["recordingState": state.rawValue]
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Watch message failed: \(error)")
        }
    }

    func sendMetrics(formScore: Double, phase: SprintPhase, velocity: Double, distance: Double) {
        guard WCSession.default.isReachable else { return }

        let context: [String: Any] = [
            "formScore": formScore,
            "phase": phase.rawValue,
            "velocity": velocity,
            "distance": distance,
            "timestamp": Date().timeIntervalSince1970
        ]

        try? WCSession.default.updateApplicationContext(context)
    }

    func startRemoteRecording() {
        sendRecordingState(.recording)
    }

    func stopRemoteRecording() {
        sendRecordingState(.idle)
    }
}

// MARK: - WCSessionDelegate
extension WatchSessionManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isWatchReachable = activationState == .activated && session.isReachable
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            // Handle messages from Watch (e.g., start/stop recording)
            if let cmd = message["command"] as? String {
                switch cmd {
                case "startRecording":
                    NotificationCenter.default.post(name: .startRecordingFromShortcut, object: nil)
                case "stopRecording":
                    NotificationCenter.default.post(name: Notification.Name("com.trackmotion.stopRecording"), object: nil)
                default: break
                }
            }
        }
    }

    // Required on iOS
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}

// MARK: - Simplified Watch App View (watchOS target)
// Note: This would be in a separate watchOS target in Xcode
// Included here as reference implementation

/*
import WatchKit
import WatchConnectivity
import SwiftUI

// watchOS ContentView
struct WatchContentView: View {
    @StateObject private var viewModel = WatchViewModel()

    var body: some View {
        VStack(spacing: 8) {
            Text("\(Int(viewModel.formScore))")
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(scoreColor)

            Text(viewModel.phase)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(String(format: "%.1f m/s", viewModel.velocity))
                .font(.system(.subheadline, design: .monospaced))

            Button(action: viewModel.toggleRecording) {
                Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title)
                    .foregroundStyle(viewModel.isRecording ? .red : .orange)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    var scoreColor: Color {
        switch viewModel.formScore {
        case 80...100: return .green
        case 60..<80:  return .yellow
        default:       return .red
        }
    }
}
*/
