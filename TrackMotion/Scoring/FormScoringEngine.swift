import Foundation

// MARK: - Form Scoring Engine
/// Generates 0-100 composite form scores from biomechanics snapshots
final class FormScoringEngine {
    static let shared = FormScoringEngine()
    private init() {}

    // MARK: - Score Full Run
    func scoreRun(snapshots: [BiomechanicsSnapshot], phases: [SprintPhaseSegment]) -> FormScore {
        guard !snapshots.isEmpty else { return FormScore() }

        let blockSnapshots        = snapshots.filter { $0.phase == .blockStart || $0.phase == .blockSet }
        let accelerationSnapshots = snapshots.filter { $0.phase == .acceleration || $0.phase == .drivePhase }
        let maxVelSnapshots       = snapshots.filter { $0.phase == .maxVelocity }
        let allRunningSnapshots   = snapshots.filter { $0.phase != .blockSet }

        let blockScore        = scoreBlockPhase(snapshots: blockSnapshots)
        let accelerationScore = scoreAccelerationPhase(snapshots: accelerationSnapshots)
        let maxVelScore       = scoreMaxVelocityPhase(snapshots: maxVelSnapshots)
        let consistencyScore  = scoreConsistency(snapshots: allRunningSnapshots)

        let overall = blockScore + accelerationScore + maxVelScore + consistencyScore

        let breakdown = buildBreakdown(
            snapshots: snapshots,
            blockScore: blockScore,
            accelerationScore: accelerationScore,
            maxVelScore: maxVelScore,
            consistencyScore: consistencyScore
        )

        return FormScore(
            overall: min(100, overall),
            blockStart: blockScore,
            acceleration: accelerationScore,
            maxVelocity: maxVelScore,
            consistency: consistencyScore,
            breakdown: breakdown
        )
    }

    // MARK: - Block Phase Scoring (25 pts)
    private func scoreBlockPhase(snapshots: [BiomechanicsSnapshot]) -> Double {
        guard !snapshots.isEmpty else { return 12.5 } // neutral if no data
        let relevant = snapshots.compactMap { $0.blockAngles }
        guard !relevant.isEmpty else { return 12.5 }

        var score = 0.0
        let maxScore = 25.0

        // Rear shin angle (8 pts) - optimal: 35-50°
        let avgRearShin = relevant.map { $0.rearShinAngle }.average()
        score += 8.0 * rangeScore(value: avgRearShin, optimal: 35...50, tolerance: 15)

        // Front shin angle (7 pts) - optimal: 50-70°
        let avgFrontShin = relevant.map { $0.frontShinAngle }.average()
        score += 7.0 * rangeScore(value: avgFrontShin, optimal: 50...70, tolerance: 20)

        // Hip height (5 pts) - optimal: 0.55-0.75 normalized
        let avgHipHeight = relevant.map { $0.hipHeight }.average()
        score += 5.0 * rangeScore(value: avgHipHeight, optimal: 0.55...0.75, tolerance: 0.2)

        // Torso lean (5 pts) - optimal: 35-50°
        let avgTorso = relevant.map { $0.torsoLean }.average()
        score += 5.0 * rangeScore(value: avgTorso, optimal: 35...50, tolerance: 15)

        return min(maxScore, score)
    }

