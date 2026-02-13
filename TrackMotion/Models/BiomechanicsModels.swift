import Foundation
import CoreGraphics

// MARK: - Pose Landmarks (MediaPipe 33-point model)
enum PoseLandmark: Int, CaseIterable {
    case nose = 0
    case leftEyeInner, leftEye, leftEyeOuter
    case rightEyeInner, rightEye, rightEyeOuter
    case leftEar, rightEar
    case mouthLeft, mouthRight
    case leftShoulder, rightShoulder
    case leftElbow, rightElbow
    case leftWrist, rightWrist
    case leftPinky, rightPinky
    case leftIndex, rightIndex
    case leftThumb, rightThumb
    case leftHip, rightHip
    case leftKnee, rightKnee
    case leftAnkle, rightAnkle
    case leftHeel, rightHeel
    case leftFootIndex, rightFootIndex

    var displayName: String {
        switch self {
        case .nose: return "Nose"
        case .leftShoulder: return "L Shoulder"
        case .rightShoulder: return "R Shoulder"
        case .leftElbow: return "L Elbow"
        case .rightElbow: return "R Elbow"
        case .leftWrist: return "L Wrist"
        case .rightWrist: return "R Wrist"
        case .leftHip: return "L Hip"
        case .rightHip: return "R Hip"
        case .leftKnee: return "L Knee"
        case .rightKnee: return "R Knee"
        case .leftAnkle: return "L Ankle"
        case .rightAnkle: return "R Ankle"
        case .leftHeel: return "L Heel"
        case .rightHeel: return "R Heel"
        default: return "Landmark \(rawValue)"
        }
    }
}

// MARK: - Pose Keypoint
struct PoseKeypoint: Codable {
    var landmark: Int
    var position: CGPoint
    var confidence: Float
    var visibility: Float

    var isVisible: Bool { visibility > 0.5 && confidence > 0.5 }
}

// MARK: - Sprint Phase
enum SprintPhase: String, Codable, CaseIterable {
    case blockSet       = "Block Set"
    case blockStart     = "Block Start"
    case drivePhase     = "Drive Phase"
    case acceleration   = "Acceleration"
    case maxVelocity    = "Max Velocity"
    case speedEndurance = "Speed Endurance"
    case deceleration   = "Deceleration"
    case unknown        = "Unknown"

    var color: String {
        switch self {
        case .blockSet:       return "#9B59B6"
        case .blockStart:     return "#E74C3C"
        case .drivePhase:     return "#E67E22"
        case .acceleration:   return "#F39C12"
        case .maxVelocity:    return "#2ECC71"
        case .speedEndurance: return "#1AA7EC"
        case .deceleration:   return "#95A5A6"
        case .unknown:        return "#7F8C8D"
        }
    }

    var distanceRange: ClosedRange<Double>? {
        switch self {
        case .blockStart:     return 0...2
        case .drivePhase:     return 0...10
        case .acceleration:   return 0...30
        case .maxVelocity:    return 30...60
        case .speedEndurance: return 60...100
        default:              return nil
        }
    }

    var description: String {
        switch self {
        case .blockSet:       return "Athlete in set position"
        case .blockStart:     return "First 0-2 steps out of blocks"
        case .drivePhase:     return "0-10m drive phase"
        case .acceleration:   return "10-30m acceleration phase"
        case .maxVelocity:    return "30-60m maximum velocity"
        case .speedEndurance: return "60-100m speed endurance"
        case .deceleration:   return "Final deceleration"
        case .unknown:        return "Phase not determined"
        }
    }
}

struct SprintPhaseSegment: Codable, Identifiable {
    let id: UUID
    var phase: SprintPhase
    var startTime: TimeInterval
    var endTime: TimeInterval
    var startDistance: Double
    var endDistance: Double
    var averageVelocity: Double

    init(
        id: UUID = UUID(),
        phase: SprintPhase,
        startTime: TimeInterval,
        endTime: TimeInterval,
        startDistance: Double = 0,
        endDistance: Double = 0,
        averageVelocity: Double = 0
    ) {
        self.id = id
        self.phase = phase
        self.startTime = startTime
        self.endTime = endTime
        self.startDistance = startDistance
        self.endDistance = endDistance
        self.averageVelocity = averageVelocity
    }

    var duration: TimeInterval { endTime - startTime }
}

