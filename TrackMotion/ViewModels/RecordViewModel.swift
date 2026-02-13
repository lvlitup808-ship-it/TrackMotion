import Foundation
import AVFoundation
import Combine
import SwiftUI

@MainActor
final class RecordViewModel: NSObject, ObservableObject {
    // MARK: - Published State
    @Published var isRecording: Bool = false
    @Published var currentPoses: [DetectedPose] = []
    @Published var latestSnapshot: BiomechanicsSnapshot?
    @Published var currentPhase: SprintPhase = .unknown
    @Published var formQualityScore: Double = 0
    @Published var activeFeedbackCue: CoachingCue?
    @Published var estimatedDistance: Double = 0
    @Published var currentVelocity: Double = 0
    @Published var recordingDuration: TimeInterval = 0
    @Published var cameraFrameSize: CGSize = UIScreen.main.bounds.size
    @Published var selectedAthlete: AthleteProfile?

    // Settings
    @Published var showSkeleton: Bool = true
    @Published var showMetricsPanel: Bool = true
    @Published var showGridOverlay: Bool = false
    @Published var showAngles: Bool = true
    @Published var voiceFeedbackEnabled: Bool = true
    @Published var autoPhaseDetection: Bool = true
    @Published var multiPersonMode: Bool = false
    @Published var kalmanFilteringEnabled: Bool = true
    @Published var processingFrameRate: Int = 15
    @Published var videoQuality: AVCaptureSession.Preset = .hd1920x1080

    // MARK: - Engine Components
    let captureSession = AVCaptureSession()
    let phaseDetector = SprintPhaseDetector()
    private let poseEngine = PoseEstimationEngine()
    private let biomechanicsCalculator = BiomechanicsCalculator.shared
    private let formScoringEngine = FormScoringEngine.shared
    private let feedbackEngine = RealtimeFeedbackEngine()

    // MARK: - Recording State
    private var movieOutput: AVCaptureMovieFileOutput?
    private var recordingStartTime: Date?
    private var recordingTimer: Timer?
    private var frameCount: Int = 0
    private var allSnapshots: [BiomechanicsSnapshot] = []
    private var previousPose: DetectedPose?

    // MARK: - Camera
    private var currentCameraPosition: AVCaptureDevice.Position = .back
    private var videoInput: AVCaptureDeviceInput?

    var recordingDurationFormatted: String {
        let total = Int(recordingDuration)
        let min = total / 60
        let sec = total % 60
        return String(format: "%d:%02d", min, sec)
    }

    // MARK: - Setup
    override init() {
        super.init()
        setupEngines()
    }

    private func setupEngines() {
        poseEngine.delegate = self
        poseEngine.minimumConfidence = 0.5
        poseEngine.processingFrameRate = processingFrameRate
        poseEngine.enableMultiPerson = multiPersonMode
        poseEngine.useKalmanFiltering = kalmanFilteringEnabled
        feedbackEngine.delegate = self
        feedbackEngine.isVoiceFeedbackEnabled = voiceFeedbackEnabled
    }

    // MARK: - Camera Session
    func startSession() {
        Task(priority: .userInitiated) {
            await configureSession()
            captureSession.startRunning()
        }
    }

    func stopSession() {
        captureSession.stopRunning()
    }

