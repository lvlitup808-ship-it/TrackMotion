import Foundation
import Combine

// MARK: - Athlete Store (single source of truth)
final class AthleteStore: ObservableObject {
    static let shared = AthleteStore()

    @Published private(set) var athletes: [AthleteProfile] = []

    private let storageKey = "com.trackmotion.athletes"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        load()
    }

    // MARK: - CRUD
    func addAthlete(_ athlete: AthleteProfile) {
        athletes.append(athlete)
        save()
    }

    func removeAthlete(at index: Int) {
        guard athletes.indices.contains(index) else { return }
        athletes.remove(at: index)
        save()
    }

    func removeAthlete(_ athlete: AthleteProfile) {
        athletes.removeAll { $0.id == athlete.id }
        save()
    }

    func updateAthlete(_ athlete: AthleteProfile) {
        if let idx = athletes.firstIndex(where: { $0.id == athlete.id }) {
            athletes[idx] = athlete
            save()
        }
    }

    func addSession(_ session: TrainingSession, to athlete: AthleteProfile) {
        if let idx = athletes.firstIndex(where: { $0.id == athlete.id }) {
            athletes[idx].sessions.append(session)
            save()
        }
    }

    func deleteAll() {
        athletes.removeAll()
        save()
    }

    // MARK: - Persistence
    private func save() {
        do {
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(athletes)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("AthleteStore save failed: \(error)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            loadSampleData()
            return
        }
        do {
            decoder.dateDecodingStrategy = .iso8601
            athletes = try decoder.decode([AthleteProfile].self, from: data)
        } catch {
            print("AthleteStore load failed: \(error)")
            loadSampleData()
        }
    }

    private func loadSampleData() {
        // Pre-populate with sample athlete for demo
        let sample = AthleteProfile(
            name: "Alex Johnson",
            dateOfBirth: Calendar.current.date(byAdding: .year, value: -19, to: Date())!,
            gender: .male,
            primaryEvents: [.sprint100m, .sprint200m],
            goalTimes: [.sprint100m: 10.5],
            personalRecords: [.sprint100m: 10.82]
        )
        athletes = [sample]
    }

    // MARK: - Export
    func exportAllData() -> Data? {
        do {
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(athletes)
        } catch {
            return nil
        }
    }

    func exportCSV(for athlete: AthleteProfile) -> String {
        var csv = "Date,Overall Score,Block Start,Acceleration,Max Velocity,Consistency,Knee Drive,Torso Angle,Symmetry\n"

        for session in athlete.sessions.sorted(by: { $0.date < $1.date }) {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd HH:mm"

            for run in session.runs {
                let avgSnap = run.biomechanicsSnapshots
                let kneeDrive = avgSnap.map { $0.runningAngles.kneeDriveAngle }.average()
                let torso = avgSnap.map { $0.runningAngles.torsoAngle }.average()
                let sym = avgSnap.map { $0.runningAngles.kneeDriveSymmetry }.average()

                csv += [
                    df.string(from: session.date),
                    "\(Int(run.formScore.overall))",
                    "\(Int(run.formScore.blockStart))",
                    "\(Int(run.formScore.acceleration))",
                    "\(Int(run.formScore.maxVelocity))",
                    "\(Int(run.formScore.consistency))",
                    String(format: "%.1f", kneeDrive),
                    String(format: "%.1f", torso),
                    String(format: "%.1f", sym)
                ].joined(separator: ",") + "\n"
            }
        }
        return csv
    }
}
