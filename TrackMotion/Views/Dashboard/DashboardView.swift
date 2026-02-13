import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = DashboardViewModel()
    @State private var showingReport = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Athlete selector
                    athleteSelector

                    // Key metrics cards
                    metricsCardsRow

                    // Performance trend chart
                    performanceTrendChart

                    // Velocity curve chart (last run)
                    if let lastRun = viewModel.lastRun, !lastRun.velocityCurve.isEmpty {
                        velocityCurveChart(run: lastRun)
                    }

                    // Radar chart
                    radarChartSection

                    // Recent sessions
                    recentSessionsList

                    // Injury risk indicators
                    injuryRiskSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(Color.backgroundPrimary)
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingReport = true
                    } label: {
                        Label("Report", systemImage: "doc.text.fill")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    DateRangePicker(selection: $viewModel.dateRange)
                }
            }
        }
        .sheet(isPresented: $showingReport) {
            PDFReportView(athlete: viewModel.selectedAthlete)
        }
    }

    // MARK: - Athlete Selector
    private var athleteSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.athletes) { athlete in
                    AthleteChip(
                        athlete: athlete,
                        isSelected: viewModel.selectedAthlete?.id == athlete.id
                    ) {
                        viewModel.selectAthlete(athlete)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Key Metric Cards (4 across)
    private var metricsCardsRow: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2),
            spacing: 12
        ) {
            MetricCard(
                title: "Overall Score",
                value: String(format: "%.0f", viewModel.overallScore),
                unit: "/100",
                icon: "star.fill",
                color: .brandOrange,
                trend: viewModel.scoreTrend
            )
            MetricCard(
                title: "Best Run",
                value: String(format: "%.0f", viewModel.bestFormScore),
                unit: "pts",
                icon: "trophy.fill",
                color: .formSuccess,
                trend: nil
            )
            MetricCard(
                title: "Improvement",
                value: String(format: "%+.1f%%", viewModel.improvementPercent),
                unit: "",
                icon: "chart.line.uptrend.xyaxis",
                color: viewModel.improvementPercent >= 0 ? .formSuccess : .formError,
                trend: nil
            )
            MetricCard(
                title: "Sessions",
                value: "\(viewModel.totalSessions)",
                unit: "total",
                icon: "calendar.badge.checkmark",
                color: .accentBlue,
                trend: nil
            )
        }
    }

    // MARK: - Performance Trend Chart
    private var performanceTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Form Score Trend")
                .font(.headline)
                .foregroundStyle(.primary)

            if viewModel.formScoreTrend.isEmpty {
                emptyChartPlaceholder(message: "Record sessions to see trends")
            } else {
                Chart {
                    ForEach(viewModel.formScoreTrend, id: \.0) { date, score in
                        LineMark(
                            x: .value("Date", date),
                            y: .value("Score", score)
                        )
                        .foregroundStyle(Color.brandOrange)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Date", date),
                            y: .value("Score", score)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.brandOrange.opacity(0.3), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        PointMark(
                            x: .value("Date", date),
                            y: .value("Score", score)
                        )
                        .foregroundStyle(Color.brandOrange)
                        .symbolSize(40)
                    }

                    // Target line
                    RuleMark(y: .value("Target", 80))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(.formSuccess.opacity(0.5))
                        .annotation(position: .trailing) {
                            Text("Target")
                                .font(.caption2)
                                .foregroundStyle(.formSuccess)
                        }
                }
                .frame(height: 180)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) {
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel { Text("\(value.as(Int.self) ?? 0)") }
                        AxisGridLine()
                    }
                }
                .chartYScale(domain: 0...100)
            }
        }
        .padding(16)
        .background(Color.backgroundSecondary, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Velocity Curve Chart
    private func velocityCurveChart(run: SprintRun) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last Run — Velocity Curve")
                .font(.headline)

            Chart {
                ForEach(run.velocityCurve) { point in
                    LineMark(
                        x: .value("Distance (m)", point.distanceMeters),
                        y: .value("Speed (m/s)", point.velocityMs)
                    )
                    .foregroundStyle(Color.accentBlue)
                    .interpolationMethod(.catmullRom)
                }

                // Mark max velocity
                if let peak = run.velocityCurve.max(by: { $0.velocityMs < $1.velocityMs }) {
                    PointMark(
                        x: .value("Distance", peak.distanceMeters),
                        y: .value("Speed", peak.velocityMs)
                    )
                    .foregroundStyle(.formSuccess)
                    .symbolSize(80)
                    .annotation(position: .top) {
                        Text(String(format: "%.1f m/s", peak.velocityMs))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.formSuccess)
                    }
                }
            }
            .frame(height: 160)
            .chartXAxisLabel("Distance (m)", alignment: .center)
            .chartYAxisLabel("Speed (m/s)")
            .chartYScale(domain: 0...13)
        }
        .padding(16)
        .background(Color.backgroundSecondary, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Radar Chart
    private var radarChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Biomechanics Radar")
                .font(.headline)

            if let athlete = viewModel.selectedAthlete {
                BiomechanicsRadarChart(metrics: viewModel.radarMetrics)
                    .frame(height: 220)
            } else {
                emptyChartPlaceholder(message: "Select an athlete to view radar")
            }
        }
        .padding(16)
        .background(Color.backgroundSecondary, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Recent Sessions
    private var recentSessionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Sessions")
                    .font(.headline)
                Spacer()
                Button("See All") {}
                    .font(.subheadline)
                    .foregroundStyle(.brandOrange)
            }

            if viewModel.recentSessions.isEmpty {
                Text("No sessions yet. Record your first sprint!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(viewModel.recentSessions.prefix(5)) { session in
                    NavigationLink {
                        SessionDetailView(session: session)
                    } label: {
                        SessionRowView(session: session)
                    }
                    .tint(.primary)
                }
            }
        }
        .padding(16)
        .background(Color.backgroundSecondary, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Injury Risk Section
    private var injuryRiskSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .foregroundStyle(.formError)
                Text("Injury Risk Monitor")
                    .font(.headline)
            }

            if viewModel.injuryRiskFlags.isEmpty {
                HStack {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(.formSuccess)
                    Text("No injury risks detected in recent sessions")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(viewModel.injuryRiskFlags.prefix(3)) { flag in
                    InjuryRiskRow(flag: flag)
                }
            }
        }
        .padding(16)
        .background(Color.backgroundSecondary, in: RoundedRectangle(cornerRadius: 16))
    }

    private func emptyChartPlaceholder(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }
}

