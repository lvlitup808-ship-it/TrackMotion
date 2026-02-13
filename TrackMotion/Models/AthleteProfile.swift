import Foundation
import SwiftUI

// MARK: - Event Types
enum EventType: String, Codable, CaseIterable, Identifiable {
    case sprint60m   = "60m"
    case sprint100m  = "100m"
    case sprint200m  = "200m"
    case sprint400m  = "400m"
    case hurdles100m = "100m Hurdles"
    case hurdles110m = "110m Hurdles"
    case hurdles400m = "400m Hurdles"
    case relay4x100  = "4x100 Relay"
    case relay4x400  = "4x400 Relay"
    case combined    = "Combined Events"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var isPrimarilySpeedEvent: Bool {
        switch self {
        case .sprint60m, .sprint100m, .sprint200m,
             .hurdles100m, .hurdles110m, .relay4x100:
            return true
        default:
            return false
        }
    }
}

// MARK: - Weather Condition
enum WeatherCondition: String, Codable, CaseIterable {
    case sunny    = "Sunny"
    case cloudy   = "Cloudy"
    case windy    = "Windy"
    case rainy    = "Rainy"
    case cold     = "Cold (<50°F)"
    case hot      = "Hot (>85°F)"
    case indoor   = "Indoor"
    case unknown  = "Unknown"