// MARK: - Block Angles
struct BlockAngles: Codable {
    var rearShinAngle: Double    // angle of rear leg shin relative to ground
    var frontShinAngle: Double   // angle of front leg shin relative to ground
    var rearThighAngle: Double
    var frontThighAngle: Double
    var hipHeight: Double        // normalized 0-1 relative to shoulder height
    var torsoLean: Double        // degrees from vertical
    var weightDistribution: Double // 0 = all rear, 1 = all front

    static let optimalRearShin: ClosedRange<Double>   = 35...50
    static let optimalFrontShin: ClosedRange<Double>  = 50...70
    static let optimalHipHeight: ClosedRange<Double>  = 0.55...0.75
    static let optimalTorsoLean: ClosedRange<Double>  = 35...50
}

// MARK: - Running Angles
struct RunningAngles: Codable {
    var kneeDriveAngle: Double          // max knee flexion angle during swing
    var trailingLegExtension: Double    // hip extension at toe-off
    var armSwingForward: Double         // elbow angle at max forward swing
    var armSwingBack: Double            // elbow angle at max backward swing
    var footStrikeAngle: Double         // ankle dorsiflexion at ground contact
    var hipFlexionAngle: Double
    var torsoAngle: Double              // forward lean during running

    // Symmetry
    var leftKneeDrive: Double
    var rightKneeDrive: Double
    var leftArmSwing: Double
    var rightArmSwing: Double

    var kneeDriveSymmetry: Double {
        abs(leftKneeDrive - rightKneeDrive)
    }

    var armSwingSymmetry: Double {
        abs(leftArmSwing - rightArmSwing)
    }

    static let optimalKneeDrive: ClosedRange<Double>         = 85...105
    static let optimalTrailingExtension: ClosedRange<Double> = 160...175
    static let optimalTorso: ClosedRange<Double>             = 75...90  // degrees from horizontal
    static let optimalFootStrike: ClosedRange<Double>        = (-5)...10
}

// MARK: - Posture Metrics
struct PostureMetrics: Codable {
    var headAlignment: Double       // degrees from vertical spine
    var shoulderRotation: Double    // cross-body shoulder rotation
    var hipDrop: Double             // pelvic tilt side-to-side
    var hipSymmetry: Double         // left vs right hip height diff
    var spineAlignment: Double      // lateral curvature
    var verticalOscillation: Double // cm of vertical movement per stride

    var overallPostureScore: Double {
        // Normalize each to 0-100 and average
        let headScore  = max(0, 100 - headAlignment * 5)
        let shoulderScore = max(0, 100 - shoulderRotation * 10)
        let hipScore   = max(0, 100 - hipDrop * 10)
        return (headScore + shoulderScore + hipScore) / 3
    }
}

// MARK: - Full Biomechanics Snapshot
struct BiomechanicsSnapshot: Codable, Identifiable {
    let id: UUID
    var timestamp: TimeInterval
    var frameIndex: Int
    var phase: SprintPhase
    var keypoints: [PoseKeypoint]

    // Calculated angles
    var blockAngles: BlockAngles?
    var runningAngles: RunningAngles
    var postureMetrics: PostureMetrics

    // Derived stride metrics
    var strideLength: Double?
    var strideFrequency: Double?
    var verticalOscillation: Double?
    var groundContactTime: Double?

    // Quality
    var formQualityScore: Double        // 0-100 from CoreML classifier
    var formQualityLabel: FormQuality
    var detectionConfidence: Double     // 0-1 pose detection confidence

    enum FormQuality: String, Codable {
        case excellent = "Excellent"
        case good      = "Good"
        case needsWork = "Needs Work"
        case poor      = "Poor"

        var color: String {
            switch self {
            case .excellent: return "#2ECC71"
            case .good:      return "#F39C12"
            case .needsWork: return "#E67E22"
            case .poor:      return "#E74C3C"
            }
        }

        static func from(score: Double) -> FormQuality {
            switch score {
            case 80...100: return .excellent
            case 60..<80:  return .good
            case 40..<60:  return .needsWork
            default:       return .poor
            }
        }
    }