    // MARK: - Acceleration Phase Scoring (25 pts)
    private func scoreAccelerationPhase(snapshots: [BiomechanicsSnapshot]) -> Double {
        guard !snapshots.isEmpty else { return 12.5 }

        var score = 0.0

        // Forward lean progression (8 pts) - should decrease from 45° to ~80° upright
        let leanAngles = snapshots.map { $0.runningAngles.torsoAngle }
        let leanProgression = leanAngles.isEmpty ? 0.5 : assessProgression(values: leanAngles, shouldIncrease: true)
        score += 8.0 * leanProgression

        // Knee drive angle (8 pts) - optimal: 85-105°
        let kneeDrives = snapshots.map { $0.runningAngles.kneeDriveAngle }
        let avgKneeDrive = kneeDrives.average()
        score += 8.0 * rangeScore(value: avgKneeDrive, optimal: 85...105, tolerance: 20)

        // Arm mechanics (5 pts) - cross-body motion penalty
        let postureScores = snapshots.map { $0.postureMetrics.shoulderRotation }
        let avgShouldRot = postureScores.average()
        score += 5.0 * max(0, 1 - avgShouldRot / 15.0) // penalize >15° rotation

        // Step length progression (4 pts)
        let strideLengths = snapshots.compactMap { $0.strideLength }
        let strideProgression = strideLengths.isEmpty ? 0.5 : assessProgression(values: strideLengths, shouldIncrease: true)
        score += 4.0 * strideProgression

        return min(25, score)
    }

    // MARK: - Max Velocity Phase Scoring (25 pts)
    private func scoreMaxVelocityPhase(snapshots: [BiomechanicsSnapshot]) -> Double {
        guard !snapshots.isEmpty else { return 12.5 }

        var score = 0.0

        // Upright posture (7 pts) - optimal: 80-88° from horizontal
        let torsoAngles = snapshots.map { $0.runningAngles.torsoAngle }
        let avgTorso = torsoAngles.average()
        score += 7.0 * rangeScore(value: avgTorso, optimal: 80...88, tolerance: 10)

        // Knee drive (8 pts)
        let kneeDrives = snapshots.map { $0.runningAngles.kneeDriveAngle }
        let avgKneeDrive = kneeDrives.average()
        score += 8.0 * rangeScore(value: avgKneeDrive, optimal: 90...110, tolerance: 20)

        // Limb symmetry (6 pts)
        let symmetryScores = snapshots.map { $0.runningAngles.kneeDriveSymmetry }
        let avgAsymmetry = symmetryScores.average()
        score += 6.0 * max(0, 1 - avgAsymmetry / 10.0) // penalize >10° asymmetry

        // Foot strike (4 pts) - mid/forefoot preferred
        let footStrikes = snapshots.map { $0.runningAngles.footStrikeAngle }
        let avgFootStrike = footStrikes.average()
        score += 4.0 * rangeScore(value: avgFootStrike, optimal: (-5)...5, tolerance: 10)

        return min(25, score)
    }

    // MARK: - Consistency Scoring (25 pts)
    private func scoreConsistency(snapshots: [BiomechanicsSnapshot]) -> Double {
        guard snapshots.count > 5 else { return 12.5 }

        var score = 0.0

        // Form breakdown: compare first third vs last third of run
        let firstThird = Array(snapshots.prefix(snapshots.count / 3))
        let lastThird  = Array(snapshots.suffix(snapshots.count / 3))

        let firstKneeDrive = firstThird.map { $0.runningAngles.kneeDriveAngle }.average()
        let lastKneeDrive  = lastThird.map { $0.runningAngles.kneeDriveAngle }.average()
        let kneeDropPct = firstKneeDrive > 0
            ? abs(firstKneeDrive - lastKneeDrive) / firstKneeDrive
            : 0

        score += 10.0 * max(0, 1 - kneeDropPct * 5) // heavy penalty for >20% drop

        // Symmetry consistency (8 pts)
        let symScores = snapshots.map { $0.runningAngles.kneeDriveSymmetry }
        let avgSym = symScores.average()
        let symStdDev = symScores.standardDeviation()
        score += 8.0 * max(0, 1 - (avgSym + symStdDev) / 10.0)

        // Posture consistency (7 pts)
        let torsoAngles = snapshots.map { $0.runningAngles.torsoAngle }
        let torsoStdDev = torsoAngles.standardDeviation()
        score += 7.0 * max(0, 1 - torsoStdDev / 15.0)

        return min(25, score)
    }

