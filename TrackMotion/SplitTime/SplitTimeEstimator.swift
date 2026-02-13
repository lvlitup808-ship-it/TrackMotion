import Foundation
import CoreGraphics

// MARK: - Split Time Estimator
/// Estimates 10m split times from video without timing gates
final class SplitTimeEstimator {
    static let shared = SplitTimeEstimator()
    private init() {}

    // MARK: - Calibration
    struct CalibrationData {
        var referencePoint1: CGPoint  // screen point 1
        var referencePoint2: CGPoint  // screen point 2
        var realWorldDistance: Double // meters between the two points
        var cameraAngle: Double       // estimated camera angle from horizontal (degrees)

        var pixelsPerMeter: Double {
            let dx = Double(referencePoint2.x - referencePoint1.x)
            let dy = Double(referencePoint2.y - referencePoint1.y)
            let pixelDist = sqrt(dx * dx + dy * dy)
            // Perspective correction: apply cosine of camera angle
            let angleRad = cameraAngle * Double.pi / 180
            let corrected = pixelDist * cos(angleRad)
            return corrected / realWorldDistance
        }
    }

    var calibration: CalibrationData?

    // MARK: - Estimate Splits from Velocity Curve
    func estimateSplits(
        velocityCurve: [VelocityPoint],
        splitIntervalMeters: Double = 10.0
    ) -> [SplitTime] {
        guard !velocityCurve.isEmpty else { return [] }

        var splits: [SplitTime] = []
        var currentSplitStart: Double = 0
        var currentSplitStartTime: TimeInterval = velocityCurve.first!.timestamp

        for i in 1..<velocityCurve.count {
            let point = velocityCurve[i]

            if point.distanceMeters >= currentSplitStart + splitIntervalMeters {
                // Interpolate exact crossing time
                let prev = velocityCurve[i - 1]
                let targetDistance = currentSplitStart + splitIntervalMeters

                let fraction = (targetDistance - prev.distanceMeters) /
                               (point.distanceMeters - prev.distanceMeters)
                let crossingTime = prev.timestamp + fraction * (point.timestamp - prev.timestamp)

                let splitTime = crossingTime - currentSplitStartTime

                // Confidence based on velocity smoothness
                let velocityVariance = computeLocalVariance(curve: velocityCurve, around: i, window: 5)
                let confidence = max(0.5, 1.0 - velocityVariance / 5.0)

                splits.append(SplitTime(
                    startDistance: currentSplitStart,
                    endDistance: currentSplitStart + splitIntervalMeters,
                    time: splitTime,
                    confidence: confidence
                ))

                currentSplitStart += splitIntervalMeters
                currentSplitStartTime = crossingTime
            }
        }

        return splits
    }

    // MARK: - Velocity Statistics
    struct VelocityStats {
        var maxVelocity: Double
        var maxVelocityDistance: Double
        var maxVelocityTime: TimeInterval
        var averageVelocity: Double
        var timeToMaxVelocity: TimeInterval
        var velocityAtFinish: Double
        var accelerationPhaseLength: Double  // distance over which athlete accelerated
    }

    func computeStats(from curve: [VelocityPoint]) -> VelocityStats? {
        guard !curve.isEmpty else { return nil }

        let velocities = curve.map { $0.velocityMs }
        let maxVel = velocities.max() ?? 0
        let avgVel = velocities.reduce(0, +) / Double(velocities.count)

        guard let maxPoint = curve.first(where: { $0.velocityMs == maxVel }) else { return nil }

        // Find acceleration phase end (where velocity plateaus within 3% of max)
        let plateau = maxVel * 0.97
        let accelEnd = curve.first(where: { $0.velocityMs >= plateau })?.distanceMeters ?? maxPoint.distanceMeters

        return VelocityStats(
            maxVelocity: maxVel,
            maxVelocityDistance: maxPoint.distanceMeters,
            maxVelocityTime: maxPoint.timestamp - (curve.first?.timestamp ?? 0),
            averageVelocity: avgVel,
            timeToMaxVelocity: maxPoint.timestamp - (curve.first?.timestamp ?? 0),
            velocityAtFinish: curve.last?.velocityMs ?? 0,
            accelerationPhaseLength: accelEnd
        )
    }

