import Foundation
import CoreGraphics

// MARK: - Sprint Phase Detector
/// Automatically classifies the current sprint phase based on pose history and velocity
final class SprintPhaseDetector {
    // State
    private var poseHistory: [TimestampedPose] = []
    private var velocityHistory: [Double] = []
    private var stepCount: Int = 0
    private var estimatedDistance: Double = 0
    private var maxVelocity: Double = 0
    private var lastStepTimestamp: TimeInterval = 0
    private var leftAnkleHistory: [TimestampedPoint] = []
    private var rightAnkleHistory: [TimestampedPoint] = []

    // Configuration
    var pixelsPerMeter: Double = 200
    var frameRate: Double = 30
    private let historyCapacity = 90  // 3 seconds at 30fps
    private var velocityFilter = MovingAverageFilter(windowSize: 5)

    // State
    var currentPhase: SprintPhase = .unknown
    var currentStepCount: Int = 0
    var estimatedDistanceMeters: Double = 0
    var currentVelocityMs: Double = 0
    var detectedPhaseSegments: [SprintPhaseSegment] = []
    var strideFrequencyHz: Double = 0
    var groundContactTimeMs: Double = 0

    private var currentSegmentStart: TimeInterval = 0
    private var currentSegmentPhase: SprintPhase = .unknown

    // MARK: - Structs
    struct TimestampedPose {
        var pose: DetectedPose
        var timestamp: TimeInterval
    }

    struct TimestampedPoint {
        var point: CGPoint
        var timestamp: TimeInterval
        var isGrounded: Bool
    }

    // MARK: - Main Update
    func update(pose: DetectedPose, timestamp: TimeInterval) -> SprintPhase {
        poseHistory.append(TimestampedPose(pose: pose, timestamp: timestamp))
        if poseHistory.count > historyCapacity {
            poseHistory.removeFirst()
        }

        updateAnkleHistory(pose: pose, timestamp: timestamp)
        updateStepCount()
        updateVelocity(pose: pose, timestamp: timestamp)
        updateStrideFrequency()

        let newPhase = classifyPhase()

        if newPhase != currentSegmentPhase {
            // Close previous segment
            if currentSegmentPhase != .unknown {
                let segment = SprintPhaseSegment(
                    phase: currentSegmentPhase,
                    startTime: currentSegmentStart,
                    endTime: timestamp,
                    startDistance: max(0, estimatedDistance - currentVelocityMs * (timestamp - currentSegmentStart)),
                    endDistance: estimatedDistance,
                    averageVelocity: currentVelocityMs
                )
                detectedPhaseSegments.append(segment)
            }
            currentSegmentPhase = newPhase
            currentSegmentStart = timestamp
        }

        currentPhase = newPhase
        currentStepCount = stepCount
        estimatedDistanceMeters = estimatedDistance

        return newPhase
    }

    // MARK: - Phase Classification
    private func classifyPhase() -> SprintPhase {
        // Initial state: no movement detected
        guard !poseHistory.isEmpty else { return .unknown }

        // Check for block set (very low velocity, specific body position)
        if currentVelocityMs < 0.3 && stepCount == 0 {
            return isInBlockPosition() ? .blockSet : .unknown
        }

        // Block start: first 2 steps, very low forward distance
        if stepCount <= 2 && estimatedDistance < 3 {
            return .blockStart
        }

        // Drive phase: steps 3-8, distance 3-10m
        if estimatedDistance < 10 && stepCount <= 8 {
            return .drivePhase
        }

        // Acceleration: 10-30m
        if estimatedDistance < 30 {
            return .acceleration
        }

        // Max velocity: 30-60m (highest velocity plateau)
        if estimatedDistance < 65 {
            // Confirm by checking velocity is near peak
            if currentVelocityMs >= maxVelocity * 0.93 {
                return .maxVelocity
            }
            return .acceleration
        }

        // Speed endurance: 60-100m
        if estimatedDistance < 100 {
            return .speedEndurance
        }

        // Deceleration: beyond 100m or velocity dropping significantly
        return .deceleration
    }

    private func isInBlockPosition() -> Bool {
        guard let latest = poseHistory.last else { return false }
        let pose = latest.pose

        // Check for low hip position and forward lean characteristic of blocks
        guard
            let hipY = pose.position(of: .leftHip)?.y ?? pose.position(of: .rightHip)?.y,
            let ankleY = pose.position(of: .leftAnkle)?.y ?? pose.position(of: .rightAnkle)?.y
        else { return false }

        let hipToAnkleRatio = Double(hipY) / Double(ankleY)
        return hipToAnkleRatio > 0.6 && hipToAnkleRatio < 0.85 // crouched position
    }

    // MARK: - Ankle Tracking for Step Detection
    private func updateAnkleHistory(pose: DetectedPose, timestamp: TimeInterval) {
        if let leftAnkle = pose.position(of: .leftAnkle) {
            let isGrounded = isAnkleGrounded(ankle: leftAnkle, hip: pose.position(of: .leftHip))
            leftAnkleHistory.append(TimestampedPoint(point: leftAnkle, timestamp: timestamp, isGrounded: isGrounded))
        }
        if let rightAnkle = pose.position(of: .rightAnkle) {
            let isGrounded = isAnkleGrounded(ankle: rightAnkle, hip: pose.position(of: .rightHip))
            rightAnkleHistory.append(TimestampedPoint(point: rightAnkle, timestamp: timestamp, isGrounded: isGrounded))
        }

        // Trim history
        let keepWindow: TimeInterval = 2.0
        leftAnkleHistory = leftAnkleHistory.filter { timestamp - $0.timestamp < keepWindow }
        rightAnkleHistory = rightAnkleHistory.filter { timestamp - $0.timestamp < keepWindow }
    }

