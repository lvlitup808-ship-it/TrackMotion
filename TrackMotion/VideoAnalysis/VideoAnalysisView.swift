import SwiftUI
import AVKit
import AVFoundation

// MARK: - Video Analysis View
struct VideoAnalysisView: View {
    let run: SprintRun
    @StateObject private var viewModel: VideoAnalysisViewModel
    @Environment(\.dismiss) var dismiss

    init(run: SprintRun) {
        self.run = run
        _viewModel = StateObject(wrappedValue: VideoAnalysisViewModel(run: run))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Video player + annotation overlay
                videoPlayerSection

                // Bottom control bar
                controlBar
            }
        }
        .navigationTitle("Video Analysis")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        viewModel.exportAnnotatedVideo()
                    } label: {
                        Label("Export Annotated Video", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        viewModel.generateHighlightClip()
                    } label: {
                        Label("Generate Highlight Clip", systemImage: "scissors")
                    }
                    Button {
                        viewModel.toggleSplitScreenMode()
                    } label: {
                        Label(
                            viewModel.splitScreenMode ? "Exit Split Screen" : "Split Screen Compare",
                            systemImage: "rectangle.split.2x1"
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear { viewModel.setupPlayer() }
        .onDisappear { viewModel.cleanup() }
    }

    // MARK: - Video Player Section
    private var videoPlayerSection: some View {
        GeometryReader { geo in
            ZStack {
                // Video player
                if let player = viewModel.player {
                    VideoPlayer(player: player)
                        .aspectRatio(contentMode: .fit)
                        .disabled(true)  // We handle gestures manually
                }

                // Skeleton overlay
                if viewModel.showSkeleton, let snapshot = viewModel.currentSnapshot {
                    SkeletonOverlayView(
                        poses: snapshot.keypoints.isEmpty ? [] : [
                            DetectedPose(
                                athleteIndex: 0,
                                keypoints: snapshot.keypoints,
                                boundingBox: .zero,
                                confidence: Float(snapshot.detectionConfidence)
                            )
                        ],
                        frameSize: geo.size,
                        phaseDetector: SprintPhaseDetector()
                    )
                }

                // Annotation overlay
                AnnotationOverlayView(
                    annotations: viewModel.currentAnnotations,
                    activeDrawing: viewModel.activeDrawingPath,
                    selectedTool: viewModel.selectedTool,
                    selectedColor: viewModel.selectedColor
                )
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            viewModel.handleDraw(at: value.location, ended: false)
                        }
                        .onEnded { value in
                            viewModel.handleDraw(at: value.location, ended: true)
                        }
                )

                // Angle protractor overlay
                if viewModel.showAngleProtractor {
                    AngleProtractorView(
                        point1: viewModel.protractorPoint1,
                        point2: viewModel.protractorPoint2,
                        point3: viewModel.protractorPoint3
                    )
                }

                // Tool palette
                VStack {
                    Spacer()
                    DrawingToolbar(viewModel: viewModel)
                        .padding(.bottom, 8)
                }
            }
        }
        .frame(maxHeight: UIScreen.main.bounds.height * 0.6)
    }

    // MARK: - Control Bar
    private var controlBar: some View {
        VStack(spacing: 12) {
            // Frame step controls
            HStack(spacing: 16) {
                // Back 10 frames
                Button {
                    viewModel.stepFrames(-10)
                } label: {
                    Image(systemName: "backward.end.alt.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }

                // Back 1 frame
                Button {
                    viewModel.stepFrames(-1)
                } label: {
                    Image(systemName: "backward.frame.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }

                // Play/Pause
                Button {
                    viewModel.togglePlayPause()
                } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                }
                .frame(width: 50)

                // Forward 1 frame
                Button {
                    viewModel.stepFrames(1)
                } label: {
                    Image(systemName: "forward.frame.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }

                // Forward 10 frames
                Button {
                    viewModel.stepFrames(10)
                } label: {
                    Image(systemName: "forward.end.alt.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
            }

            // Playback speed
            HStack(spacing: 8) {
                Text("Speed:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach([0.1, 0.25, 0.5, 1.0, 2.0], id: \.self) { speed in
                    Button {
                        viewModel.setPlaybackSpeed(speed)
                    } label: {
                        Text(speed == 1.0 ? "1x" : "\(String(format: "%.0f", speed * 100))%")
                            .font(.caption.weight(viewModel.playbackSpeed == speed ? .bold : .regular))
                            .foregroundStyle(viewModel.playbackSpeed == speed ? .brandOrange : .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                viewModel.playbackSpeed == speed
                                    ? Color.brandOrange.opacity(0.2)
                                    : Color.clear,
                                in: Capsule()
                            )
                    }
                }
            }

            // Scrubber
            VideoScrubberView(
                progress: $viewModel.scrubberProgress,
                duration: viewModel.videoDuration,
                thumbnails: viewModel.thumbnails
            )
            .padding(.horizontal)

            // Frame / Time info
            HStack {
                Text("Frame: \(viewModel.currentFrameIndex)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.currentTimeFormatted)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            // Skeleton toggle
            HStack {
                Toggle("Skeleton", isOn: $viewModel.showSkeleton)
                    .font(.caption)
                Toggle("Angles", isOn: $viewModel.showAngles)
                    .font(.caption)
                Toggle("Protractor", isOn: $viewModel.showAngleProtractor)
                    .font(.caption)
            }
            .tint(.brandOrange)
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color.backgroundPrimary)
    }
}

// MARK: - Drawing Toolbar
struct DrawingToolbar: View {
    @ObservedObject var viewModel: VideoAnalysisViewModel

    let tools: [(VideoAnalysisViewModel.DrawingTool, String)] = [
        (.pen, "pencil"),
        (.line, "line.diagonal"),
        (.circle, "circle"),
        (.angle, "angle"),
        (.eraser, "eraser")
    ]

    let colors: [Color] = [.white, .brandOrange, .formSuccess, .formError, .accentBlue, .yellow]

    var body: some View {
        HStack(spacing: 12) {
            // Tools
            ForEach(tools, id: \.0.rawValue) { tool, icon in
                Button {
                    viewModel.selectedTool = tool
                } label: {
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundStyle(viewModel.selectedTool == tool ? .brandOrange : .white)
                        .frame(width: 36, height: 36)
                        .background(
                            viewModel.selectedTool == tool
                                ? Color.brandOrange.opacity(0.2)
                                : Color.clear,
                            in: Circle()
                        )
                }
            }

            Divider()
                .frame(height: 28)
                .overlay(.white.opacity(0.3))

            // Colors
            ForEach(colors, id: \.self) { color in
                Button {
                    viewModel.selectedColor = color
                } label: {
                    Circle()
                        .fill(color)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle()
                                .stroke(.white, lineWidth: viewModel.selectedColor == color ? 2 : 0)
                        )
                }
            }

            Divider()
                .frame(height: 28)
                .overlay(.white.opacity(0.3))

            // Undo / Clear
            Button {
                viewModel.undoLastAnnotation()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .foregroundStyle(.white)
            }

            Button {
                viewModel.clearAnnotations()
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.formError)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

// MARK: - Annotation Overlay
struct AnnotationOverlayView: View {
    let annotations: [VideoAnnotation]
    let activeDrawing: [CGPoint]
    let selectedTool: VideoAnalysisViewModel.DrawingTool
    let selectedColor: Color

    var body: some View {
        Canvas { context, size in
            // Draw saved annotations
            for annotation in annotations {
                guard !annotation.pathData.isEmpty else { continue }
                // Parse simple path data (x,y pairs)
                drawAnnotation(context: context, annotation: annotation, size: size)
            }

            // Draw active stroke
            if activeDrawing.count >= 2 {
                var path = Path()
                path.move(to: activeDrawing[0])
                for point in activeDrawing.dropFirst() {
                    path.addLine(to: point)
                }
                context.stroke(
                    path,
                    with: .color(selectedColor),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .allowsHitTesting(false)  // Pass touches through for gesture handling
    }

    private func drawAnnotation(context: GraphicsContext, annotation: VideoAnnotation, size: CGSize) {
        let color = Color(hex: annotation.color)
        let points = parsePathData(annotation.pathData)
        guard points.count >= 2 else { return }

        var path = Path()
        path.move(to: points[0])
        for pt in points.dropFirst() {
            path.addLine(to: pt)
        }

        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: annotation.lineWidth, lineCap: .round, lineJoin: .round)
        )
    }

    private func parsePathData(_ data: String) -> [CGPoint] {
        let parts = data.split(separator: ";").compactMap { pair -> CGPoint? in
            let coords = pair.split(separator: ",")
            guard coords.count == 2,
                  let x = Double(coords[0]),
                  let y = Double(coords[1]) else { return nil }
            return CGPoint(x: x, y: y)
        }
        return parts
    }
}

// MARK: - Angle Protractor
struct AngleProtractorView: View {
    @Binding var point1: CGPoint
    @Binding var point2: CGPoint  // vertex
    @Binding var point3: CGPoint

    private var angle: Double {
        let ax = Double(point1.x - point2.x), ay = Double(point1.y - point2.y)
        let bx = Double(point3.x - point2.x), by = Double(point3.y - point2.y)
        let dot = ax * bx + ay * by
        let magA = sqrt(ax*ax + ay*ay), magB = sqrt(bx*bx + by*by)
        guard magA > 0, magB > 0 else { return 0 }
        return acos(max(-1, min(1, dot / (magA * magB)))) * 180 / .pi
    }

    var body: some View {
        Canvas { context, _ in
            // Draw lines from vertex to points
            var line1 = Path()
            line1.move(to: point2)
            line1.addLine(to: point1)
            context.stroke(line1, with: .color(.yellow), style: StrokeStyle(lineWidth: 2))

            var line2 = Path()
            line2.move(to: point2)
            line2.addLine(to: point3)
            context.stroke(line2, with: .color(.yellow), style: StrokeStyle(lineWidth: 2))

            // Handle circles
            for pt in [point1, point2, point3] {
                let rect = CGRect(x: pt.x - 6, y: pt.y - 6, width: 12, height: 12)
                context.fill(Circle().path(in: rect), with: .color(.yellow))
            }

            // Angle label
            let midX = (point2.x + point1.x + point3.x) / 3
            let midY = (point2.y + point1.y + point3.y) / 3
            let text = String(format: "%.1f°", angle)
            context.draw(
                Text(text)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow),
                at: CGPoint(x: midX, y: midY)
            )
        }
    }
}

// MARK: - Video Scrubber
struct VideoScrubberView: View {
    @Binding var progress: Double
    let duration: TimeInterval
    let thumbnails: [UIImage]

    var body: some View {
        VStack(spacing: 4) {
            // Thumbnail strip
            if !thumbnails.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(Array(thumbnails.enumerated()), id: \.offset) { i, thumb in
                            Image(uiImage: thumb)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 30)
                                .clipped()
                        }
                    }
                }
                .frame(height: 30)
                .overlay(
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.brandOrange)
                            .frame(width: 2)
                            .position(x: geo.size.width * progress, y: 15)
                    }
                )
            }

            Slider(value: $progress, in: 0...1)
                .tint(.brandOrange)
        }
    }
}
