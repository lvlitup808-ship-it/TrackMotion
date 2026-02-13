import SwiftUI
import AVFoundation

struct RecordView: View {
    @StateObject private var viewModel = RecordViewModel()
    @EnvironmentObject var appState: AppState
    @State private var showingSettings = false
    @State private var showingAthleteSelector = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Camera preview
            CameraPreviewView(session: viewModel.captureSession)
                .ignoresSafeArea()

            // Skeleton overlay
            if viewModel.showSkeleton {
                SkeletonOverlayView(
                    poses: viewModel.currentPoses,
                    frameSize: viewModel.cameraFrameSize,
                    phaseDetector: viewModel.phaseDetector
                )
                .ignoresSafeArea()
            }

            // Real-time feedback overlays
            VStack(spacing: 0) {
                // Top bar
                topBar

                Spacer()

                // Side metrics panel
                HStack {
                    Spacer()
                    if viewModel.showMetricsPanel {
                        MetricsSidePanel(snapshot: viewModel.latestSnapshot)
                            .padding(.trailing, 12)
                    }
                }

                // Bottom controls
                bottomControls
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)

            // Phase indicator badge
            if viewModel.isRecording {
                VStack {
                    HStack {
                        PhaseBadgeView(phase: viewModel.currentPhase)
                        Spacer()
                    }
                    .padding(.top, 100)
                    .padding(.leading, 16)
                    Spacer()
                }
            }

            // Form quality meter
            if viewModel.isRecording {
                HStack {
                    FormQualityMeterView(score: viewModel.formQualityScore)
                        .padding(.leading, 16)
                    Spacer()
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }

            // Live feedback cue overlay
            if let cue = viewModel.activeFeedbackCue {
                VStack {
                    LiveCueOverlay(cue: cue)
                        .padding(.top, 160)
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            RecordSettingsSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showingAthleteSelector) {
            AthleteQuickSelectorView(selectedAthlete: $viewModel.selectedAthlete)
        }
        .onAppear { viewModel.startSession() }
        .onDisappear { viewModel.stopSession() }
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            // Athlete selector
            Button {
                showingAthleteSelector = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 22))
                    Text(viewModel.selectedAthlete?.name ?? "Select Athlete")
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
            }

            Spacer()

            HStack(spacing: 12) {
                // Grid overlay toggle
                Button {
                    viewModel.showGridOverlay.toggle()
                } label: {
                    Image(systemName: viewModel.showGridOverlay ? "grid" : "grid.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                }

                // Skeleton toggle
                Button {
                    viewModel.showSkeleton.toggle()
                } label: {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 20))
                        .foregroundStyle(viewModel.showSkeleton ? .brandOrange : .white)
                }

                // Metrics panel toggle
                Button {
                    viewModel.showMetricsPanel.toggle()
                } label: {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(viewModel.showMetricsPanel ? .brandOrange : .white)
                }

                // Settings
                Button { showingSettings = true } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    // MARK: - Bottom Controls
    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Camera controls row
            HStack(spacing: 32) {
                // Flip camera
                Button {
                    viewModel.flipCamera()
                } label: {
                    Image(systemName: "camera.rotate.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.white)
                }

                // Record button
                RecordButton(isRecording: viewModel.isRecording) {
                    if viewModel.isRecording {
                        viewModel.stopRecording()
                    } else {
                        viewModel.startRecording()
                    }
                }

                // Multi-person toggle
                Button {
                    viewModel.toggleMultiPersonMode()
                } label: {
                    Image(systemName: viewModel.multiPersonMode ? "person.2.fill" : "person.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(viewModel.multiPersonMode ? .brandOrange : .white)
                }
            }

            // Status info
            if viewModel.isRecording {
                HStack(spacing: 16) {
                    // Duration
                    Label(viewModel.recordingDurationFormatted, systemImage: "clock.fill")
                        .font(.system(.subheadline, design: .monospaced).weight(.medium))
                        .foregroundStyle(.white)

                    Divider()
                        .frame(height: 16)
                        .overlay(.white.opacity(0.5))

                    // Distance estimate
                    Label("\(Int(viewModel.estimatedDistance))m", systemImage: "figure.run")
                        .font(.system(.subheadline, design: .monospaced).weight(.medium))
                        .foregroundStyle(.white)

                    Divider()
                        .frame(height: 16)
                        .overlay(.white.opacity(0.5))

                    // Speed
                    Label(
                        String(format: "%.1f m/s", viewModel.currentVelocity),
                        systemImage: "speedometer"
                    )
                    .font(.system(.subheadline, design: .monospaced).weight(.medium))
                    .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }
}

// MARK: - Record Button
struct RecordButton: View {
    let isRecording: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(.white, lineWidth: 3)
                    .frame(width: 76, height: 76)

                if isRecording {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.formError)
                        .frame(width: 32, height: 32)
                } else {
                    Circle()
                        .fill(Color.formError)
                        .frame(width: 62, height: 62)
                }
            }
        }
        .scaleEffect(isRecording ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isRecording)
    }
}

