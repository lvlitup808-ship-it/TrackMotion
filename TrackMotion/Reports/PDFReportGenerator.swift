import Foundation
import PDFKit
import UIKit
import Charts
import SwiftUI

// MARK: - PDF Report Generator
final class PDFReportGenerator {
    static let shared = PDFReportGenerator()
    private init() {}

    struct ReportConfig {
        var includeAnnotatedImages: Bool = true
        var includeSplitTimes: Bool = true
        var includeVelocityCurve: Bool = true
        var includeDrillSuggestions: Bool = true
        var coachNotes: String = ""
        var dateRange: DashboardViewModel.DateRange = .last30Days
    }

    // MARK: - Generate Report
    func generateReport(
        for athlete: AthleteProfile,
        sessions: [TrainingSession],
        config: ReportConfig = ReportConfig()
    ) -> Data? {
        let pdfMetaData: [String: Any] = [
            kCGPDFContextCreator as String: "TrackMotion",
            kCGPDFContextAuthor as String: "TrackMotion AI Coach",
            kCGPDFContextTitle as String: "\(athlete.name) — Sprint Analysis Report"
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData

        let pageWidth: CGFloat = 8.5 * 72    // Letter size
        let pageHeight: CGFloat = 11.0 * 72
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let margin: CGFloat = 54

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        return renderer.pdfData { context in
            // Page 1: Executive Summary
            context.beginPage()
            drawPage1(context: context,
                      pageRect: pageRect,
                      margin: margin,
                      athlete: athlete,
                      sessions: sessions)

            // Page 2: Detailed Metrics
            context.beginPage()
            drawPage2(context: context,
                      pageRect: pageRect,
                      margin: margin,
                      athlete: athlete,
                      sessions: sessions)

            // Page 3: Action Plan
            context.beginPage()
            drawPage3(context: context,
                      pageRect: pageRect,
                      margin: margin,
                      athlete: athlete,
                      sessions: sessions,
                      config: config)
        }
    }

    // MARK: - Page 1: Executive Summary
    private func drawPage1(
        context: UIGraphicsPDFRendererContext,
        pageRect: CGRect,
        margin: CGFloat,
        athlete: AthleteProfile,
        sessions: [TrainingSession]
    ) {
        let ctx = context.cgContext

        // Header background
        ctx.setFillColor(UIColor(Color.brandOrange).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: pageRect.width, height: 120))

        // App logo text
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        NSAttributedString(string: "TrackMotion", attributes: titleAttrs)
            .draw(at: CGPoint(x: margin, y: 30))

        let subtitleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.white.withAlphaComponent(0.8)
        ]
        NSAttributedString(string: "Sprint Analysis Report", attributes: subtitleAttrs)
            .draw(at: CGPoint(x: margin, y: 68))