    private func configureSession() async {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = videoQuality

        // Remove existing inputs/outputs
        captureSession.inputs.forEach { captureSession.removeInput($0) }
        captureSession.outputs.forEach { captureSession.removeOutput($0) }

        // Add video input
        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: currentCameraPosition
        ),
        let input = try? AVCaptureDeviceInput(device: device) else {
            captureSession.commitConfiguration()
            return
        }

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
            videoInput = input
        }

        // Configure camera for high frame rate
        configureFrameRate(for: device)

        // Video output for pose estimation
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.trackmotion.video", qos: .userInteractive))
        videoOutput.alwaysDiscardsLateVideoFrames = true

        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        // Movie output for saving
        let movieOutput = AVCaptureMovieFileOutput()
        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
            self.movieOutput = movieOutput
        }

        captureSession.commitConfiguration()
    }

    private func configureFrameRate(for device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 60)
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
            device.unlockForConfiguration()
        } catch {
            print("Frame rate configuration failed: \(error)")
        }
    }

    // MARK: - Recording Control
    func startRecording() {
        guard !isRecording else { return }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("trackmotion_\(Date().timeIntervalSince1970).mov")

        movieOutput?.startRecording(to: outputURL, recordingDelegate: self)
        isRecording = true
        recordingStartTime = Date()
        allSnapshots.removeAll()
        phaseDetector.reset()
        feedbackEngine.reset()

        // Start duration timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.recordingDuration = Date().timeIntervalSince(self.recordingStartTime ?? Date())
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        movieOutput?.stopRecording()
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    // MARK: - Camera Flip
    func flipCamera() {
        currentCameraPosition = currentCameraPosition == .back ? .front : .back
        Task { await configureSession() }
    }

    // MARK: - Multi-Person Toggle
    func toggleMultiPersonMode() {
        multiPersonMode.toggle()
        poseEngine.enableMultiPerson = multiPersonMode
    }

    // MARK: - Frame Processing
    private func processFrame(sampleBuffer: CMSampleBuffer) {
        frameCount += 1
        poseEngine.processVideoFrame(sampleBuffer)
    }

    // MARK: - Post-Processing
    private func processPoseUpdate(_ poses: [DetectedPose], timestamp: CMTime) {
        guard !poses.isEmpty else { return }
        let primaryPose = poses[0]
        let ts = CMTimeGetSeconds(timestamp)

        // Phase detection
        let phase = autoPhaseDetection
            ? phaseDetector.update(pose: primaryPose, timestamp: ts)
            : .unknown

        // Biomechanics calculation
        let snapshot = biomechanicsCalculator.computeSnapshot(
            from: primaryPose,
            previousPose: previousPose,
            frameIndex: frameCount,
            timestamp: ts,
            phase: phase
        )

        previousPose = primaryPose
        allSnapshots.append(snapshot)

        // Real-time feedback
        let cues = feedbackEngine.processSnapshot(snapshot)

        // Update UI state
        currentPoses = poses
        latestSnapshot = snapshot
        currentPhase = phase
        formQualityScore = snapshot.formQualityScore
        estimatedDistance = phaseDetector.estimatedDistanceMeters
        currentVelocity = phaseDetector.currentVelocityMs

        if let highPriorityCue = cues.first(where: { $0.priority == .high }) {
            activeFeedbackCue = highPriorityCue
            // Auto-hide cue after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
                if self?.activeFeedbackCue?.id == highPriorityCue.id {
                    self?.activeFeedbackCue = nil
                }
            }
        }
    }

    // MARK: - Finalize Run
    private func finalizeRun(videoURL: URL) {
        guard !allSnapshots.isEmpty else { return }

        let phases = phaseDetector.detectedPhaseSegments
        let formScore = formScoringEngine.scoreRun(snapshots: allSnapshots, phases: phases)
        let recommendations = RecommendationEngine.shared.generateRecommendations(
            from: allSnapshots,
            score: formScore,
            athleteHistory: selectedAthlete?.sessions
                .flatMap { $0.runs.map { $0.formScore } } ?? []
        )
        let velocityCurve = phaseDetector.buildVelocityCurve()
        let injuryFlags = InjuryRiskDetector.shared.analyze(snapshots: allSnapshots)

        let sessionID = UUID()
        let run = SprintRun(
            sessionID: sessionID,
            videoURL: videoURL,
            duration: recordingDuration,
            frameRate: Double(processingFrameRate),
            detectedPhases: phases,
            biomechanicsSnapshots: allSnapshots,
            formScore: formScore,
            aiRecommendations: recommendations,
            velocityCurve: velocityCurve,
            injuryRiskFlags: injuryFlags
        )

        // Save to athlete's session
        if let athlete = selectedAthlete {
            let session = TrainingSession(
                athleteID: athlete.id
            )
            session.runs.append(run)
            AthleteStore.shared.addSession(session, to: athlete)
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension RecordViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        Task { @MainActor in
            self.processFrame(sampleBuffer: sampleBuffer)
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension RecordViewModel: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        if error == nil {
            Task { @MainActor in
                self.finalizeRun(videoURL: outputFileURL)
            }
        }
    }
}

// MARK: - PoseEstimationDelegate
extension RecordViewModel: PoseEstimationDelegate {
    nonisolated func poseEstimationEngine(
        _ engine: PoseEstimationEngine,
        didDetectPoses poses: [DetectedPose],
        in pixelBuffer: CVPixelBuffer,
        at timestamp: CMTime
    ) {
        Task { @MainActor in
            self.processPoseUpdate(poses, timestamp: timestamp)
        }
    }

    nonisolated func poseEstimationEngine(_ engine: PoseEstimationEngine, didFailWithError error: Error) {
        print("Pose estimation error: \(error)")
    }
}

// MARK: - RealtimeFeedbackDelegate
extension RecordViewModel: RealtimeFeedbackDelegate {
    func feedbackEngine(_ engine: RealtimeFeedbackEngine, didTriggerCue cue: CoachingCue) {
        activeFeedbackCue = cue
    }
}