// MARK: - Supporting Views

struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    let trend: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(color)
                Spacer()
                if let trend {
                    Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption)
                        .foregroundStyle(trend >= 0 ? .formSuccess : .formError)
                }
            }

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color.backgroundSecondary, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct AthleteChip: View {
    let athlete: AthleteProfile
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(athlete.name)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.brandOrange : Color.backgroundSecondary,
                             in: Capsule())
        }
    }
}

struct SessionRowView: View {
    let session: TrainingSession

    var body: some View {
        HStack(spacing: 12) {
            // Score circle
            ZStack {
                Circle()
                    .stroke(scoreColor(session.overallScore), lineWidth: 2)
                    .frame(width: 44, height: 44)
                Text("\(Int(session.overallScore))")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .foregroundStyle(scoreColor(session.overallScore))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(session.displayDate)
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 8) {
                    Label(session.location.isEmpty ? "Unknown location" : session.location,
                          systemImage: "location.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.secondary)

                    Text("\(session.runs.count) runs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 80...100: return .formSuccess
        case 60..<80:  return .formWarning
        default:       return .formError
        }
    }
}

struct InjuryRiskRow: View {
    let flag: InjuryRiskFlag

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(hex: flag.severity.color))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(flag.issue)
                    .font(.subheadline.weight(.medium))
                Text(flag.recommendation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Text(flag.severity.rawValue)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color(hex: flag.severity.color))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Biomechanics Radar Chart
struct BiomechanicsRadarChart: View {
    let metrics: [RadarMetric]

    struct RadarMetric: Identifiable {
        let id = UUID()
        var name: String
        var value: Double  // 0-1 normalized
        var color: Color
    }

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2 - 30

            Canvas { context, size in
                guard metrics.count >= 3 else { return }

                let count = metrics.count
                let angleStep = 2 * Double.pi / Double(count)

                // Draw grid
                for level in stride(from: 0.2, through: 1.0, by: 0.2) {
                    var gridPath = Path()
                    for i in 0..<count {
                        let angle = Double(i) * angleStep - Double.pi / 2
                        let x = center.x + CGFloat(cos(angle) * radius * level)
                        let y = center.y + CGFloat(sin(angle) * radius * level)
                        if i == 0 { gridPath.move(to: CGPoint(x: x, y: y)) }
                        else { gridPath.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    gridPath.closeSubpath()
                    context.stroke(gridPath, with: .color(.white.opacity(0.1)), lineWidth: 1)
                }

                // Draw spokes
                for i in 0..<count {
                    let angle = Double(i) * angleStep - Double.pi / 2
                    var spokePath = Path()
                    spokePath.move(to: center)
                    spokePath.addLine(to: CGPoint(
                        x: center.x + CGFloat(cos(angle) * radius),
                        y: center.y + CGFloat(sin(angle) * radius)
                    ))
                    context.stroke(spokePath, with: .color(.white.opacity(0.15)), lineWidth: 1)
                }

                // Draw filled polygon
                var dataPath = Path()
                for (i, metric) in metrics.enumerated() {
                    let angle = Double(i) * angleStep - Double.pi / 2
                    let r = radius * CGFloat(metric.value)
                    let pt = CGPoint(
                        x: center.x + CGFloat(cos(angle)) * r,
                        y: center.y + CGFloat(sin(angle)) * r
                    )
                    if i == 0 { dataPath.move(to: pt) }
                    else { dataPath.addLine(to: pt) }
                }
                dataPath.closeSubpath()
                context.fill(dataPath, with: .color(Color.brandOrange.opacity(0.3)))
                context.stroke(dataPath, with: .color(Color.brandOrange), lineWidth: 2)
            }

            // Labels
            ForEach(Array(metrics.enumerated()), id: \.offset) { i, metric in
                let angle = Double(i) * (2 * Double.pi / Double(metrics.count)) - Double.pi / 2
                let labelRadius = radius + 22
                let x = center.x + CGFloat(cos(angle)) * labelRadius
                let y = center.y + CGFloat(sin(angle)) * labelRadius

                Text(metric.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .position(x: x, y: y)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Date Range Picker
struct DateRangePicker: View {
    @Binding var selection: DashboardViewModel.DateRange

    var body: some View {
        Menu {
            ForEach(DashboardViewModel.DateRange.allCases, id: \.self) { range in
                Button(range.displayName) { selection = range }
            }
        } label: {
            Label(selection.displayName, systemImage: "calendar")
                .font(.subheadline)
        }
    }
}