        // Date
        let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .none)
        NSAttributedString(
            string: dateStr,
            attributes: [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.white.withAlphaComponent(0.7)
            ]
        ).draw(at: CGPoint(x: margin, y: 92))

        var y: CGFloat = 148

        // Athlete name
        drawText(athlete.name,
                 at: CGPoint(x: margin, y: y),
                 font: .systemFont(ofSize: 24, weight: .bold),
                 color: .label)
        y += 36

        // Events
        let eventsStr = athlete.primaryEvents.map { $0.displayName }.joined(separator: ", ")
        drawText("Events: \(eventsStr)",
                 at: CGPoint(x: margin, y: y),
                 font: .systemFont(ofSize: 14),
                 color: .secondaryLabel)
        y += 28

        // Score summary cards
        let cardW: CGFloat = (pageRect.width - 2 * margin - 48) / 4
        let scores = [
            ("Overall", athlete.overallScore, ""),
            ("Best Run", athlete.bestFormScore, ""),
            ("Sessions", Double(athlete.sessions.count), ""),
            ("Total Runs", Double(athlete.totalRuns), "")
        ]
        y += 10
        for (i, (label, value, _)) in scores.enumerated() {
            let cardX = margin + CGFloat(i) * (cardW + 16)
            drawScoreCard(label: label, value: Int(value), at: CGPoint(x: cardX, y: y),
                          size: CGSize(width: cardW, height: 80), ctx: ctx)
        }
        y += 104

        // Key improvements / declines
        drawText("Summary",
                 at: CGPoint(x: margin, y: y),
                 font: .systemFont(ofSize: 18, weight: .semibold),
                 color: .label)
        y += 28

        let allRuns = sessions.flatMap { $0.runs }
        let avgScore = allRuns.isEmpty ? 0 : allRuns.map { $0.formScore.overall }.reduce(0, +) / Double(allRuns.count)

        let bullets = [
            "Overall average form score: \(String(format: "%.0f", avgScore))/100",
            "Total training sessions analyzed: \(sessions.count)",
            "Best form score achieved: \(String(format: "%.0f", athlete.bestFormScore))/100",
            "Primary focus areas: \(sessions.flatMap { $0.focusAreas }.map { $0.rawValue }.prefix(3).joined(separator: ", "))"
        ]

        for bullet in bullets {
            drawBullet(bullet, at: CGPoint(x: margin, y: y), ctx: ctx)
            y += 24
        }

        y += 20

        // Top 3 priorities
        drawText("Top Priorities for Next Phase",
                 at: CGPoint(x: margin, y: y),
                 font: .systemFont(ofSize: 18, weight: .semibold),
                 color: .label)
        y += 28

        let latestRecs = sessions.sorted { $0.date > $1.date }
            .flatMap { $0.runs }.first?.aiRecommendations ?? []

        for (i, rec) in latestRecs.prefix(3).enumerated() {
            drawText("\(i + 1). \(rec.issue)",
                     at: CGPoint(x: margin, y: y),
                     font: .systemFont(ofSize: 13, weight: .medium),
                     color: .label)
            y += 20
            drawText("   → \(rec.recommendation)",
                     at: CGPoint(x: margin, y: y),
                     font: .systemFont(ofSize: 12),
                     color: .secondaryLabel)
            y += 24
        }
    }

    // MARK: - Page 2: Detailed Metrics
    private func drawPage2(
        context: UIGraphicsPDFRendererContext,
        pageRect: CGRect,
        margin: CGFloat,
        athlete: AthleteProfile,
        sessions: [TrainingSession]
    ) {
        var y: CGFloat = margin

        drawText("Detailed Metrics — Last 5 Sessions",
                 at: CGPoint(x: margin, y: y),
                 font: .systemFont(ofSize: 20, weight: .bold),
                 color: .label)
        y += 36

        // Table header
        let colWidths: [CGFloat] = [100, 70, 70, 70, 70, 70]
        let headers = ["Date", "Overall", "Blocks", "Accel.", "Max Vel.", "Consistency"]
        drawTableRow(headers, at: y, margin: margin, colWidths: colWidths,
                     isHeader: true, ctx: context.cgContext)
        y += 28

        // Table rows
        let recentSessions = sessions.sorted { $0.date > $1.date }.prefix(5)
        for session in recentSessions {
            let df = DateFormatter()
            df.dateFormat = "MM/dd/yy"
            let avgScore = session.overallScore
            let blockScore = session.runs.map { $0.formScore.blockStart }.average()
            let accelScore = session.runs.map { $0.formScore.acceleration }.average()
            let maxVelScore = session.runs.map { $0.formScore.maxVelocity }.average()
            let consistency = session.runs.map { $0.formScore.consistency }.average()

            let row = [
                df.string(from: session.date),
                "\(Int(avgScore))/100",
                "\(Int(blockScore))/25",
                "\(Int(accelScore))/25",
                "\(Int(maxVelScore))/25",
                "\(Int(consistency))/25"
            ]
            drawTableRow(row, at: y, margin: margin, colWidths: colWidths,
                         isHeader: false, ctx: context.cgContext)
            y += 24
        }

        y += 30

        // Metric breakdown table
        drawText("Key Angle Averages",
                 at: CGPoint(x: margin, y: y),
                 font: .systemFont(ofSize: 18, weight: .semibold),
                 color: .label)
        y += 28

        let allSnaps = sessions.flatMap { $0.runs.flatMap { $0.biomechanicsSnapshots } }

        if !allSnaps.isEmpty {
            let metrics: [(String, String, String, String)] = [
                ("Knee Drive", "\(Int(allSnaps.map { $0.runningAngles.kneeDriveAngle }.average()))°", "85-105°", allSnaps.map { $0.runningAngles.kneeDriveAngle }.average() >= 85 ? "✓" : "↑"),
                ("Torso Angle", "\(Int(allSnaps.map { $0.runningAngles.torsoAngle }.average()))°", "75-90°", "~"),
                ("Arm Swing Sym.", "\(Int(allSnaps.map { $0.runningAngles.armSwingSymmetry }.average()))°", "<5°", allSnaps.map { $0.runningAngles.armSwingSymmetry }.average() < 5 ? "✓" : "↑"),
                ("Hip Drop", "\(Int(allSnaps.map { $0.postureMetrics.hipDrop }.average()))°", "<5°", allSnaps.map { $0.postureMetrics.hipDrop }.average() < 5 ? "✓" : "↑")
            ]

            let metricCols: [CGFloat] = [150, 80, 80, 50]
            drawTableRow(["Metric", "Current", "Optimal", "Status"],
                         at: y, margin: margin, colWidths: metricCols,
                         isHeader: true, ctx: context.cgContext)
            y += 28

            for (name, current, optimal, status) in metrics {
                drawTableRow([name, current, optimal, status],
                             at: y, margin: margin, colWidths: metricCols,
                             isHeader: false, ctx: context.cgContext)
                y += 24
            }
        }
    }

    // MARK: - Page 3: Action Plan
    private func drawPage3(
        context: UIGraphicsPDFRendererContext,
        pageRect: CGRect,
        margin: CGFloat,
        athlete: AthleteProfile,
        sessions: [TrainingSession],
        config: ReportConfig
    ) {
        var y: CGFloat = margin

        drawText("Action Plan & Recommendations",
                 at: CGPoint(x: margin, y: y),
                 font: .systemFont(ofSize: 20, weight: .bold),
                 color: .label)
        y += 36

        // AI Recommendations
        let latestRecs = sessions.sorted { $0.date > $1.date }
            .flatMap { $0.runs }.first?.aiRecommendations ?? []

        for rec in latestRecs.prefix(4) {
            // Recommendation header
            let priorityColor: UIColor = rec.priority == .high ? .systemRed :
                                         rec.priority == .medium ? .systemOrange : .systemGreen
            context.cgContext.setFillColor(priorityColor.withAlphaComponent(0.1).cgColor)
            context.cgContext.fill(CGRect(x: margin, y: y, width: pageRect.width - 2 * margin, height: 88))

            drawText("[\(rec.priority.rawValue.uppercased())] \(rec.issue)",
                     at: CGPoint(x: margin + 8, y: y + 8),
                     font: .systemFont(ofSize: 13, weight: .semibold),
                     color: priorityColor)
            drawText(rec.recommendation,
                     at: CGPoint(x: margin + 8, y: y + 28),
                     font: .systemFont(ofSize: 12),
                     color: .label)

            let drillNames = DrillLibrary.shared.drills(for: rec.suggestedDrills)
                .map { $0.name }
                .joined(separator: " • ")
            drawText("Drills: \(drillNames)",
                     at: CGPoint(x: margin + 8, y: y + 52),
                     font: .systemFont(ofSize: 11),
                     color: .secondaryLabel)
            drawText("Estimated improvement: \(rec.estimatedImprovementWeeks) weeks",
                     at: CGPoint(x: margin + 8, y: y + 68),
                     font: .systemFont(ofSize: 11),
                     color: .secondaryLabel)
            y += 104
        }

        y += 20

        // Coach notes section
        drawText("Coach Notes",
                 at: CGPoint(x: margin, y: y),
                 font: .systemFont(ofSize: 18, weight: .semibold),
                 color: .label)
        y += 28

        let notesText = config.coachNotes.isEmpty ? "No additional notes added." : config.coachNotes
        context.cgContext.setStrokeColor(UIColor.separator.cgColor)
        context.cgContext.stroke(CGRect(x: margin, y: y, width: pageRect.width - 2 * margin, height: 120))
        drawText(notesText,
                 at: CGPoint(x: margin + 8, y: y + 8),
                 font: .systemFont(ofSize: 12),
                 color: .label)
        y += 140

        // Footer
        drawText("Generated by TrackMotion • \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))",
                 at: CGPoint(x: margin, y: pageRect.height - 40),
                 font: .systemFont(ofSize: 10),
                 color: .secondaryLabel)
    }

    // MARK: - Drawing Helpers
    private func drawText(_ text: String, at point: CGPoint, font: UIFont, color: UIColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        NSAttributedString(string: text, attributes: attrs).draw(at: point)
    }

    private func drawBullet(_ text: String, at point: CGPoint, ctx: CGContext) {
        drawText("•  \(text)",
                 at: CGPoint(x: point.x, y: point.y),
                 font: .systemFont(ofSize: 13),
                 color: .label)
    }

    private func drawScoreCard(label: String, value: Int, at point: CGPoint, size: CGSize, ctx: CGContext) {
        ctx.setFillColor(UIColor.secondarySystemBackground.cgColor)
        ctx.fill(CGRect(origin: point, size: size))

        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 28, weight: .bold),
            .foregroundColor: UIColor(Color.brandOrange)
        ]
        NSAttributedString(string: "\(value)", attributes: valueAttrs)
            .draw(at: CGPoint(x: point.x + 8, y: point.y + 12))

        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.secondaryLabel
        ]
        NSAttributedString(string: label, attributes: labelAttrs)
            .draw(at: CGPoint(x: point.x + 8, y: point.y + 54))
    }

    private func drawTableRow(_ values: [String], at y: CGFloat, margin: CGFloat,
                               colWidths: [CGFloat], isHeader: Bool, ctx: CGContext) {
        var x = margin
        let font: UIFont = isHeader
            ? .systemFont(ofSize: 12, weight: .semibold)
            : .systemFont(ofSize: 11)
        let color: UIColor = isHeader ? UIColor(Color.brandOrange) : .label

        if isHeader {
            ctx.setFillColor(UIColor(Color.brandOrange).withAlphaComponent(0.1).cgColor)
            let totalWidth = colWidths.reduce(0, +)
            ctx.fill(CGRect(x: margin, y: y - 4, width: totalWidth, height: 24))
        }

        for (i, value) in values.enumerated() {
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            NSAttributedString(string: value, attributes: attrs)
                .draw(at: CGPoint(x: x + 4, y: y))
            x += i < colWidths.count ? colWidths[i] : 70
        }
    }
}

