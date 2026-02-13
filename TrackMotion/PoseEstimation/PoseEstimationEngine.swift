import Foundation
import AVFoundation
import Vision
import CoreImage
import CoreML
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Pose Estimation Protocol
protocol PoseEstimationDelegate: AnyObject {
    func poseEstimationEngine(
        _ engine: PoseEstimationEngine,
        didDetectPoses poses: [DetectedPose],
        in pixelBuffer: CVPixelBuffer,
        at timestamp: CMTime
    )
    func poseEstimationEngine(_ engine: PoseEstimationEngine, didFailWithError error: Error)
}

// MARK: - Detected Pose (multi-person capable)
struct DetectedPose: Identifiable {
    let id: UUID
    var athleteIndex: Int            // 0-based, stable across frames
    var keypoints: [PoseKeypoint]
    var boundingBox: CGRect
    var confidence: Float
    var trackingID: Int?             // for multi-person ID persistence

    init(
        id: UUID = UUID(),
        athleteIndex: Int,
        keypoints: [PoseKeypoint],
        boundingBox: CGRect,
        confidence: Float,
        trackingID: Int? = nil
    ) {
        self.id = id
        self.athleteIndex = athleteIndex
        self.keypoints = keypoints
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.trackingID = trackingID
    }

    func keypoint(for landmark: PoseLandmark) -> PoseKeypoint? {
        keypoints.first { $0.landmark == landmark.rawValue }
    }

    func position(of landmark: PoseLandmark) -> CGPoint? {
        guard let kp = keypoint(for: landmark), kp.isVisible else { return nil }
        return kp.position
    }
}

// MARK: - Pose Estimation Engine
final class PoseEstimationEngine: NSObject {
    weak var delegate: PoseEstimationDelegate?

    // Configuration
    var maxPersons: Int = 4
    var minimumConfidence: Float = 0.5
    var processingFrameRate: Int = 15     // Process every Nth frame for performance
    var useKalmanFiltering: Bool = true
    var enableMultiPerson: Bool = false

    // State
    private var frameCounter: Int = 0
    private var personTrackers: [Int: PersonTracker] = [:]
    private var nextTrackingID: Int = 0

    // Vision request
    private lazy var bodyPoseRequest: VNDetectHumanBodyPoseRequest = {
        let request = VNDetectHumanBodyPoseRequest()
        return request
    }()

    // Kalman filters per person per landmark
    private var kalmanFilters: [Int: [Int: KalmanFilter2D]] = [:]

