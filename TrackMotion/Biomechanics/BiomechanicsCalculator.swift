import Foundation
import CoreGraphics

// MARK: - Biomechanics Calculator
/// Computes all biomechanical angles and metrics from pose keypoints
final class BiomechanicsCalculator {
    static let shared = BiomechanicsCalculator()

    // Configuration
    var pixelsPerMeter: Double = 200    // calibrated by user
    var frameRate: Double = 30.0

    private init() {}

    // MARK: - Primary Entry Point
    func computeSnapshot(
        from pose: DetectedPose,
        previousPose: DetectedPose?,
        frameIndex: Int,
        timestamp: TimeInterval,
        phase: SprintPhase
    ) -> BiomechanicsSnapshot {
        let keypoints = pose.keypoints

        let blockAngles = phase == .blockStart || phase == .blockSet
            ? computeBlockAngles(from: keypoints)
            : nil
        let runningAngles = computeRunningAngles(from: keypoints)
        let postureMetrics = computePostureMetrics(from: keypoints)

        var strideLength: Double?
        var strideFrequency: Double?
        var verticalOscillation: Double?
        var groundContactTime: Double?

        if let prev = previousPose {
            strideLength = estimateStrideLength(current: keypoints, previous: prev.keypoints)
            strideFrequency = estimateStrideFrequency(current: keypoints, previous: prev.keypoints)
            verticalOscillation = estimateVerticalOscillation(current: keypoints, previous: prev.keypoints)
            groundContactTime = estimateGroundContactTime(current: keypoints, previous: prev.keypoints)
        }

        // Build feature vector for classifier
        let features = buildFeatureVector(
            runningAngles: runningAngles,
            postureMetrics: postureMetrics,
            blockAngles: blockAngles
        )
        let (qualityScore, qualityLabel) = FormQualityClassifier.shared.classify(features: features)

        return BiomechanicsSnapshot(
            timestamp: timestamp,
            frameIndex: frameIndex,
            phase: phase,
            keypoints: keypoints,
            blockAngles: blockAngles,
            runningAngles: runningAngles,
            postureMetrics: postureMetrics,
            strideLength: strideLength,
            strideFrequency: strideFrequency,
            verticalOscillation: verticalOscillation,
            groundContactTime: groundContactTime,
            formQualityScore: qualityScore,
            formQualityLabel: qualityLabel,
            detectionConfidence: Double(pose.confidence)
        )
    }

    // MARK: - Block Start Angles
    func computeBlockAngles(from keypoints: [PoseKeypoint]) -> BlockAngles? {
        guard
            let leftHip    = point(.leftHip, from: keypoints),
            let rightHip   = point(.rightHip, from: keypoints),
            let leftKnee   = point(.leftKnee, from: keypoints),
            let rightKnee  = point(.rightKnee, from: keypoints),
            let leftAnkle  = point(.leftAnkle, from: keypoints),
            let rightAnkle = point(.rightAnkle, from: keypoints),
            let leftShoulder  = point(.leftShoulder, from: keypoints),
            let rightShoulder = point(.rightShoulder, from: keypoints)
        else { return nil }

        let hipCenter = CGPoint(
            x: (leftHip.x + rightHip.x) / 2,
            y: (leftHip.y + rightHip.y) / 2
        )
        let shoulderCenter = CGPoint(
            x: (leftShoulder.x + rightShoulder.x) / 2,
            y: (leftShoulder.y + rightShoulder.y) / 2
        )

        // Determine front/rear leg based on horizontal position
        let leftIsForward = leftKnee.x > rightKnee.x

        let frontHip    = leftIsForward ? leftHip    : rightHip
        let rearHip     = leftIsForward ? rightHip   : leftHip
        let frontKnee   = leftIsForward ? leftKnee   : rightKnee
        let rearKnee    = leftIsForward ? rightKnee  : leftKnee
        let frontAnkle  = leftIsForward ? leftAnkle  : rightAnkle
        let rearAnkle   = leftIsForward ? rightAnkle : leftAnkle

        let rearShinAngle  = shinAngle(knee: rearKnee, ankle: rearAnkle)
        let frontShinAngle = shinAngle(knee: frontKnee, ankle: frontAnkle)

        let rearThighAngle  = thighAngle(hip: rearHip, knee: rearKnee)
        let frontThighAngle = thighAngle(hip: frontHip, knee: frontKnee)

        // Hip height relative to shoulder height (normalized)
        let torsoLength = abs(shoulderCenter.y - hipCenter.y)
        let hipFromGround = 1.0 - hipCenter.y  // assuming y=0 is ground
        let hipHeight = torsoLength > 0 ? hipFromGround / (torsoLength * 2) : 0.6

        // Torso lean angle
        let torsoLean = angle(
            from: hipCenter,
            to: shoulderCenter,
            referenceAngle: 90
        )

        // Simple weight distribution estimate (closer to front = more weight forward)
        let blockWidth = abs(frontAnkle.x - rearAnkle.x)
        let weightDist = blockWidth > 0
            ? Double(abs(hipCenter.x - rearAnkle.x) / blockWidth)
            : 0.5

        return BlockAngles(
            rearShinAngle: rearShinAngle,
            frontShinAngle: frontShinAngle,
            rearThighAngle: rearThighAngle,
            frontThighAngle: frontThighAngle,
            hipHeight: Double(hipHeight),
            torsoLean: torsoLean,
            weightDistribution: Double(weightDist)
        )
    }