    // MARK: - Detailed Breakdown
    private func buildBreakdown(
        snapshots: [BiomechanicsSnapshot],
        blockScore: Double,
        accelerationScore: Double,
        maxVelScore: Double,
        consistencyScore: Double
    ) -> [MetricScore] {
        var metrics: [MetricScore] = []

        // Add phase scores
        metrics.append(MetricScore(
            metricName: "Block Start",
            score: blockScore / 25 * 100,
            weight: 1.0,
            measuredValue: blockScore,
            optimalMin: 20,
            optimalMax: 25,
            unit: "pts",
            feedback: blockScore >= 20 ? "Excellent block position" : "Work on shin angles and hip height"
        ))

        metrics.append(MetricScore(
            metricName: "Acceleration",
            score: accelerationScore / 25 * 100,
            weight: 1.0,
            measuredValue: accelerationScore,
            optimalMin: 20,
            optimalMax: 25,
            unit: "pts",
            feedback: accelerationScore >= 20 ? "Strong acceleration phase" : "Focus on forward lean and knee drive"
        ))

        metrics.append(MetricScore(
            metricName: "Max Velocity",
            score: maxVelScore / 25 * 100,
            weight: 1.0,
            measuredValue: maxVelScore,
            optimalMin: 20,
            optimalMax: 25,
            unit: "pts",
            feedback: maxVelScore >= 20 ? "Excellent top-end form" : "Improve posture and turnover"
        ))

        metrics.append(MetricScore(
            metricName: "Consistency",
            score: consistencyScore / 25 * 100,
            weight: 1.0,
            measuredValue: consistencyScore,
            optimalMin: 20,
            optimalMax: 25,
            unit: "pts",
            feedback: consistencyScore >= 20 ? "Form held throughout" : "Form breaking down late in run"
        ))

        // Individual metric scores
        if !snapshots.isEmpty {
            let avgKneeDrive = snapshots.map { $0.runningAngles.kneeDriveAngle }.average()
            metrics.append(MetricScore(
                metricName: "Knee Drive",
                score: rangeScore(value: avgKneeDrive, optimal: 85...105, tolerance: 20) * 100,
                weight: 2.0,
                measuredValue: avgKneeDrive,
                optimalMin: 85,
                optimalMax: 105,
                unit: "°",
                feedback: avgKneeDrive >= 85 ? "Good knee drive height" : "Drive your knees higher"
            ))

            let avgSym = snapshots.map { $0.runningAngles.kneeDriveSymmetry }.average()
            metrics.append(MetricScore(
                metricName: "Symmetry",
                score: max(0, (1 - avgSym / 10.0)) * 100,
                weight: 1.5,
                measuredValue: avgSym,
                optimalMin: 0,
                optimalMax: 3,
                unit: "°",
                feedback: avgSym <= 3 ? "Good bilateral symmetry" : "Left/right imbalance detected"
            ))
        }

        return metrics
    }

    // MARK: - Scoring Helpers

    /// Returns 0-1 score for value within optimal range with gradual falloff
    private func rangeScore(value: Double, optimal: ClosedRange<Double>, tolerance: Double) -> Double {
        if optimal.contains(value) { return 1.0 }
        let deviation = value < optimal.lowerBound
            ? optimal.lowerBound - value
            : value - optimal.upperBound
        return max(0, 1.0 - deviation / tolerance)
    }

    /// Returns 0-1 score assessing whether values progress in the right direction
    private func assessProgression(values: [Double], shouldIncrease: Bool) -> Double {
        guard values.count >= 3 else { return 0.5 }
        let first = values.prefix(values.count / 2).average()
        let last  = values.suffix(values.count / 2).average()
        let diff  = last - first
        return shouldIncrease
            ? max(0, min(1, 0.5 + diff / 20.0))
            : max(0, min(1, 0.5 - diff / 20.0))
    }
}

// MARK: - Array Extensions for Statistics
extension Array where Element == Double {
    func average() -> Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }

    func standardDeviation() -> Double {
        guard count > 1 else { return 0 }
        let avg = average()
        let variance = map { pow($0 - avg, 2) }.reduce(0, +) / Double(count - 1)
        return sqrt(variance)
    }
}
