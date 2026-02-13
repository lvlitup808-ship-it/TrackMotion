import Foundation

// MARK: - Injury Risk Detector
/// Anomaly detection for dangerous movement patterns using isolation-forest-inspired logic
final class InjuryRiskDetector {
    static let shared = InjuryRiskDetector()
    private init() {}

    // MARK: - Red Flag Thresholds
    private let asymmetryThreshold: Double = 5.0      // >5° knee drive difference
    private let overstrideThreshold: Double = 0.3      // normalized foot landing ahead of CoM
    private let rotationThreshold: Double = 10.0       // >10° shoulder rotation
    private let formDropThreshold: Double = 0.15       // >15% form degradation in final 20%

    // MARK: - Main Analysis Entry Point
    func analyze(snapshots: [BiomechanicsSnapshot]) -> [InjuryRiskFlag] {
        guard !snapshots.isEmpty else { return [] }

        var flags: [InjuryRiskFlag] = []

        flags.append(contentsOf: detectAsymmetry(snapshots: snapshots))
        flags.append(contentsOf: detectOverstriding(snapshots: snapshots))
        flags.append(contentsOf: detectExcessiveRotation(snapshots: snapshots))
        flags.append(contentsOf: detectFatigueMarkers(snapshots: snapshots))
        flags.append(contentsOf: detectHipDrop(snapshots: snapshots))

        return flags.sorted { $0.severity.rawValue > $1.severity.rawValue }
    }

    // MARK: - Asymmetry Detection
    private func detectAsymmetry(snapshots: [BiomechanicsSnapshot]) -> [InjuryRiskFlag] {
        let asymmetryValues = snapshots.map { $0.runningAngles.kneeDriveSymmetry }
        let avgAsymmetry = asymmetryValues.average()

        guard avgAsymmetry > asymmetryThreshold else { return [] }

        // Determine which side is weaker
        let leftAvg = snapshots.map { $0.runningAngles.leftKneeDrive }.average()
        let rightAvg = snapshots.map { $0.runningAngles.rightKneeDrive }.average()
        let weaker = leftAvg < rightAvg ? "left" : "right"

        let severity: RiskSeverity = avgAsymmetry > 10 ? .high : .medium
        let timestamp = snapshots.last?.timestamp ?? 0

        return [InjuryRiskFlag(
            timestamp: timestamp,
            severity: severity,
            bodyPart: "Knees / Hips",
            issue: "Bilateral Asymmetry (\(String(format: "%.1f", avgAsymmetry))° difference)",
            description: "The \(weaker) leg shows significantly lower knee drive than the right, indicating a strength or mobility imbalance.",
            recommendation: "Unilateral strength work (single-leg squats, SL RDLs). Consider physio assessment if persistent."
        )]
    }

    // MARK: - Overstriding Detection
    private func detectOverstriding(snapshots: [BiomechanicsSnapshot]) -> [InjuryRiskFlag] {
        // Overstride: foot landing too far ahead of center of mass
        // Approximated by checking if foot strike angle is excessive
        let footStrikeAngles = snapshots
            .filter { $0.phase == .maxVelocity || $0.phase == .speedEndurance }
            .map { $0.runningAngles.footStrikeAngle }

        guard !footStrikeAngles.isEmpty else { return [] }

        let avgFootStrike = footStrikeAngles.average()
        guard avgFootStrike > 15 else { return [] } // More than 15° dorsiflexion = overstriding

        let severity: RiskSeverity = avgFootStrike > 25 ? .high : .medium
        let timestamp = snapshots.last?.timestamp ?? 0

        return [InjuryRiskFlag(
            timestamp: timestamp,
            severity: severity,
            bodyPart: "Ankles / Hamstrings",
            issue: "Overstriding Detected (\(String(format: "%.0f", avgFootStrike))° foot strike angle)",
            description: "Foot is landing too far in front of the body's center of mass, creating a braking force and increasing hamstring strain risk.",
            recommendation: "Focus on landing under the hips. Use wicket runs to shorten ground contact. Strengthen hip flexors."
        )]
    }

    // MARK: - Excessive Rotation Detection
    private func detectExcessiveRotation(snapshots: [BiomechanicsSnapshot]) -> [InjuryRiskFlag] {
        let rotations = snapshots.map { $0.postureMetrics.shoulderRotation }
        let avgRotation = rotations.average()

        guard avgRotation > rotationThreshold else { return [] }

        let severity: RiskSeverity = avgRotation > 20 ? .high : .medium
        let timestamp = snapshots.last?.timestamp ?? 0

        return [InjuryRiskFlag(
            timestamp: timestamp,
            severity: severity,
            bodyPart: "Lower Back / Core",
            issue: "Excessive Trunk Rotation (\(String(format: "%.0f", avgRotation))°)",
            description: "Shoulders are rotating excessively across the body, indicating poor core stability and increasing lumbar spine stress.",
            recommendation: "Arm swing drills and seated arm mechanics. Core stability exercises (Pallof press, anti-rotation holds)."
        )]
    }