    // MARK: - Running Angles
    func computeRunningAngles(from keypoints: [PoseKeypoint]) -> RunningAngles {
        let leftShoulder  = point(.leftShoulder, from: keypoints)
        let rightShoulder = point(.rightShoulder, from: keypoints)
        let leftElbow     = point(.leftElbow, from: keypoints)
        let rightElbow    = point(.rightElbow, from: keypoints)
        let leftWrist     = point(.leftWrist, from: keypoints)
        let rightWrist    = point(.rightWrist, from: keypoints)
        let leftHip       = point(.leftHip, from: keypoints)
        let rightHip      = point(.rightHip, from: keypoints)
        let leftKnee      = point(.leftKnee, from: keypoints)
        let rightKnee     = point(.rightKnee, from: keypoints)
        let leftAnkle     = point(.leftAnkle, from: keypoints)
        let rightAnkle    = point(.rightAnkle, from: keypoints)

        // Knee drive angles
        var leftKneeDrive: Double = 0
        var rightKneeDrive: Double = 0
        if let lh = leftHip, let lk = leftKnee, let la = leftAnkle {
            leftKneeDrive = jointAngle(a: lh, vertex: lk, b: la)
        }
        if let rh = rightHip, let rk = rightKnee, let ra = rightAnkle {
            rightKneeDrive = jointAngle(a: rh, vertex: rk, b: ra)
        }
        let kneeDriveAngle = max(leftKneeDrive, rightKneeDrive) // leading leg

        // Trailing leg extension
        var trailingLegExt: Double = 0
        let minKneeDriveLeg = leftKneeDrive < rightKneeDrive ? (leftHip, leftKnee, leftAnkle) : (rightHip, rightKnee, rightAnkle)
        if let h = minKneeDriveLeg.0, let k = minKneeDriveLeg.1, let a = minKneeDriveLeg.2 {
            trailingLegExt = jointAngle(a: h, vertex: k, b: a)
        }

        // Arm swing angles
        var leftArmSwing: Double = 0
        var rightArmSwing: Double = 0
        if let ls = leftShoulder, let le = leftElbow, let lw = leftWrist {
            leftArmSwing = jointAngle(a: ls, vertex: le, b: lw)
        }
        if let rs = rightShoulder, let re = rightElbow, let rw = rightWrist {
            rightArmSwing = jointAngle(a: rs, vertex: re, b: rw)
        }
        let armSwingForward = max(leftArmSwing, rightArmSwing)
        let armSwingBack    = min(leftArmSwing, rightArmSwing)

        // Hip flexion angle
        var hipFlexion: Double = 0
        if let ls = leftShoulder, let lh = leftHip, let lk = leftKnee {
            hipFlexion = jointAngle(a: ls, vertex: lh, b: lk)
        }

        // Torso angle relative to vertical
        var torsoAngle: Double = 85 // default upright
        if let ls = leftShoulder, let rs = rightShoulder, let lh = leftHip, let rh = rightHip {
            let shoulderMid = CGPoint(x: (ls.x + rs.x) / 2, y: (ls.y + rs.y) / 2)
            let hipMid = CGPoint(x: (lh.x + rh.x) / 2, y: (lh.y + rh.y) / 2)
            torsoAngle = vectorAngleFromVertical(from: hipMid, to: shoulderMid)
        }

        // Foot strike angle (ankle dorsiflexion approximation)
        var footStrikeAngle: Double = 0
        if let lk = leftKnee, let la = leftAnkle {
            footStrikeAngle = shinAngle(knee: lk, ankle: la) - 90
        }

        return RunningAngles(
            kneeDriveAngle: kneeDriveAngle,
            trailingLegExtension: trailingLegExt,
            armSwingForward: armSwingForward,
            armSwingBack: armSwingBack,
            footStrikeAngle: footStrikeAngle,
            hipFlexionAngle: hipFlexion,
            torsoAngle: torsoAngle,
            leftKneeDrive: leftKneeDrive,
            rightKneeDrive: rightKneeDrive,
            leftArmSwing: leftArmSwing,
            rightArmSwing: rightArmSwing
        )
    }