// MARK: - PDF Report View (SwiftUI wrapper)
struct PDFReportView: View {
    let athlete: AthleteProfile?
    @Environment(\.dismiss) var dismiss
    @State private var coachNotes = ""
    @State private var pdfData: Data?
    @State private var isGenerating = false
    @State private var showingShareSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let athlete {
                    Form {
                        Section("Report Options") {
                            TextField("Add Coach Notes...", text: $coachNotes, axis: .vertical)
                                .lineLimit(4...8)
                        }

                        Section("Athlete") {
                            Label(athlete.name, systemImage: "person.fill")
                            Label("\(athlete.sessions.count) sessions", systemImage: "calendar")
                            Label("\(athlete.totalRuns) total runs", systemImage: "figure.run")
                        }
                    }

                    if isGenerating {
                        ProgressView("Generating Report...")
                            .padding()
                    }

                    Button {
                        generateReport(for: athlete)
                    } label: {
                        Label("Generate PDF Report", systemImage: "doc.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.brandOrange, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)
                    .disabled(isGenerating)
                } else {
                    Text("Select an athlete to generate a report")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Generate Report")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if pdfData != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Share") { showingShareSheet = true }
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let data = pdfData {
                ShareSheet(items: [data])
            }
        }
    }

    private func generateReport(for athlete: AthleteProfile) {
        isGenerating = true
        DispatchQueue.global(qos: .userInitiated).async {
            let config = PDFReportGenerator.ReportConfig(coachNotes: coachNotes)
            let data = PDFReportGenerator.shared.generateReport(
                for: athlete,
                sessions: athlete.sessions,
                config: config
            )
            DispatchQueue.main.async {
                pdfData = data
                isGenerating = false
                if data != nil { showingShareSheet = true }
            }
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