    // MARK: - Public Interface
    func processFrame(_ pixelBuffer: CVPixelBuffer, at timestamp: CMTime) {
        frameCounter += 1
        guard frameCounter % max(1, Int(30 / processingFrameRate)) == 0 else { return }

        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            self?.runPoseEstimation(on: pixelBuffer, at: timestamp)
        }
    }

    func processVideoFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        processFrame(pixelBuffer, at: timestamp)
    }

    // MARK: - Vision-based Pose Estimation
    private func runPoseEstimation(on pixelBuffer: CVPixelBuffer, at timestamp: CMTime) {
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .up,
            options: [:]
        )

        do {
            try handler.perform([bodyPoseRequest])
            guard let observations = bodyPoseRequest.results else { return }

            var detectedPoses: [DetectedPose] = []
            let maxCount = min(observations.count, enableMultiPerson ? maxPersons : 1)

            for (index, observation) in observations.prefix(maxCount).enumerated() {
                guard observation.confidence >= minimumConfidence else { continue }

                if let pose = buildDetectedPose(
                    from: observation,
                    athleteIndex: index,
                    pixelBuffer: pixelBuffer
                ) {
                    let smoothedPose = useKalmanFiltering
                        ? applyKalmanFilter(to: pose)
                        : pose
                    detectedPoses.append(smoothedPose)
                }
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.delegate?.poseEstimationEngine(
                    self,
                    didDetectPoses: detectedPoses,
                    in: pixelBuffer,
                    at: timestamp
                )
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.delegate?.poseEstimationEngine(self, didFailWithError: error)
            }
        }
    }

    // MARK: - Build Detected Pose from Vision Observation
    private func buildDetectedPose(
        from observation: VNHumanBodyPoseObservation,
        athleteIndex: Int,
        pixelBuffer: CVPixelBuffer
    ) -> DetectedPose? {
        var keypoints: [PoseKeypoint] = []

        // Map Vision joint names to MediaPipe landmark indices
        let jointMappings: [(VNHumanBodyPoseObservation.JointName, PoseLandmark)] = [
            (.nose, .nose),
            (.leftEye, .leftEye),
            (.rightEye, .rightEye),
            (.leftEar, .leftEar),
            (.rightEar, .rightEar),
            (.leftShoulder, .leftShoulder),
            (.rightShoulder, .rightShoulder),
            (.leftElbow, .leftElbow),
            (.rightElbow, .rightElbow),
            (.leftWrist, .leftWrist),
            (.rightWrist, .rightWrist),
            (.leftHip, .leftHip),
            (.rightHip, .rightHip),
            (.leftKnee, .leftKnee),
            (.rightKnee, .rightKnee),
            (.leftAnkle, .leftAnkle),
            (.rightAnkle, .rightAnkle)
        ]

        var minX: CGFloat = 1, minY: CGFloat = 1, maxX: CGFloat = 0, maxY: CGFloat = 0

        for (jointName, landmark) in jointMappings {
            if let recognizedPoint = try? observation.recognizedPoint(jointName) {
                // Vision returns normalized coordinates (0-1), flip Y
                let x = recognizedPoint.location.x
                let y = 1 - recognizedPoint.location.y
                let confidence = recognizedPoint.confidence

                let keypoint = PoseKeypoint(
                    landmark: landmark.rawValue,
                    position: CGPoint(x: x, y: y),
                    confidence: confidence,
                    visibility: confidence
                )
                keypoints.append(keypoint)

                if confidence > 0.3 {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }

        guard keypoints.count >= 10 else { return nil }

        let boundingBox = CGRect(
            x: minX - 0.05,
            y: minY - 0.05,
            width: (maxX - minX) + 0.1,
            height: (maxY - minY) + 0.1
        )

        return DetectedPose(
            athleteIndex: athleteIndex,
            keypoints: keypoints,
            boundingBox: boundingBox,
            confidence: observation.confidence
        )
    }

    // MARK: - Kalman Filtering for Smooth Tracking
    private func applyKalmanFilter(to pose: DetectedPose) -> DetectedPose {
        let id = pose.athleteIndex

        if kalmanFilters[id] == nil {
            kalmanFilters[id] = [:]
        }

        var smoothedKeypoints = pose.keypoints

        for i in 0..<smoothedKeypoints.count {
            let landmarkID = smoothedKeypoints[i].landmark

            if kalmanFilters[id]![landmarkID] == nil {
                kalmanFilters[id]![landmarkID] = KalmanFilter2D()
            }

            let position = smoothedKeypoints[i].position
            let smoothed = kalmanFilters[id]![landmarkID]!.update(measurement: position)
            smoothedKeypoints[i] = PoseKeypoint(
                landmark: smoothedKeypoints[i].landmark,
                position: smoothed,
                confidence: smoothedKeypoints[i].confidence,
                visibility: smoothedKeypoints[i].visibility
            )
        }

        return DetectedPose(
            id: pose.id,
            athleteIndex: pose.athleteIndex,
            keypoints: smoothedKeypoints,
            boundingBox: pose.boundingBox,
            confidence: pose.confidence,
            trackingID: pose.trackingID
        )
    }
}

// MARK: - Person Tracker (maintains ID across frames)
final class PersonTracker {
    var trackingID: Int
    var lastSeenBoundingBox: CGRect
    var missingFrameCount: Int = 0

    init(trackingID: Int, boundingBox: CGRect) {
        self.trackingID = trackingID
        self.lastSeenBoundingBox = boundingBox
    }

    func iou(with box: CGRect) -> CGFloat {
        let intersection = lastSeenBoundingBox.intersection(box)
        guard !intersection.isNull else { return 0 }
        let intersectionArea = intersection.width * intersection.height
        let unionArea = lastSeenBoundingBox.width * lastSeenBoundingBox.height +
                        box.width * box.height - intersectionArea
        return unionArea > 0 ? intersectionArea / unionArea : 0
    }
}

// MARK: - Kalman Filter 2D (smooths noisy keypoint positions)
final class KalmanFilter2D {
    // State: [x, y, vx, vy]
    private var x: Double = 0, y: Double = 0
    private var vx: Double = 0, vy: Double = 0
    private var px: Double = 1, py: Double = 1
    private var pvx: Double = 1, pvy: Double = 1
    private let processNoise: Double = 0.01
    private let measurementNoise: Double = 0.05
    private var isInitialized: Bool = false

    func update(measurement: CGPoint) -> CGPoint {
        let mx = Double(measurement.x)
        let my = Double(measurement.y)

        if !isInitialized {
            x = mx; y = my
            isInitialized = true
            return measurement
        }

        // Predict
        let predX = x + vx
        let predY = y + vy
        let predPX = px + pvx + processNoise
        let predPY = py + pvy + processNoise

        // Update
        let kx = predPX / (predPX + measurementNoise)
        let ky = predPY / (predPY + measurementNoise)

        x = predX + kx * (mx - predX)
        y = predY + ky * (my - predY)
        vx = 0.8 * vx + 0.2 * (x - predX)
        vy = 0.8 * vy + 0.2 * (y - predY)
        px = (1 - kx) * predPX
        py = (1 - ky) * predPY

        return CGPoint(x: x, y: y)
    }

    func reset() {
        isInitialized = false
        x = 0; y = 0; vx = 0; vy = 0
        px = 1; py = 1; pvx = 1; pvy = 1
    }
}

// MARK: - Form Quality Classifier (CoreML wrapper)
final class FormQualityClassifier {
    static let shared = FormQualityClassifier()
    private var model: VNCoreMLModel?

    private init() {
        loadModel()
    }

    private func loadModel() {
        // Load custom CoreML model if available
        // Falls back to rule-based scoring if model not present
        if let modelURL = Bundle.main.url(forResource: "SprintFormClassifier", withExtension: "mlmodelc") {
            do {
                let mlModel = try MLModel(contentsOf: modelURL)
                model = try VNCoreMLModel(for: mlModel)
            } catch {
                print("CoreML model not available, using rule-based scoring: \(error)")
            }
        }
    }

    /// Classify form quality from biomechanical feature vector
    func classify(features: [Double]) -> (score: Double, label: BiomechanicsSnapshot.FormQuality) {
        // Feature-based scoring (used when CoreML model unavailable)
        // Features: [kneeDrive, torsoLean, armSwing, footStrike, symmetry, ...]
        guard features.count >= 5 else {
            return (50.0, .needsWork)
        }

        var score = 0.0
        var maxScore = 0.0

        // Knee drive (weight: 20)
        let kneeDrive = features[0]
        maxScore += 20
        if kneeDrive >= 85 && kneeDrive <= 105 {
            score += 20
        } else {
            let deviation = min(abs(kneeDrive - 95), 30) / 30
            score += 20 * (1 - deviation)
        }

        // Torso lean (weight: 15)
        let torso = features[1]
        maxScore += 15
        if torso >= 75 && torso <= 90 {
            score += 15
        } else {
            let deviation = min(abs(torso - 82.5), 30) / 30
            score += 15 * (1 - deviation)
        }

        // Arm swing (weight: 15)
        let armSwing = features[2]
        maxScore += 15
        if armSwing >= 50 && armSwing <= 80 {
            score += 15
        } else {
            let deviation = min(abs(armSwing - 65), 40) / 40
            score += 15 * (1 - deviation)
        }

        // Foot strike (weight: 25)
        let footStrike = features[3]
        maxScore += 25
        if footStrike >= -5 && footStrike <= 10 {
            score += 25
        } else {
            let deviation = min(abs(footStrike - 2.5), 20) / 20
            score += 25 * (1 - deviation)
        }

        // Symmetry (weight: 25)
        let symmetry = features[4]
        maxScore += 25
        let symmetryScore = max(0, 25 * (1 - symmetry / 10))
        score += symmetryScore

        let normalized = maxScore > 0 ? (score / maxScore) * 100 : 50
        let label = BiomechanicsSnapshot.FormQuality.from(score: normalized)
        return (normalized, label)
    }
}