    var icon: String {
        switch self {
        case .sunny:   return "sun.max.fill"
        case .cloudy:  return "cloud.fill"
        case .windy:   return "wind"
        case .rainy:   return "cloud.rain.fill"
        case .cold:    return "thermometer.snowflake"
        case .hot:     return "thermometer.sun.fill"
        case .indoor:  return "building.2.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}

// MARK: - Focus Area
enum FocusArea: String, Codable, CaseIterable {
    case blockStarts   = "Block Starts"
    case acceleration  = "Acceleration"
    case maxVelocity   = "Max Velocity"
    case speedEndurance = "Speed Endurance"
    case mechanics     = "Running Mechanics"
    case strength      = "Strength"
    case general       = "General Training"

    var icon: String {
        switch self {
        case .blockStarts:    return "figure.run.circle"
        case .acceleration:   return "bolt.fill"
        case .maxVelocity:    return "speedometer"
        case .speedEndurance: return "timer"
        case .mechanics:      return "gearshape.2"
        case .strength:       return "dumbbell.fill"
        case .general:        return "checkmark.circle"
        }
    }
}

// MARK: - Athlete Profile
final class AthleteProfile: ObservableObject, Identifiable, Codable {
    let id: UUID
    @Published var name: String
    @Published var dateOfBirth: Date
    @Published var gender: Gender
    @Published var primaryEvents: [EventType]
    @Published var goalTimes: [EventType: TimeInterval]
    @Published var personalRecords: [EventType: TimeInterval]
    @Published var profileImageData: Data?
    @Published var sessions: [TrainingSession]
    @Published var baselineMetrics: BiomechanicsBaseline?
    @Published var notes: String
    let createdDate: Date

    enum Gender: String, Codable, CaseIterable {
        case male = "Male"
        case female = "Female"
        case nonBinary = "Non-Binary"
        case preferNotToSay = "Prefer Not to Say"
    }

    init(
        id: UUID = UUID(),
        name: String,
        dateOfBirth: Date = Date(),
        gender: Gender = .preferNotToSay,
        primaryEvents: [EventType] = [.sprint100m],
        goalTimes: [EventType: TimeInterval] = [:],
        personalRecords: [EventType: TimeInterval] = [:],
        profileImageData: Data? = nil,
        sessions: [TrainingSession] = [],
        baselineMetrics: BiomechanicsBaseline? = nil,
        notes: String = "",
        createdDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.dateOfBirth = dateOfBirth
        self.gender = gender
        self.primaryEvents = primaryEvents
        self.goalTimes = goalTimes
        self.personalRecords = personalRecords
        self.profileImageData = profileImageData
        self.sessions = sessions
        self.baselineMetrics = baselineMetrics
        self.notes = notes
        self.createdDate = createdDate
    }

    var age: Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
    }

    var profileImage: UIImage? {
        guard let data = profileImageData else { return nil }
        return UIImage(data: data)
    }

    var lastSession: TrainingSession? {
        sessions.sorted { $0.date > $1.date }.first
    }

    var overallScore: Double {
        let scores = sessions.flatMap { $0.runs.map { $0.formScore.overall } }
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / Double(scores.count)
    }

    var bestFormScore: Double {
        sessions.flatMap { $0.runs.map { $0.formScore.overall } }.max() ?? 0
    }

    var totalRuns: Int {
        sessions.map { $0.runs.count }.reduce(0, +)
    }

    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case id, name, dateOfBirth, gender, primaryEvents, goalTimes,
             personalRecords, profileImageData, sessions, baselineMetrics, notes, createdDate
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        dateOfBirth = try c.decode(Date.self, forKey: .dateOfBirth)
        gender = try c.decode(Gender.self, forKey: .gender)
        primaryEvents = try c.decode([EventType].self, forKey: .primaryEvents)
        goalTimes = try c.decode([EventType: TimeInterval].self, forKey: .goalTimes)
        personalRecords = try c.decode([EventType: TimeInterval].self, forKey: .personalRecords)
        profileImageData = try c.decodeIfPresent(Data.self, forKey: .profileImageData)
        sessions = try c.decode([TrainingSession].self, forKey: .sessions)
        baselineMetrics = try c.decodeIfPresent(BiomechanicsBaseline.self, forKey: .baselineMetrics)
        notes = try c.decode(String.self, forKey: .notes)
        createdDate = try c.decode(Date.self, forKey: .createdDate)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(dateOfBirth, forKey: .dateOfBirth)
        try c.encode(gender, forKey: .gender)
        try c.encode(primaryEvents, forKey: .primaryEvents)
        try c.encode(goalTimes, forKey: .goalTimes)
        try c.encode(personalRecords, forKey: .personalRecords)
        try c.encodeIfPresent(profileImageData, forKey: .profileImageData)
        try c.encode(sessions, forKey: .sessions)
        try c.encodeIfPresent(baselineMetrics, forKey: .baselineMetrics)
        try c.encode(notes, forKey: .notes)
        try c.encode(createdDate, forKey: .createdDate)
    }
}

// MARK: - Training Session
final class TrainingSession: ObservableObject, Identifiable, Codable {
    let id: UUID
    @Published var date: Date
    @Published var location: String
    @Published var weather: WeatherCondition
    @Published var focusAreas: [FocusArea]
    @Published var runs: [SprintRun]
    @Published var coachNotes: String
    var athleteID: UUID

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        location: String = "",
        weather: WeatherCondition = .unknown,
        focusAreas: [FocusArea] = [],
        runs: [SprintRun] = [],
        coachNotes: String = "",
        athleteID: UUID
    ) {
        self.id = id
        self.date = date
        self.location = location
        self.weather = weather
        self.focusAreas = focusAreas
        self.runs = runs
        self.coachNotes = coachNotes
        self.athleteID = athleteID
    }

    var overallScore: Double {
        guard !runs.isEmpty else { return 0 }
        return runs.map { $0.formScore.overall }.reduce(0, +) / Double(runs.count)
    }

    var bestRun: SprintRun? {
        runs.max { $0.formScore.overall < $1.formScore.overall }
    }

