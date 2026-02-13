import Foundation
import AVKit
import AVFoundation
import SwiftUI
import Combine

@MainActor
final class VideoAnalysisViewModel: ObservableObject {
    let run: SprintRun

    // Player
    @Published var player: AVPlayer?
    @Published var isPlaying: Bool = false
    @Published var playbackSpeed: Double = 1.0
    @Published var scrubberProgress: Double = 0
    @Published var currentFrameIndex: Int = 0
    @Published var videoDuration: TimeInterval = 0
    @Published var thumbnails: [UIImage] = []

    // Overlay
    @Published var showSkeleton: Bool = true
    @Published var showAngles: Bool = true
    @Published var showAngleProtractor: Bool = false
    @Published var splitScreenMode: Bool = false

    // Annotation
    @Published var currentAnnotations: [VideoAnnotation] = []
    @Published var activeDrawingPath: [CGPoint] = []
    @Published var selectedTool: DrawingTool = .pen
    @Published var selectedColor: Color = .brandOrange

    // Protractor points
    @Published var protractorPoint1: CGPoint = CGPoint(x: 100, y: 200)
    @Published var protractorPoint2: CGPoint = CGPoint(x: 200, y: 300)
    @Published var protractorPoint3: CGPoint = CGPoint(x: 300, y: 200)

    // Analysis state
    @Published var currentSnapshot: BiomechanicsSnapshot?
    @Published var highlightClipURL: URL?

    enum DrawingTool: String, CaseIterable {
        case pen, line, circle, angle, eraser
    }

    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private let frameRate: Double

    var currentTimeFormatted: String {
        guard let player else { return "0:00.000" }
        let time = CMTimeGetSeconds(player.currentTime())
        let min = Int(time) / 60
        let sec = Int(time) % 60
        let ms = Int((time - Double(Int(time))) * 1000)
        return String(format: "%d:%02d.%03d", min, sec, ms)
    }

    init(run: SprintRun) {
        self.run = run
        self.frameRate = run.frameRate
        self.currentAnnotations = run.manualAnnotations
    }

    // MARK: - Setup
    func setupPlayer() {
        guard let url = run.videoURL else { return }
        let asset = AVAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: item)

        Task {
            if let duration = try? await asset.load(.duration) {
                videoDuration = CMTimeGetSeconds(duration)
            }
            await generateThumbnails(asset: asset)
        }