    init(
        id: UUID = UUID(),
        timestamp: TimeInterval,
        frameIndex: Int,
        phase: SprintPhase = .unknown,
        keypoints: [PoseKeypoint] = [],
        blockAngles: BlockAngles? = nil,
        runningAngles: RunningAngles = RunningAngles(
            kneeDriveAngle: 0, trailingLegExtension: 0,
            armSwingForward: 0, armSwingBack: 0, footStrikeAngle: 0,
            hipFlexionAngle: 0, torsoAngle: 0,
            leftKneeDrive: 0, rightKneeDrive: 0,
            leftArmSwing: 0, rightArmSwing: 0
        ),
        postureMetrics: PostureMetrics = PostureMetrics(
            headAlignment: 0, shoulderRotation: 0, hipDrop: 0,
            hipSymmetry: 0, spineAlignment: 0, verticalOscillation: 0
        ),
        strideLength: Double? = nil,
        strideFrequency: Double? = nil,
        verticalOscillation: Double? = nil,
        groundContactTime: Double? = nil,
        formQualityScore: Double = 0,
        formQualityLabel: FormQuality = .needsWork,
        detectionConfidence: Double = 0
    ) {
        self.id = id
        self.timestamp = timestamp
        self.frameIndex = frameIndex
        self.phase = phase
        self.keypoints = keypoints
        self.blockAngles = blockAngles
        self.runningAngles = runningAngles
        self.postureMetrics = postureMetrics
        self.strideLength = strideLength
        self.strideFrequency = strideFrequency
        self.verticalOscillation = verticalOscillation
        self.groundContactTime = groundContactTime
        self.formQualityScore = formQualityScore
        self.formQualityLabel = formQualityLabel
        self.detectionConfidence = detectionConfidence
    }

    func keypoint(for landmark: PoseLandmark) -> PoseKeypoint? {
        keypoints.first { $0.landmark == landmark.rawValue }
    }
}

// MARK: - Form Score
struct FormScore: Codable {
    var overall: Double          // 0-100
    var blockStart: Double       // 0-25
    var acceleration: Double     // 0-25
    var maxVelocity: Double      // 0-25
    var consistency: Double      // 0-25
    var breakdown: [MetricScore]

    init(
        overall: Double = 0,
        blockStart: Double = 0,
        acceleration: Double = 0,
        maxVelocity: Double = 0,
        consistency: Double = 0,
        breakdown: [MetricScore] = []
    ) {
        self.overall = overall
        self.blockStart = blockStart
        self.acceleration = acceleration
        self.maxVelocity = maxVelocity
        self.consistency = consistency
        self.breakdown = breakdown
    }

    var grade: String {
        switch overall {
        case 90...100: return "A+"
        case 80..<90:  return "A"
        case 70..<80:  return "B"
        case 60..<70:  return "C"
        case 50..<60:  return "D"
        default:       return "F"
        }
    }
}

struct MetricScore: Codable, Identifiable {
    let id: UUID
    var metricName: String
    var score: Double        // 0-100
    var weight: Double       // weighting factor
    var measuredValue: Double
    var optimalMin: Double
    var optimalMax: Double
    var unit: String
    var feedback: String

    init(
        id: UUID = UUID(),
        metricName: String,
        score: Double,
        weight: Double = 1.0,
        measuredValue: Double,
        optimalMin: Double,
        optimalMax: Double,
        unit: String = "°",
        feedback: String = ""
    ) {
        self.id = id
        self.metricName = metricName
        self.score = score
        self.weight = weight
        self.measuredValue = measuredValue
        self.optimalMin = optimalMin
        self.optimalMax = optimalMax
        self.unit = unit
        self.feedback = feedback
    }

    var isInOptimalRange: Bool {
        measuredValue >= optimalMin && measuredValue <= optimalMax
    }
}

// MARK: - Injury Risk
enum RiskSeverity: String, Codable {
    case low    = "Low"
    case medium = "Medium"
    case high   = "High"

    var color: String {
        switch self {
        case .low:    return "#2ECC71"
        case .medium: return "#F39C12"
        case .high:   return "#E74C3C"
        }
    }
}

struct InjuryRiskFlag: Codable, Identifiable {
    let id: UUID
    var timestamp: TimeInterval
    var severity: RiskSeverity
    var bodyPart: String
    var issue: String
    var description: String
    var recommendation: String

    init(
        id: UUID = UUID(),
        timestamp: TimeInterval,
        severity: RiskSeverity,
        bodyPart: String,
        issue: String,
        description: String,
        recommendation: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.severity = severity
        self.bodyPart = bodyPart
        self.issue = issue
        self.description = description
        self.recommendation = recommendation
    }
}
