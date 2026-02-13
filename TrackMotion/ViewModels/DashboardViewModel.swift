import Foundation
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var selectedAthlete: AthleteProfile?
    @Published var dateRange: DateRange = .last30Days
    @Published var formScoreTrend: [(Date, Double)] = []
    @Published var radarMetrics: [DashboardView.BiomechanicsRadarChart.RadarMetric] = []
    @Published var recentSessions: [TrainingSession] = []
    @Published var injuryRiskFlags: [InjuryRiskFlag] = []

    private var cancellables = Set<AnyCancellable>()
    private let store = AthleteStore.shared

    enum DateRange: String, CaseIterable {
        case last7Days   = "7D"
        case last30Days  = "30D"
        case last90Days  = "90D"
        case allTime     = "All"

        var displayName: String {
            switch self {
            case .last7Days:  return "Last 7 Days"
            case .last30Days: return "Last 30 Days"
            case .last90Days: return "Last 90 Days"
            case .allTime:    return "All Time"
            }
        }

        var startDate: Date {
            let cal = Calendar.current
            switch self {
            case .last7Days:  return cal.date(byAdding: .day, value: -7, to: Date())!
            case .last30Days: return cal.date(byAdding: .day, value: -30, to: Date())!
            case .last90Days: return cal.date(byAdding: .day, value: -90, to: Date())!
            case .allTime:    return Date.distantPast
            }
        }
    }

    var athletes: [AthleteProfile] { store.athletes }

    var overallScore: Double { selectedAthlete?.overallScore ?? 0 }
    var bestFormScore: Double { selectedAthlete?.bestFormScore ?? 0 }
    var totalSessions: Int { selectedAthlete?.sessions.count ?? 0 }

    var scoreTrend: Double {
        guard formScoreTrend.count >= 2 else { return 0 }
        return formScoreTrend.last!.1 - formScoreTrend.first!.1
    }

    var improvementPercent: Double {
        guard formScoreTrend.count >= 2, formScoreTrend.first!.1 > 0 else { return 0 }
        return (formScoreTrend.last!.1 - formScoreTrend.first!.1) / formScoreTrend.first!.1 * 100
    }

    var lastRun: SprintRun? {
        selectedAthlete?.sessions
            .sorted { $0.date > $1.date }
            .first?.runs.last
    }

    init() {
        selectedAthlete = store.athletes.first
        setupBindings()
        if let athlete = selectedAthlete {
            loadData(for: athlete)
        }
    }

    func selectAthlete(_ athlete: AthleteProfile) {
        selectedAthlete = athlete
        loadData(for: athlete)
    }

    private func setupBindings() {
        $dateRange
            .sink { [weak self] _ in
                guard let self, let athlete = self.selectedAthlete else { return }
                self.loadData(for: athlete)
            }
            .store(in: &cancellables)
    }

    private func loadData(for athlete: AthleteProfile) {
        let cutoff = dateRange.startDate
        let sessions = athlete.sessions.filter { $0.date >= cutoff }

        recentSessions = sessions.sorted { $0.date > $1.date }

        // Build score trend
        formScoreTrend = sessions
            .sorted { $0.date < $1.date }
            .compactMap { session -> (Date, Double)? in
                guard !session.runs.isEmpty else { return nil }
                let avgScore = session.runs.map { $0.formScore.overall }.reduce(0, +) / Double(session.runs.count)
                return (session.date, avgScore)
            }

        // Injury flags from recent sessions
        injuryRiskFlags = sessions.flatMap { session in
            session.runs.flatMap { $0.injuryRiskFlags }
        }.filter { $0.severity == .high || $0.severity == .medium }

        buildRadarMetrics(from: sessions)
    }

    private func buildRadarMetrics(from sessions: [TrainingSession]) {
        let allSnapshots = sessions.flatMap { s in s.runs.flatMap { $0.biomechanicsSnapshots } }
        guard !allSnapshots.isEmpty else {
            radarMetrics = []
            return
        }

        let avgKneeDrive = allSnapshots.map { $0.runningAngles.kneeDriveAngle }.average()
        let avgTorso = allSnapshots.map { $0.runningAngles.torsoAngle }.average()
        let avgSym = 1 - min(allSnapshots.map { $0.runningAngles.kneeDriveSymmetry }.average() / 10, 1)
        let avgArmSym = allSnapshots.map { $0.postureMetrics.shoulderRotation }.average()
        let avgBlockScore = sessions.flatMap { $0.runs }.map { $0.formScore.blockStart / 25 }.average()
        let avgConsistency = sessions.flatMap { $0.runs }.map { $0.formScore.consistency / 25 }.average()

        radarMetrics = [
            .init(name: "Knee\nDrive", value: normalize(avgKneeDrive, min: 60, max: 115), color: .brandOrange),
            .init(name: "Torso\nLean", value: normalize(avgTorso, min: 60, max: 90), color: .brandOrange),
            .init(name: "Symmetry", value: avgSym, color: .brandOrange),
            .init(name: "Arm\nMechanics", value: max(0, 1 - avgArmSym / 15), color: .brandOrange),
            .init(name: "Block\nStart", value: avgBlockScore, color: .brandOrange),
            .init(name: "Consistency", value: avgConsistency, color: .brandOrange)
        ]
    }

    private func normalize(_ value: Double, min: Double, max: Double) -> Double {
        guard max > min else { return 0 }
        return Swift.max(0, Swift.min(1, (value - min) / (max - min)))
    }
}