        // Observe playback time
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: CMTimeScale(frameRate)),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            let seconds = CMTimeGetSeconds(time)
            self.scrubberProgress = self.videoDuration > 0 ? seconds / self.videoDuration : 0
            self.currentFrameIndex = Int(seconds * self.frameRate)
            self.updateSnapshot(for: seconds)
        }

        // Observe scrubber changes
        $scrubberProgress
            .dropFirst()
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { [weak self] progress in
                guard let self else { return }
                let targetTime = CMTime(seconds: progress * self.videoDuration, preferredTimescale: 600)
                self.player?.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
            }
            .store(in: &cancellables)
    }

    private func generateThumbnails(asset: AVAsset) async {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 120, height: 90)

        let duration = try? await asset.load(.duration)
        let total = CMTimeGetSeconds(duration ?? .zero)
        let count = 20
        let step = total / Double(count)

        var images: [UIImage] = []
        for i in 0..<count {
            let time = CMTime(seconds: Double(i) * step, preferredTimescale: 600)
            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                images.append(UIImage(cgImage: cgImage))
            }
        }

        thumbnails = images
    }

    func cleanup() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        player?.pause()
    }

    // MARK: - Playback Control
    func togglePlayPause() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        isPlaying.toggle()
    }

    func setPlaybackSpeed(_ speed: Double) {
        playbackSpeed = speed
        player?.rate = Float(speed)
    }

    func stepFrames(_ count: Int) {
        guard let player else { return }
        let frameDuration = 1.0 / frameRate
        let current = CMTimeGetSeconds(player.currentTime())
        let target = max(0, min(videoDuration, current + Double(count) * frameDuration))
        let time = CMTime(seconds: target, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        isPlaying = false
        player.pause()
    }

    // MARK: - Snapshot Lookup
    private func updateSnapshot(for timestamp: TimeInterval) {
        currentSnapshot = run.biomechanicsSnapshots
            .min(by: { abs($0.timestamp - timestamp) < abs($1.timestamp - timestamp) })
    }

    // MARK: - Drawing
    func handleDraw(at point: CGPoint, ended: Bool) {
        if selectedTool == .eraser {
            eraseAt(point: point)
            return
        }

        if ended && !activeDrawingPath.isEmpty {
            let pathData = activeDrawingPath
                .map { "\(Int($0.x)),\(Int($0.y))" }
                .joined(separator: ";")

            let annotation = VideoAnnotation(
                timestamp: CMTimeGetSeconds(player?.currentTime() ?? .zero),
                pathData: pathData,
                color: UIColor(selectedColor).hexString,
                lineWidth: 2.5,
                annotationType: toolToAnnotationType(selectedTool)
            )
            currentAnnotations.append(annotation)
            activeDrawingPath = []
        } else {
            activeDrawingPath.append(point)
        }
    }

    private func eraseAt(point: CGPoint) {
        currentAnnotations.removeAll { annotation in
            let points = annotation.pathData.split(separator: ";").compactMap { pair -> CGPoint? in
                let c = pair.split(separator: ",")
                guard c.count == 2, let x = Double(c[0]), let y = Double(c[1]) else { return nil }
                return CGPoint(x: x, y: y)
            }
            return points.contains { pt in
                let dx = pt.x - point.x, dy = pt.y - point.y
                return sqrt(dx*dx + dy*dy) < 20
            }
        }
    }

    private func toolToAnnotationType(_ tool: DrawingTool) -> VideoAnnotation.AnnotationType {
        switch tool {
        case .pen:    return .freehand
        case .line:   return .line
        case .circle: return .circle
        case .angle:  return .angle
        case .eraser: return .freehand
        }
    }

    func undoLastAnnotation() {
        guard !currentAnnotations.isEmpty else { return }
        currentAnnotations.removeLast()
    }

    func clearAnnotations() {
        currentAnnotations.removeAll()
        activeDrawingPath.removeAll()
    }

    // MARK: - Export
    func exportAnnotatedVideo() {
        guard let url = run.videoURL else { return }
        // In full implementation: composite annotation layer with AVMutableComposition
        // and export via AVAssetExportSession
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    func generateHighlightClip() {
        guard let url = run.videoURL else { return }
        Task {
            await HighlightClipGenerator.shared.generate(from: run, sourceURL: url)
        }
    }

    func toggleSplitScreenMode() {
        splitScreenMode.toggle()
    }
}

// MARK: - Highlight Clip Generator
final class HighlightClipGenerator {
    static let shared = HighlightClipGenerator()
    private init() {}

    func generate(from run: SprintRun, sourceURL: URL) async {
        let asset = AVAsset(url: sourceURL)

        // Find best 5-10 second segment (highest average form score)
        let duration = try? await asset.load(.duration)
        let totalSeconds = CMTimeGetSeconds(duration ?? .zero)

        // Find block clearance timestamp (first frame after blockStart phase)
        let blockClearTime = run.detectedPhases
            .first { $0.phase == .drivePhase }?.startTime ?? 0

        // Extract 0.5s before block clearance → 4.5s after
        let startTime = max(0, blockClearTime - 0.5)
        let endTime = min(totalSeconds, startTime + 5.0)

        let startCMTime = CMTime(seconds: startTime, preferredTimescale: 600)
        let endCMTime   = CMTime(seconds: endTime, preferredTimescale: 600)

        // Create composition
        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else { return }

        do {
            let assetTrack = try await asset.loadTracks(withMediaType: .video).first
            guard let assetTrack else { return }

            try track.insertTimeRange(
                CMTimeRange(start: startCMTime, end: endCMTime),
                of: assetTrack,
                at: .zero
            )

            // Add text overlays using AVMutableVideoComposition + CALayer
            let textLayer = CATextLayer()
            textLayer.string = "TrackMotion • Form Score: \(Int(run.formScore.overall))"
            textLayer.fontSize = 24
            textLayer.foregroundColor = UIColor.white.cgColor
            textLayer.frame = CGRect(x: 20, y: 40, width: 400, height: 40)

            // Export
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("highlight_\(run.id.uuidString).mp4")

            guard let exportSession = AVAssetExportSession(
                asset: composition,
                presetName: AVAssetExportPreset1280x720
            ) else { return }

            exportSession.outputURL = outputURL
            exportSession.outputFileType = .mp4

            await exportSession.export()

            if exportSession.status == .completed {
                // Share the clip
                await MainActor.run {
                    let activityVC = UIActivityViewController(
                        activityItems: [outputURL],
                        applicationActivities: nil
                    )
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootVC = windowScene.windows.first?.rootViewController {
                        rootVC.present(activityVC, animated: true)
                    }
                }
            }
        } catch {
            print("Highlight clip generation failed: \(error)")
        }
    }
}