// MARK: - Phase Badge
struct PhaseBadgeView: View {
    let phase: SprintPhase

    var body: some View {
        Text(phase.rawValue.uppercased())
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(hex: phase.color), in: Capsule())
            .shadow(radius: 4)
    }
}

// MARK: - Form Quality Meter (vertical bar on left side)
struct FormQualityMeterView: View {
    let score: Double  // 0-100

    private var meterColor: Color {
        switch score {
        case 80...100: return .formSuccess
        case 60..<80:  return .formWarning
        case 40..<60:  return .brandOrange
        default:       return .formError
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("\(Int(score))")
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .foregroundStyle(.white)

            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(meterColor)
                        .frame(height: geo.size.height * score / 100)
                }
            }
            .frame(width: 10, height: 100)

            Text("FORM")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Metrics Side Panel
struct MetricsSidePanel: View {
    let snapshot: BiomechanicsSnapshot?

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if let snap = snapshot {
                if let block = snap.blockAngles {
                    MetricRow(label: "Rear Shin", value: "\(Int(block.rearShinAngle))°",
                              isOptimal: BlockAngles.optimalRearShin.contains(block.rearShinAngle))
                    MetricRow(label: "Front Shin", value: "\(Int(block.frontShinAngle))°",
                              isOptimal: BlockAngles.optimalFrontShin.contains(block.frontShinAngle))
                }

                let ra = snap.runningAngles
                MetricRow(label: "Knee Drive", value: "\(Int(ra.kneeDriveAngle))°",
                          isOptimal: RunningAngles.optimalKneeDrive.contains(ra.kneeDriveAngle))
                MetricRow(label: "Torso", value: "\(Int(ra.torsoAngle))°",
                          isOptimal: RunningAngles.optimalTorso.contains(ra.torsoAngle))
                MetricRow(label: "Symmetry", value: "\(Int(ra.kneeDriveSymmetry))°",
                          isOptimal: ra.kneeDriveSymmetry <= 5)

                if let stride = snap.strideLength {
                    MetricRow(label: "Stride", value: String(format: "%.1fm", stride), isOptimal: stride >= 1.5)
                }
            } else {
                Text("Waiting for\npose detection...")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct MetricRow: View {
    let label: String
    let value: String
    let isOptimal: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(isOptimal ? .formSuccess : .formError)
        }
    }
}

// MARK: - Live Cue Overlay
struct LiveCueOverlay: View {
    let cue: CoachingCue
    @State private var opacity: Double = 0

    private var bgColor: Color {
        switch cue.priority {
        case .high:   return .formError
        case .medium: return .formWarning
        case .low:    return .formSuccess
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: cue.priority == .high ? "exclamationmark.circle.fill" : "info.circle.fill")
                .font(.title3)
            Text(cue.recommendation)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(bgColor.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.3)) { opacity = 1 }
            withAnimation(.easeOut(duration: 0.5).delay(2.5)) { opacity = 0 }
        }
    }
}

// MARK: - Skeleton Overlay
struct SkeletonOverlayView: View {
    let poses: [DetectedPose]
    let frameSize: CGSize
    let phaseDetector: SprintPhaseDetector

    // Skeleton connections (landmark index pairs)
    private let connections: [(PoseLandmark, PoseLandmark)] = [
        // Torso
        (.leftShoulder, .rightShoulder),
        (.leftShoulder, .leftHip),
        (.rightShoulder, .rightHip),
        (.leftHip, .rightHip),
        // Left arm
        (.leftShoulder, .leftElbow),
        (.leftElbow, .leftWrist),
        // Right arm
        (.rightShoulder, .rightElbow),
        (.rightElbow, .rightWrist),
        // Left leg
        (.leftHip, .leftKnee),
        (.leftKnee, .leftAnkle),
        (.leftAnkle, .leftHeel),
        // Right leg
        (.rightHip, .rightKnee),
        (.rightKnee, .rightAnkle),
        (.rightAnkle, .rightHeel),
        // Head
        (.nose, .leftShoulder),
        (.nose, .rightShoulder)
    ]

