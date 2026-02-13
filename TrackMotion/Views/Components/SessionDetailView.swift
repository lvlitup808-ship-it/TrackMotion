import SwiftUI
import Charts

struct SessionDetailView: View {
    @ObservedObject var session: TrainingSession
    @State private var selectedRun: SprintRun?
    @State private var showingVideoAnalysis = false
    @State private var showingShareSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Session header
                sessionHeader

                // Runs list
                runsSection

                // Score breakdown chart
                if !session.runs.isEmpty {
                    scoreBreakdownChart
                }

                // Velocity curves
                if let bestRun = session.bestRun, !bestRun.velocityCurve.isEmpty {
                    bestRunVelocity(run: bestRun)
                }

                // Coach notes
                if !session.coachNotes.isEmpty {
                    coachNotesSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .navigationTitle("Session Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showingVideoAnalysis) {
            if let run = selectedRun {
                NavigationStack {
                    VideoAnalysisView(run: run)
                }
            }
        }
        .background(Color.backgroundPrimary)
    }

    // MARK: - Session Header
    private var sessionHeader: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.displayDate)
                        .font(.headline)
                    if !session.location.isEmpty {
                        Label(session.location, systemImage: "location.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Label(session.weather.rawValue, systemImage: session.weather.icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Overall session score
                ZStack {
                    Circle()
                        .stroke(scoreColor(session.overallScore), lineWidth: 4)
                        .frame(width: 70, height: 70)
                    VStack(spacing: 0) {
                        Text("\(Int(session.overallScore))")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(scoreColor(session.overallScore))
                        Text("SCORE")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Focus areas
            if !session.focusAreas.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(session.focusAreas, id: \.rawValue) { area in
                            Label(area.rawValue, systemImage: area.icon)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.brandOrange)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.brandOrange.opacity(0.15), in: Capsule())
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.backgroundSecondary, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Runs
    private var runsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Runs (\(session.runs.count))")
                .font(.headline)

            ForEach(Array(session.runs.enumerated()), id: \.element.id) { index, run in
                RunRowView(run: run, index: index + 1) {
                    selectedRun = run
                    showingVideoAnalysis = true
                }
            }
        }
        .padding(16)
        .background(Color.backgroundSecondary, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Score Breakdown Chart
    private var scoreBreakdownChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Score Breakdown")
                .font(.headline)

            Chart {
                ForEach(Array(session.runs.enumerated()), id: \.offset) { i, run in
                    BarMark(
                        x: .value("Run", "Run \(i + 1)"),
                        y: .value("Block", run.formScore.blockStart)
                    )
                    .foregroundStyle(by: .value("Phase", "Block Start"))

                    BarMark(
                        x: .value("Run", "Run \(i + 1)"),
                        y: .value("Accel", run.formScore.acceleration)
                    )
                    .foregroundStyle(by: .value("Phase", "Acceleration"))

                    BarMark(
                        x: .value("Run", "Run \(i + 1)"),
                        y: .value("MaxVel", run.formScore.maxVelocity)
                    )
                    .foregroundStyle(by: .value("Phase", "Max Velocity"))

                    BarMark(
                        x: .value("Run", "Run \(i + 1)"),
                        y: .value("Consistency", run.formScore.consistency)
                    )
                    .foregroundStyle(by: .value("Phase", "Consistency"))
                }
            }
            .chartForegroundStyleScale([
                "Block Start": Color.brandOrange,
                "Acceleration": Color.accentBlue,
                "Max Velocity": Color.formSuccess,
                "Consistency": Color.formWarning
            ])
            .frame(height: 180)
            .chartYScale(domain: 0...100)
        }
        .padding(16)
        .background(Color.backgroundSecondary, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Best Run Velocity
    private func bestRunVelocity(run: SprintRun) -> some View {
        let stats = SplitTimeEstimator.shared.computeStats(from: run.velocityCurve)
        let splits = SplitTimeEstimator.shared.estimateSplits(velocityCurve: run.velocityCurve)

        return VelocityCurveComparisonView(
            actualCurve: run.velocityCurve,
            optimalCurve: [],
            splits: splits,
            stats: stats
        )
    }

    // MARK: - Coach Notes
    private var coachNotesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Coach Notes", systemImage: "note.text")
                .font(.headline)
            Text(session.coachNotes)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.backgroundSecondary, in: RoundedRectangle(cornerRadius: 16))
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 80...100: return .formSuccess
        case 60..<80:  return .formWarning
        default:       return .formError
        }
    }
}

// MARK: - Run Row
struct RunRowView: View {
    let run: SprintRun
    let index: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Run number
                Text("#\(index)")
                    .font(.system(.subheadline, design: .monospaced).weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30)

                // Score arc
                ZStack {
                    Circle()
                        .stroke(scoreColor.opacity(0.3), lineWidth: 3)
                        .frame(width: 44, height: 44)
                    Circle()
                        .trim(from: 0, to: run.formScore.overall / 100)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(run.formScore.overall))")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(scoreColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(run.formScore.grade)
                        .font(.subheadline.weight(.semibold))

                    HStack(spacing: 8) {
                        Text(String(format: "%.1fs", run.duration))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if !run.injuryRiskFlags.isEmpty {
                            Label("\(run.injuryRiskFlags.count)", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.formWarning)
                        }
                    }
                }

                Spacer()

                // Phase indicators
                HStack(spacing: 4) {
                    ForEach(run.detectedPhases.prefix(4)) { phase in
                        Circle()
                            .fill(Color(hex: phase.phase.color))
                            .frame(width: 8, height: 8)
                    }
                }

                Image(systemName: "play.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.brandOrange)
            }
            .padding(.vertical, 4)
        }
        .tint(.primary)
    }

    private var scoreColor: Color {
        switch run.formScore.overall {
        case 80...100: return .formSuccess
        case 60..<80:  return .formWarning
        default:       return .formError
        }
    }
}