    private func isAnkleGrounded(ankle: CGPoint?, hip: CGPoint?) -> Bool {
        guard let ankle, let hip else { return false }
        // In normalized coordinates, ankle near bottom (y near 1 if y increases downward)
        // and hip is higher (lower y value)
        return ankle.y > hip.y * 0.8
    }

    // MARK: - Step Count Detection
    private func updateStepCount() {
        // Detect zero-crossings in ankle Y-velocity (ankle lifts = step)
        guard leftAnkleHistory.count >= 3 else { return }

        let recent = Array(leftAnkleHistory.suffix(5))
        for i in 1..<recent.count - 1 {
            let prev = recent[i - 1]
            let curr = recent[i]
            let next = recent[i + 1]

            // Peak detection: ankle was rising (y decreasing in normalized coords) then falling
            let dy1 = Double(curr.point.y - prev.point.y)
            let dy2 = Double(next.point.y - curr.point.y)

            if dy1 < -0.02 && dy2 > 0.02 { // Local minimum in Y = ankle peak
                let now = curr.timestamp
                if now - lastStepTimestamp > 0.15 { // Minimum time between steps
                    stepCount += 1
                    lastStepTimestamp = now
                }
            }
        }
    }

    // MARK: - Velocity Estimation
    private func updateVelocity(pose: DetectedPose, timestamp: TimeInterval) {
        guard poseHistory.count >= 2 else { return }

        let prev = poseHistory[poseHistory.count - 2]
        let curr = poseHistory[poseHistory.count - 1]

        // Use hip position as proxy for center of mass
        guard
            let currHip = curr.pose.position(of: .leftHip) ?? curr.pose.position(of: .rightHip),
            let prevHip = prev.pose.position(of: .leftHip) ?? prev.pose.position(of: .rightHip)
        else { return }

        let dt = curr.timestamp - prev.timestamp
        guard dt > 0 else { return }

        let dx = Double(currHip.x - prevHip.x)
        let dy = Double(currHip.y - prevHip.y)
        let pixelDist = sqrt(dx * dx + dy * dy)
        let velocityPixelsPerSec = pixelDist / dt
        let velocityMs = velocityPixelsPerSec / pixelsPerMeter

        let smoothedVelocity = velocityFilter.update(velocityMs)
        currentVelocityMs = smoothedVelocity
        velocityHistory.append(smoothedVelocity)

        if smoothedVelocity > maxVelocity {
            maxVelocity = smoothedVelocity
        }

        // Integrate for distance
        estimatedDistance += smoothedVelocity * dt
    }

    // MARK: - Stride Frequency
    private func updateStrideFrequency() {
        guard poseHistory.count >= 2 else { return }

        // Use step count over time window
        let window: TimeInterval = 1.0
        let currentTime = poseHistory.last?.timestamp ?? 0
        let stepsInWindow = countStepsInWindow(window: window, currentTime: currentTime)

        strideFrequencyHz = stepsInWindow * 2 // steps/s → strides/s (2 steps = 1 stride)
    }

    private func countStepsInWindow(window: TimeInterval, currentTime: TimeInterval) -> Double {
        let windowStart = currentTime - window
        let leftSteps = leftAnkleHistory.filter {
            $0.timestamp >= windowStart && !$0.isGrounded
        }.count
        let rightSteps = rightAnkleHistory.filter {
            $0.timestamp >= windowStart && !$0.isGrounded
        }.count
        return Double(leftSteps + rightSteps) / window
    }

    // MARK: - Velocity Curve for Export
    func buildVelocityCurve() -> [VelocityPoint] {
        guard poseHistory.count >= 2 else { return [] }

        var points: [VelocityPoint] = []
        var runningDistance: Double = 0
        var localVelocityFilter = MovingAverageFilter(windowSize: 5)

        for i in 1..<poseHistory.count {
            let prev = poseHistory[i - 1]
            let curr = poseHistory[i]

            guard
                let currHip = curr.pose.position(of: .leftHip) ?? curr.pose.position(of: .rightHip),
                let prevHip = prev.pose.position(of: .leftHip) ?? prev.pose.position(of: .rightHip)
            else { continue }

            let dt = curr.timestamp - prev.timestamp
            guard dt > 0 else { continue }

            let dx = Double(currHip.x - prevHip.x)
            let dy = Double(currHip.y - prevHip.y)
            let pixelDist = sqrt(dx * dx + dy * dy)
            let rawVelocity = (pixelDist / pixelsPerMeter) / dt
            let smoothed = localVelocityFilter.update(rawVelocity)

            runningDistance += smoothed * dt

            points.append(VelocityPoint(
                distanceMeters: runningDistance,
                velocityMs: smoothed,
                timestamp: curr.timestamp
            ))
        }
        return points
    }

    // MARK: - Reset
    func reset() {
        poseHistory.removeAll()
        velocityHistory.removeAll()
        stepCount = 0
        estimatedDistance = 0
        maxVelocity = 0
        lastStepTimestamp = 0
        leftAnkleHistory.removeAll()
        rightAnkleHistory.removeAll()
        currentPhase = .unknown
        currentStepCount = 0
        estimatedDistanceMeters = 0
        currentVelocityMs = 0
        detectedPhaseSegments.removeAll()
        strideFrequencyHz = 0
        groundContactTimeMs = 0
        velocityFilter = MovingAverageFilter(windowSize: 5)
        currentSegmentStart = 0
        currentSegmentPhase = .unknown
    }
}