    // MARK: - Posture Metrics
    func computePostureMetrics(from keypoints: [PoseKeypoint]) -> PostureMetrics {
        let nose          = point(.nose, from: keypoints)
        let leftShoulder  = point(.leftShoulder, from: keypoints)
        let rightShoulder = point(.rightShoulder, from: keypoints)
        let leftHip       = point(.leftHip, from: keypoints)
        let rightHip      = point(.rightHip, from: keypoints)

        // Head alignment (deviation from spine axis)
        var headAlignment: Double = 0
        if let n = nose, let ls = leftShoulder, let rs = rightShoulder {
            let shoulderMid = CGPoint(x: (ls.x + rs.x) / 2, y: (ls.y + rs.y) / 2)
            headAlignment = Double(abs(n.x - shoulderMid.x)) * 100
        }

        // Shoulder rotation (cross-body tilt in degrees)
        var shoulderRotation: Double = 0
        if let ls = leftShoulder, let rs = rightShoulder {
            let dy = Double(rs.y - ls.y)
            let dx = Double(rs.x - ls.x)
            shoulderRotation = abs(atan2(dy, dx) * 180 / .pi)
        }

        // Hip drop (pelvic tilt)
        var hipDrop: Double = 0
        if let lh = leftHip, let rh = rightHip {
            let dy = Double(abs(rh.y - lh.y))
            let dx = Double(abs(rh.x - lh.x))
            hipDrop = dx > 0 ? atan2(dy, dx) * 180 / .pi : 0
        }

        // Hip symmetry (height difference normalized)
        var hipSymmetry: Double = 0
        if let lh = leftHip, let rh = rightHip {
            hipSymmetry = Double(abs(lh.y - rh.y)) * 100
        }

        // Spine alignment (lateral deviation)
        var spineAlignment: Double = 0
        if let ls = leftShoulder, let rs = rightShoulder, let lh = leftHip, let rh = rightHip {
            let shoulderMidX = (ls.x + rs.x) / 2
            let hipMidX = (lh.x + rh.x) / 2
            spineAlignment = Double(abs(shoulderMidX - hipMidX)) * 100
        }

        return PostureMetrics(
            headAlignment: headAlignment,
            shoulderRotation: shoulderRotation,
            hipDrop: hipDrop,
            hipSymmetry: hipSymmetry,
            spineAlignment: spineAlignment,
            verticalOscillation: 0 // Computed from multi-frame analysis
        )
    }

    // MARK: - Stride Metrics (requires two consecutive frames)
    func estimateStrideLength(current: [PoseKeypoint], previous: [PoseKeypoint]) -> Double? {
        guard
            let currAnkle = point(.leftAnkle, from: current) ?? point(.rightAnkle, from: current),
            let prevAnkle = point(.leftAnkle, from: previous) ?? point(.rightAnkle, from: previous)
        else { return nil }

        let dx = Double(currAnkle.x - prevAnkle.x)
        let dy = Double(currAnkle.y - prevAnkle.y)
        let pixelDist = sqrt(dx * dx + dy * dy)
        return pixelDist / pixelsPerMeter
    }

    func estimateStrideFrequency(current: [PoseKeypoint], previous: [PoseKeypoint]) -> Double? {
        // Simplified: estimate from ankle crossing events
        // Full implementation requires tracking ankle Y-position over multiple frames
        return nil  // Populated by PhaseDetectionEngine which has full history
    }

    func estimateVerticalOscillation(current: [PoseKeypoint], previous: [PoseKeypoint]) -> Double? {
        guard
            let currHip = point(.leftHip, from: current),
            let prevHip = point(.leftHip, from: previous)
        else { return nil }

        let dy = Double(abs(currHip.y - prevHip.y))
        return (dy / pixelsPerMeter) * 100  // convert to cm
    }