    private let athleteColors: [Color] = [
        .brandOrange, .accentBlue, .formSuccess, Color(hex: "#9B59B6")
    ]

    var body: some View {
        Canvas { context, size in
            for pose in poses {
                let color = athleteColors[pose.athleteIndex % athleteColors.count]

                // Draw connections
                for (landmarkA, landmarkB) in connections {
                    guard
                        let ptA = scaledPoint(pose: pose, landmark: landmarkA, size: size),
                        let ptB = scaledPoint(pose: pose, landmark: landmarkB, size: size)
                    else { continue }

                    var path = Path()
                    path.move(to: ptA)
                    path.addLine(to: ptB)
                    context.stroke(path, with: .color(color.opacity(0.85)),
                                   style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                }

                // Draw keypoints
                for kp in pose.keypoints where kp.isVisible {
                    let pt = CGPoint(
                        x: kp.position.x * size.width,
                        y: kp.position.y * size.height
                    )
                    let rect = CGRect(x: pt.x - 4, y: pt.y - 4, width: 8, height: 8)
                    context.fill(Circle().path(in: rect), with: .color(.white))
                    context.fill(Circle().path(in: rect.insetBy(dx: 1.5, dy: 1.5)), with: .color(color))
                }
            }
        }
    }

    private func scaledPoint(pose: DetectedPose, landmark: PoseLandmark, size: CGSize) -> CGPoint? {
        guard let kp = pose.keypoint(for: landmark), kp.isVisible else { return nil }
        return CGPoint(x: kp.position.x * size.width, y: kp.position.y * size.height)
    }
}

// MARK: - Camera Preview
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.session = session
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    class PreviewUIView: UIView {
        var session: AVCaptureSession? {
            didSet {
                guard let session else { return }
                videoLayer.session = session
            }
        }

        private lazy var videoLayer: AVCaptureVideoPreviewLayer = {
            let layer = AVCaptureVideoPreviewLayer()
            layer.videoGravity = .resizeAspectFill
            return layer
        }()

        override func layoutSubviews() {
            super.layoutSubviews()
            videoLayer.frame = bounds
            if videoLayer.superlayer == nil {
                self.layer.addSublayer(videoLayer)
            }
        }
    }
}

// MARK: - Athlete Quick Selector
struct AthleteQuickSelectorView: View {
    @Binding var selectedAthlete: AthleteProfile?
    @Environment(\.dismiss) var dismiss
    @StateObject private var store = AthleteStore.shared

    var body: some View {
        NavigationStack {
            List(store.athletes) { athlete in
                Button {
                    selectedAthlete = athlete
                    dismiss()
                } label: {
                    HStack {
                        Circle()
                            .fill(Color.brandOrange)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Text(athlete.name.prefix(2).uppercased())
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(athlete.name)
                                .font(.headline)
                            Text(athlete.primaryEvents.first?.displayName ?? "General")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if selectedAthlete?.id == athlete.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.brandOrange)
                        }
                    }
                }
                .tint(.primary)
            }
            .navigationTitle("Select Athlete")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Record Settings Sheet
struct RecordSettingsSheet: View {
    @ObservedObject var viewModel: RecordViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Analysis") {
                    Toggle("Voice Feedback", isOn: $viewModel.voiceFeedbackEnabled)
                    Toggle("Auto Phase Detection", isOn: $viewModel.autoPhaseDetection)
                    Toggle("Multi-Person Mode", isOn: $viewModel.multiPersonMode)
                    Toggle("Kalman Filtering", isOn: $viewModel.kalmanFilteringEnabled)

                    Picker("Frame Rate", selection: $viewModel.processingFrameRate) {
                        Text("10 fps").tag(10)
                        Text("15 fps").tag(15)
                        Text("30 fps").tag(30)
                    }
                }

                Section("Display") {
                    Toggle("Show Skeleton", isOn: $viewModel.showSkeleton)
                    Toggle("Show Metrics Panel", isOn: $viewModel.showMetricsPanel)
                    Toggle("Grid Overlay", isOn: $viewModel.showGridOverlay)
                    Toggle("Show Angles", isOn: $viewModel.showAngles)
                }

                Section("Video") {
                    Picker("Quality", selection: $viewModel.videoQuality) {
                        Text("720p").tag(AVCaptureSession.Preset.hd1280x720)
                        Text("1080p").tag(AVCaptureSession.Preset.hd1920x1080)
                        Text("4K").tag(AVCaptureSession.Preset.hd4K3840x2160)
                    }
                }
            }
            .navigationTitle("Recording Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