    var displayDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    enum CodingKeys: String, CodingKey {
        case id, date, location, weather, focusAreas, runs, coachNotes, athleteID
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        date = try c.decode(Date.self, forKey: .date)
        location = try c.decode(String.self, forKey: .location)
        weather = try c.decode(WeatherCondition.self, forKey: .weather)
        focusAreas = try c.decode([FocusArea].self, forKey: .focusAreas)
        runs = try c.decode([SprintRun].self, forKey: .runs)
        coachNotes = try c.decode(String.self, forKey: .coachNotes)
        athleteID = try c.decode(UUID.self, forKey: .athleteID)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(date, forKey: .date)
        try c.encode(location, forKey: .location)
        try c.encode(weather, forKey: .weather)
        try c.encode(focusAreas, forKey: .focusAreas)
        try c.encode(runs, forKey: .runs)
        try c.encode(coachNotes, forKey: .coachNotes)
        try c.encode(athleteID, forKey: .athleteID)
    }
}

// MARK: - Sprint Run
final class SprintRun: ObservableObject, Identifiable, Codable {
    let id: UUID
    let sessionID: UUID
    @Published var videoURL: URL?
    @Published var duration: TimeInterval
    @Published var frameRate: Double
    @Published var detectedPhases: [SprintPhaseSegment]
    @Published var biomechanicsSnapshots: [BiomechanicsSnapshot]
    @Published var formScore: FormScore
    @Published var estimatedSplits: [SplitTime]
    @Published var aiRecommendations: [CoachingCue]
    @Published var manualAnnotations: [VideoAnnotation]
    @Published var velocityCurve: [VelocityPoint]
    @Published var injuryRiskFlags: [InjuryRiskFlag]
    let recordedAt: Date

    init(
        id: UUID = UUID(),
        sessionID: UUID,
        videoURL: URL? = nil,
        duration: TimeInterval = 0,
        frameRate: Double = 30.0,
        detectedPhases: [SprintPhaseSegment] = [],
        biomechanicsSnapshots: [BiomechanicsSnapshot] = [],
        formScore: FormScore = FormScore(),
        estimatedSplits: [SplitTime] = [],
        aiRecommendations: [CoachingCue] = [],
        manualAnnotations: [VideoAnnotation] = [],
        velocityCurve: [VelocityPoint] = [],
        injuryRiskFlags: [InjuryRiskFlag] = [],
        recordedAt: Date = Date()
    ) {
        self.id = id
        self.sessionID = sessionID
        self.videoURL = videoURL
        self.duration = duration
        self.frameRate = frameRate
        self.detectedPhases = detectedPhases
        self.biomechanicsSnapshots = biomechanicsSnapshots
        self.formScore = formScore
        self.estimatedSplits = estimatedSplits
        self.aiRecommendations = aiRecommendations
        self.manualAnnotations = manualAnnotations
        self.velocityCurve = velocityCurve
        self.injuryRiskFlags = injuryRiskFlags
        self.recordedAt = recordedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, sessionID, videoURL, duration, frameRate, detectedPhases,
             biomechanicsSnapshots, formScore, estimatedSplits, aiRecommendations,
             manualAnnotations, velocityCurve, injuryRiskFlags, recordedAt
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        sessionID = try c.decode(UUID.self, forKey: .sessionID)
        videoURL = try c.decodeIfPresent(URL.self, forKey: .videoURL)
        duration = try c.decode(TimeInterval.self, forKey: .duration)
        frameRate = try c.decode(Double.self, forKey: .frameRate)
        detectedPhases = try c.decode([SprintPhaseSegment].self, forKey: .detectedPhases)
        biomechanicsSnapshots = try c.decode([BiomechanicsSnapshot].self, forKey: .biomechanicsSnapshots)
        formScore = try c.decode(FormScore.self, forKey: .formScore)
        estimatedSplits = try c.decode([SplitTime].self, forKey: .estimatedSplits)
        aiRecommendations = try c.decode([CoachingCue].self, forKey: .aiRecommendations)
        manualAnnotations = try c.decode([VideoAnnotation].self, forKey: .manualAnnotations)
        velocityCurve = try c.decode([VelocityPoint].self, forKey: .velocityCurve)
        injuryRiskFlags = try c.decode([InjuryRiskFlag].self, forKey: .injuryRiskFlags)
        recordedAt = try c.decode(Date.self, forKey: .recordedAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(sessionID, forKey: .sessionID)
        try c.encodeIfPresent(videoURL, forKey: .videoURL)
        try c.encode(duration, forKey: .duration)
        try c.encode(frameRate, forKey: .frameRate)
        try c.encode(detectedPhases, forKey: .detectedPhases)
        try c.encode(biomechanicsSnapshots, forKey: .biomechanicsSnapshots)
        try c.encode(formScore, forKey: .formScore)
        try c.encode(estimatedSplits, forKey: .estimatedSplits)
        try c.encode(aiRecommendations, forKey: .aiRecommendations)
        try c.encode(manualAnnotations, forKey: .manualAnnotations)
        try c.encode(velocityCurve, forKey: .velocityCurve)
        try c.encode(injuryRiskFlags, forKey: .injuryRiskFlags)
        try c.encode(recordedAt, forKey: .recordedAt)
    }
}

// MARK: - Supporting Value Types
struct VelocityPoint: Codable, Identifiable {
    let id: UUID
    var distanceMeters: Double
    var velocityMs: Double
    var timestamp: TimeInterval