    // MARK: - Compare to Theoretical Optimal Curve
    /// Returns what the velocity curve should look like for a given PR time
    func theoreticalCurve(for prTime100m: Double, resolution: Int = 50) -> [VelocityPoint] {
        // Model based on Bezier curve fitting typical world-class sprint profiles
        // Parameters calibrated from sprint science research
        let maxVelocity = 100 / prTime100m * 1.13  // peak is ~13% above average
        let timeToMax: Double = 6.0  // seconds to reach max velocity (varies by level)
        let distToMax: Double = 35   // meters to reach max velocity

        var curve: [VelocityPoint] = []
        let step = 100.0 / Double(resolution)

        for i in 0..<resolution {
            let dist = Double(i) * step
            let velocity: Double

            if dist < distToMax {
                // Acceleration phase: smooth S-curve
                let t = dist / distToMax
                velocity = maxVelocity * (3 * t * t - 2 * t * t * t)
            } else {
                // Speed endurance: gentle deceleration
                let t = (dist - distToMax) / (100 - distToMax)
                velocity = maxVelocity * (1 - 0.06 * t)
            }

            // Integrate to get time
            let time: TimeInterval
            if i == 0 {
                time = 0
            } else {
                let prevPoint = curve.last!
                let avgVel = (prevPoint.velocityMs + velocity) / 2
                time = prevPoint.timestamp + (step / avgVel)
            }

            curve.append(VelocityPoint(distanceMeters: dist, velocityMs: velocity, timestamp: time))
        }

        return curve
    }

    // MARK: - Helpers
    private func computeLocalVariance(curve: [VelocityPoint], around index: Int, window: Int) -> Double {
        let start = max(0, index - window / 2)
        let end   = min(curve.count - 1, index + window / 2)
        let window = Array(curve[start...end]).map { $0.velocityMs }
        return window.standardDeviation()
    }
}

// MARK: - Velocity Curve View
import SwiftUI
import Charts

struct VelocityCurveComparisonView: View {
    let actualCurve: [VelocityPoint]
    let optimalCurve: [VelocityPoint]
    let splits: [SplitTime]
    let stats: SplitTimeEstimator.VelocityStats?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Velocity Profile")
                .font(.headline)

            Chart {
                // Optimal curve (dashed)
                ForEach(optimalCurve) { point in
                    LineMark(
                        x: .value("Distance", point.distanceMeters),
                        y: .value("Speed", point.velocityMs)
                    )
                    .foregroundStyle(.formSuccess.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                }

                // Actual curve
                ForEach(actualCurve) { point in
                    LineMark(
                        x: .value("Distance", point.distanceMeters),
                        y: .value("Speed", point.velocityMs)
                    )
                    .foregroundStyle(Color.brandOrange)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Distance", point.distanceMeters),
                        y: .value("Speed", point.velocityMs)
                    )
                    .foregroundStyle(LinearGradient(
                        colors: [.brandOrange.opacity(0.3), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                }

                // Mark peak velocity
                if let peak = actualCurve.max(by: { $0.velocityMs < $1.velocityMs }) {
                    PointMark(
                        x: .value("Distance", peak.distanceMeters),
                        y: .value("Speed", peak.velocityMs)
                    )
                    .foregroundStyle(.white)
                    .symbolSize(60)
                    .annotation(position: .top) {
                        Text(String(format: "%.1f m/s", peak.velocityMs))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Color.brandOrange, in: Capsule())
                    }
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100]) {
                    AxisValueLabel()
                    AxisGridLine().foregroundStyle(.white.opacity(0.1))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel { Text("\(value.as(Double.self).map { String(format: "%.0f", $0) } ?? "")") }
                    AxisGridLine().foregroundStyle(.white.opacity(0.1))
                }
            }
            .chartYScale(domain: 0...13)
            .chartXAxisLabel("Distance (m)", alignment: .center)
            .chartYAxisLabel("Speed (m/s)")
            .chartLegend {
                HStack {
                    Rectangle()
                        .fill(Color.brandOrange)
                        .frame(width: 20, height: 3)
                    Text("Actual")
                        .font(.caption)

                    Rectangle()
                        .fill(Color.formSuccess.opacity(0.5))
                        .frame(width: 20, height: 3)
                        .background(
                            Rectangle()
                                .stroke(Color.formSuccess.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        )
                    Text("Target")
                        .font(.caption)
                }
            }

            // Stats grid
            if let stats {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    StatCard(
                        value: String(format: "%.1f", stats.maxVelocity),
                        unit: "m/s",
                        label: "Peak Speed"
                    )
                    StatCard(
                        value: String(format: "%.0f", stats.maxVelocityDistance),
                        unit: "m",
                        label: "Peak at"
                    )
                    StatCard(
                        value: String(format: "%.1f", stats.timeToMaxVelocity),
                        unit: "s",
                        label: "Time to Max"
                    )
                }
            }

            // Split times table
            if !splits.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Split Times")
                        .font(.subheadline.weight(.semibold))

                    ForEach(splits) { split in
                        HStack {
                            Text(split.displayLabel)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(split.formattedTime)
                                .font(.system(.subheadline, design: .monospaced).weight(.bold))
                                .foregroundStyle(.brandOrange)
                            Text("±\(String(format: "%.2f", (1 - split.confidence) * 0.1))s")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.backgroundSecondary, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct StatCard: View {
    let value: String
    let unit: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(.title3, design: .monospaced).weight(.bold))
                    .foregroundStyle(.brandOrange)
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(Color.backgroundPrimary, in: RoundedRectangle(cornerRadius: 10))
    }
}