    // MARK: - Fatigue Markers (Form Breakdown in Final Section)
    private func detectFatigueMarkers(snapshots: [BiomechanicsSnapshot]) -> [InjuryRiskFlag] {
        guard snapshots.count > 10 else { return [] }

        let firstQuarter = Array(snapshots.prefix(snapshots.count / 4))
        let lastQuarter  = Array(snapshots.suffix(snapshots.count / 4))

        let firstKneeDrive = firstQuarter.map { $0.runningAngles.kneeDriveAngle }.average()
        let lastKneeDrive  = lastQuarter.map { $0.runningAngles.kneeDriveAngle }.average()

        guard firstKneeDrive > 0 else { return [] }
        let dropPercent = (firstKneeDrive - lastKneeDrive) / firstKneeDrive

        guard dropPercent > formDropThreshold else { return [] }

        let severity: RiskSeverity = dropPercent > 0.25 ? .high : .medium
        let timestamp = snapshots.last?.timestamp ?? 0

        return [InjuryRiskFlag(
            timestamp: timestamp,
            severity: severity,
            bodyPart: "General",
            issue: "Fatigue-Induced Form Breakdown (\(String(format: "%.0f", dropPercent * 100))% knee drive drop)",
            description: "Sprint mechanics deteriorate significantly in the final section, indicating inadequate speed endurance.",
            recommendation: "Incorporate speed endurance training. Ensure adequate recovery between sessions. Check training load this week."
        )]
    }

    // MARK: - Hip Drop Detection
    private func detectHipDrop(snapshots: [BiomechanicsSnapshot]) -> [InjuryRiskFlag] {
        let hipDrops = snapshots.map { $0.postureMetrics.hipDrop }
        let avgHipDrop = hipDrops.average()
        let maxHipDrop = hipDrops.max() ?? 0

        guard avgHipDrop > 5 || maxHipDrop > 8 else { return [] }

        let severity: RiskSeverity = maxHipDrop > 10 ? .high : .medium
        let timestamp = snapshots.last?.timestamp ?? 0

        return [InjuryRiskFlag(
            timestamp: timestamp,
            severity: severity,
            bodyPart: "Hip / IT Band / Knee",
            issue: "Hip Drop / Trendelenburg Sign (\(String(format: "%.0f", avgHipDrop))° average)",
            description: "Pelvis drops to the unsupported side during single-leg support phase, indicating weak hip abductors (glute medius). This increases IT band and patellofemoral stress.",
            recommendation: "Lateral band walks, clamshells, single-leg glute bridges. Consider physio assessment for IT band syndrome prevention."
        )]
    }
}

// MARK: - Multi-Person Tracker
final class MultiAthleteTracker {
    static let shared = MultiAthleteTracker()
    private init() {}

    private var trackers: [Int: TrackedAthlete] = [:]
    private var nextID: Int = 0
    private let iouThreshold: CGFloat = 0.3
    private let maxMissingFrames: Int = 15

    struct TrackedAthlete {
        var id: Int
        var boundingBox: CGRect
        var phaseDetector: SprintPhaseDetector
        var biomechanicsSnapshots: [BiomechanicsSnapshot]
        var missingFrames: Int
        var color: String

        static let colors = ["#FF6B35", "#1AA7EC", "#2ECC71", "#9B59B6"]
    }

    func update(detectedPoses: [DetectedPose], timestamp: TimeInterval) -> [Int: DetectedPose] {
        var assignments: [Int: DetectedPose] = [:]

        // Age trackers
        for id in trackers.keys {
            trackers[id]?.missingFrames += 1
        }

        // Remove stale trackers
        trackers = trackers.filter { $0.value.missingFrames < maxMissingFrames }

        // Match detections to trackers using IoU
        for pose in detectedPoses {
            var bestMatchID: Int?
            var bestIoU: CGFloat = iouThreshold

            for (id, tracker) in trackers {
                let iou = computeIoU(tracker.boundingBox, pose.boundingBox)
                if iou > bestIoU {
                    bestIoU = iou
                    bestMatchID = id
                }
            }

            if let matchID = bestMatchID {
                trackers[matchID]?.boundingBox = pose.boundingBox
                trackers[matchID]?.missingFrames = 0
                assignments[matchID] = pose
            } else {
                // New athlete
                let newID = nextID
                nextID += 1
                trackers[newID] = TrackedAthlete(
                    id: newID,
                    boundingBox: pose.boundingBox,
                    phaseDetector: SprintPhaseDetector(),
                    biomechanicsSnapshots: [],
                    missingFrames: 0,
                    color: TrackedAthlete.colors[newID % TrackedAthlete.colors.count]
                )
                assignments[newID] = pose
            }
        }

        return assignments
    }

    private func computeIoU(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let intersection = a.intersection(b)
        guard !intersection.isNull else { return 0 }
        let iArea = intersection.width * intersection.height
        let uArea = a.width * a.height + b.width * b.height - iArea
        return uArea > 0 ? iArea / uArea : 0
    }

    func reset() {
        trackers.removeAll()
        nextID = 0
    }
}