    init(id: UUID = UUID(), distanceMeters: Double, velocityMs: Double, timestamp: TimeInterval) {
        self.id = id
        self.distanceMeters = distanceMeters
        self.velocityMs = velocityMs
        self.timestamp = timestamp
    }
}

struct SplitTime: Codable, Identifiable {
    let id: UUID
    var startDistance: Double
    var endDistance: Double
    var time: TimeInterval
    var confidence: Double // 0-1

    init(id: UUID = UUID(), startDistance: Double, endDistance: Double, time: TimeInterval, confidence: Double) {
        self.id = id
        self.startDistance = startDistance
        self.endDistance = endDistance
        self.time = time
        self.confidence = confidence
    }

    var displayLabel: String { "\(Int(startDistance))-\(Int(endDistance))m" }

    var formattedTime: String {
        String(format: "%.2fs", time)
    }
}

struct VideoAnnotation: Codable, Identifiable {
    let id: UUID
    var timestamp: TimeInterval
    var pathData: String // SVG path
    var color: String
    var lineWidth: Double
    var annotationType: AnnotationType

    enum AnnotationType: String, Codable {
        case freehand, line, circle, angle, text
    }

    init(
        id: UUID = UUID(),
        timestamp: TimeInterval,
        pathData: String,
        color: String = "#FF6B35",
        lineWidth: Double = 2.0,
        annotationType: AnnotationType = .freehand
    ) {
        self.id = id
        self.timestamp = timestamp
        self.pathData = pathData
        self.color = color
        self.lineWidth = lineWidth
        self.annotationType = annotationType
    }
}

struct BiomechanicsBaseline: Codable {
    var rearShinAngle: Double
    var frontShinAngle: Double
    var kneeDriveAngle: Double
    var armSwingRange: Double
    var strideLength: Double
    var strideFrequency: Double
    var forwardLean: Double
    var capturedAt: Date

    init(
        rearShinAngle: Double = 45.0,
        frontShinAngle: Double = 55.0,
        kneeDriveAngle: Double = 90.0,
        armSwingRange: Double = 60.0,
        strideLength: Double = 1.8,
        strideFrequency: Double = 4.5,
        forwardLean: Double = 45.0,
        capturedAt: Date = Date()
    ) {
        self.rearShinAngle = rearShinAngle
        self.frontShinAngle = frontShinAngle
        self.kneeDriveAngle = kneeDriveAngle
        self.armSwingRange = armSwingRange
        self.strideLength = strideLength
        self.strideFrequency = strideFrequency
        self.forwardLean = forwardLean
        self.capturedAt = capturedAt
    }
}