    func estimateGroundContactTime(current: [PoseKeypoint], previous: [PoseKeypoint]) -> Double? {
        // Requires ankle velocity tracking over multiple frames
        // Simplified version returns nil; PhaseDetectionEngine handles full computation
        return nil
    }

    // MARK: - Feature Vector for ML Classifier
    private func buildFeatureVector(
        runningAngles: RunningAngles,
        postureMetrics: PostureMetrics,
        blockAngles: BlockAngles?
    ) -> [Double] {
        var features: [Double] = []

        // Running form features
        features.append(runningAngles.kneeDriveAngle)
        features.append(runningAngles.torsoAngle)
        features.append(runningAngles.armSwingForward)
        features.append(runningAngles.footStrikeAngle)
        features.append(runningAngles.kneeDriveSymmetry)
        features.append(runningAngles.armSwingSymmetry)
        features.append(runningAngles.trailingLegExtension)
        features.append(runningAngles.hipFlexionAngle)

        // Posture features
        features.append(postureMetrics.headAlignment)
        features.append(postureMetrics.shoulderRotation)
        features.append(postureMetrics.hipDrop)
        features.append(postureMetrics.hipSymmetry)

        // Block angles (if available)
        if let ba = blockAngles {
            features.append(ba.rearShinAngle)
            features.append(ba.frontShinAngle)
            features.append(ba.torsoLean)
        }

        return features
    }

    // MARK: - Geometry Helpers

    /// Angle of shin relative to horizontal ground (0° = horizontal, 90° = vertical)
    private func shinAngle(knee: CGPoint, ankle: CGPoint) -> Double {
        let dx = Double(knee.x - ankle.x)
        let dy = Double(knee.y - ankle.y)
        return atan2(abs(dy), abs(dx)) * 180 / .pi
    }

    /// Angle of thigh relative to horizontal ground
    private func thighAngle(hip: CGPoint, knee: CGPoint) -> Double {
        let dx = Double(knee.x - hip.x)
        let dy = Double(knee.y - hip.y)
        return atan2(abs(dy), abs(dx)) * 180 / .pi
    }

    /// 3-point joint angle at vertex (0-180°)
    func jointAngle(a: CGPoint, vertex: CGPoint, b: CGPoint) -> Double {
        let ax = Double(a.x - vertex.x), ay = Double(a.y - vertex.y)
        let bx = Double(b.x - vertex.x), by = Double(b.y - vertex.y)
        let dot = ax * bx + ay * by
        let magA = sqrt(ax * ax + ay * ay)
        let magB = sqrt(bx * bx + by * by)
        guard magA > 0, magB > 0 else { return 0 }
        let cosTheta = max(-1, min(1, dot / (magA * magB)))
        return acos(cosTheta) * 180 / .pi
    }

    /// Angle between two points relative to vertical axis
    private func angle(from p1: CGPoint, to p2: CGPoint, referenceAngle: Double) -> Double {
        let dx = Double(p2.x - p1.x)
        let dy = Double(p2.y - p1.y)
        return atan2(dx, dy) * 180 / .pi
    }

    /// Angle of vector from vertical (90° = horizontal, 0° = vertical)
    private func vectorAngleFromVertical(from p1: CGPoint, to p2: CGPoint) -> Double {
        let dx = Double(p2.x - p1.x)
        let dy = Double(p2.y - p1.y)
        let angleFromHoriz = atan2(abs(dy), abs(dx)) * 180 / .pi
        return angleFromHoriz
    }

    /// Extract CGPoint from keypoints array for a given landmark
    private func point(_ landmark: PoseLandmark, from keypoints: [PoseKeypoint]) -> CGPoint? {
        guard let kp = keypoints.first(where: { $0.landmark == landmark.rawValue }),
              kp.isVisible else { return nil }
        return kp.position
    }
}

// MARK: - Moving Average Filter for Velocity/Stride Smoothing
struct MovingAverageFilter {
    private let windowSize: Int
    private var buffer: [Double] = []

    init(windowSize: Int = 5) {
        self.windowSize = windowSize
    }

    mutating func update(_ value: Double) -> Double {
        buffer.append(value)
        if buffer.count > windowSize {
            buffer.removeFirst()
        }
        return buffer.reduce(0, +) / Double(buffer.count)
    }

    mutating func reset() {
        buffer.removeAll()
    }
}
