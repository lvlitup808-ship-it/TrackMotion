import Foundation
import AVFoundation

// MARK: - Coaching Cue Model
struct CoachingCue: Codable, Identifiable {
    let id: UUID
    var priority: Priority
    var category: Category
    var issue: String
    var recommendation: String
    var voiceFeedback: String
    var suggestedDrills: [String]  // drill IDs
    var estimatedImprovementWeeks: Int
    var triggerCondition: String

    enum Priority: String, Codable, CaseIterable {
        case high   = "High"
        case medium = "Medium"
        case low    = "Low"

        var color: String {
            switch self {
            case .high:   return "#E74C3C"
            case .medium: return "#F39C12"
            case .low:    return "#2ECC71"
            }
        }
    }

    enum Category: String, Codable, CaseIterable {
        case technique  = "Technique"
        case strength   = "Strength"
        case mobility   = "Mobility"
        case rhythm     = "Rhythm"
        case posture    = "Posture"
        case blockStart = "Block Start"
    }

    init(
        id: UUID = UUID(),
        priority: Priority,
        category: Category,
        issue: String,
        recommendation: String,
        voiceFeedback: String,
        suggestedDrills: [String] = [],
        estimatedImprovementWeeks: Int = 2,
        triggerCondition: String = ""
    ) {
        self.id = id
        self.priority = priority
        self.category = category
        self.issue = issue
        self.recommendation = recommendation
        self.voiceFeedback = voiceFeedback
        self.suggestedDrills = suggestedDrills
        self.estimatedImprovementWeeks = estimatedImprovementWeeks
        self.triggerCondition = triggerCondition
    }
}

// MARK: - Form Rule Protocol
protocol FormRule {
    var ruleID: String { get }
    var category: CoachingCue.Category { get }
    var priority: CoachingCue.Priority { get }
    var checkInterval: Int { get }  // check every N frames
    func evaluate(snapshot: BiomechanicsSnapshot) -> CoachingCue?
}

// MARK: - Concrete Form Rules

struct KneeDriveRule: FormRule {
    let ruleID = "knee_drive_low"
    let category: CoachingCue.Category = .technique
    let priority: CoachingCue.Priority = .high
    let checkInterval = 5

    func evaluate(snapshot: BiomechanicsSnapshot) -> CoachingCue? {
        let angle = snapshot.runningAngles.kneeDriveAngle
        guard angle > 0 && angle < 85 else { return nil }

        return CoachingCue(
            priority: priority,
            category: category,
            issue: "Low knee drive detected (\(Int(angle))°)",
            recommendation: "Drive your knees to hip height on every stride",
            voiceFeedback: "Drive your knee higher",
            suggestedDrills: ["high_knees", "a_skip", "wall_drives"],
            estimatedImprovementWeeks: 2,
            triggerCondition: "knee_drive < 85°"
        )
    }
}

struct TorsoLeanRule: FormRule {
    let ruleID = "torso_lean_insufficient"
    let category: CoachingCue.Category = .posture
    let priority: CoachingCue.Priority = .medium
    let checkInterval = 5

    func evaluate(snapshot: BiomechanicsSnapshot) -> CoachingCue? {
        guard snapshot.phase == .acceleration || snapshot.phase == .drivePhase else { return nil }
        let angle = snapshot.runningAngles.torsoAngle
        guard angle > 0 && angle < 40 else { return nil }

        return CoachingCue(
            priority: priority,
            category: category,
            issue: "Insufficient forward lean (\(Int(angle))°)",
            recommendation: "Lean your torso forward from the ankles, not the waist",
            voiceFeedback: "Lean forward more",
            suggestedDrills: ["wall_lean_drills", "falling_starts", "sled_push"],
            estimatedImprovementWeeks: 1,
            triggerCondition: "torso_lean < 40° in acceleration"
        )
    }
}

struct ArmCrossBodyRule: FormRule {
    let ruleID = "arm_crosses_midline"
    let category: CoachingCue.Category = .technique
    let priority: CoachingCue.Priority = .medium
    let checkInterval = 5

    func evaluate(snapshot: BiomechanicsSnapshot) -> CoachingCue? {
        let rotation = snapshot.postureMetrics.shoulderRotation
        guard rotation > 10 else { return nil }

        return CoachingCue(
            priority: priority,
            category: category,
            issue: "Arms crossing body midline (\(Int(rotation))° rotation)",
            recommendation: "Keep your arm swing forward-and-back, not across your body",
            voiceFeedback: "Keep arms straight",
            suggestedDrills: ["seated_arm_swings", "arm_circles", "mirror_drills"],
            estimatedImprovementWeeks: 1,
            triggerCondition: "shoulder_rotation > 10°"
        )
    }
}

struct StrideFrequencyRule: FormRule {
    let ruleID = "stride_frequency_drop"
    let category: CoachingCue.Category = .rhythm
    let priority: CoachingCue.Priority = .high
    let checkInterval = 10

    private var peakFrequency: Double = 0
    private var currentFrequency: Double = 0

    func evaluate(snapshot: BiomechanicsSnapshot) -> CoachingCue? {
        guard snapshot.phase == .speedEndurance || snapshot.phase == .deceleration else { return nil }
        guard let freq = snapshot.strideFrequency, freq > 0 else { return nil }

        // This rule needs context from phase detector; simplified check
        if freq < 4.0 { // below threshold for sprint events
            return CoachingCue(
                priority: priority,
                category: category,
                issue: "Stride frequency dropping (\(String(format: "%.1f", freq)) strides/s)",
                recommendation: "Maintain your turnover rate through the finish line",
                voiceFeedback: "Maintain your tempo",
                suggestedDrills: ["fast_feet", "downhill_sprints", "wicket_runs"],
                estimatedImprovementWeeks: 3,
                triggerCondition: "stride_frequency < threshold in final 20m"
            )
        }
        return nil
    }
}

struct HipDropRule: FormRule {
    let ruleID = "hip_drop"
    let category: CoachingCue.Category = .posture
    let priority: CoachingCue.Priority = .medium
    let checkInterval = 5

    func evaluate(snapshot: BiomechanicsSnapshot) -> CoachingCue? {
        let drop = snapshot.postureMetrics.hipDrop
        guard drop > 5 else { return nil }

        return CoachingCue(
            priority: priority,
            category: category,
            issue: "Hip drop detected (\(Int(drop))°)",
            recommendation: "Keep your hips level and engage your glutes",
            voiceFeedback: "Keep hips level",
            suggestedDrills: ["glute_bridges", "single_leg_deadlifts", "lateral_band_walks"],
            estimatedImprovementWeeks: 3,
            triggerCondition: "hip_drop > 5°"
        )
    }
}

struct SymmetryRule: FormRule {
    let ruleID = "bilateral_asymmetry"
    let category: CoachingCue.Category = .technique
    let priority: CoachingCue.Priority = .medium
    let checkInterval = 10

    func evaluate(snapshot: BiomechanicsSnapshot) -> CoachingCue? {
        let asymmetry = snapshot.runningAngles.kneeDriveSymmetry
        guard asymmetry > 5 else { return nil }

        let weaker = snapshot.runningAngles.leftKneeDrive < snapshot.runningAngles.rightKneeDrive
            ? "left" : "right"

        return CoachingCue(
            priority: priority,
            category: category,
            issue: "Asymmetrical knee drive (\(Int(asymmetry))° difference)",
            recommendation: "Focus on equal \(weaker) leg drive to reduce imbalance",
            voiceFeedback: "Equal knee drive both legs",
            suggestedDrills: ["single_leg_bounds", "hurdle_hops", "step_ups"],
            estimatedImprovementWeeks: 4,
            triggerCondition: "knee_drive_asymmetry > 5°"
        )
    }
}

// MARK: - Real-Time Feedback Engine
final class RealtimeFeedbackEngine {
    weak var delegate: RealtimeFeedbackDelegate?
    var isVoiceFeedbackEnabled: Bool = true
    var isVisualFeedbackEnabled: Bool = true

    private var rules: [FormRule] = []
    private var frameCount: Int = 0
    private var lastTriggeredRuleIDs: Set<String> = []
    private var cooldownFrames: [String: Int] = [:]
    private let ruleCooldownFrames: Int = 90  // ~3 seconds at 30fps

    private let speechSynthesizer = AVSpeechSynthesizer()
    private var isSpeaking: Bool = false

    init() {
        setupDefaultRules()
    }

    private func setupDefaultRules() {
        rules = [
            KneeDriveRule(),
            TorsoLeanRule(),
            ArmCrossBodyRule(),
            StrideFrequencyRule(),
            HipDropRule(),
            SymmetryRule()
        ]
    }

    // MARK: - Process Frame
    func processSnapshot(_ snapshot: BiomechanicsSnapshot) -> [CoachingCue] {
        frameCount += 1
        var triggeredCues: [CoachingCue] = []

        for rule in rules {
            // Check interval
            guard frameCount % rule.checkInterval == 0 else { continue }

            // Check cooldown
            if let lastFrame = cooldownFrames[rule.ruleID],
               frameCount - lastFrame < ruleCooldownFrames { continue }

            if let cue = rule.evaluate(snapshot: snapshot) {
                triggeredCues.append(cue)
                cooldownFrames[rule.ruleID] = frameCount

                // Deliver feedback
                if isVoiceFeedbackEnabled && !isSpeaking {
                    speakFeedback(cue.voiceFeedback)
                }
                if isVisualFeedbackEnabled {
                    delegate?.feedbackEngine(self, didTriggerCue: cue)
                }
            }
        }

        return triggeredCues
    }

    // MARK: - Voice Feedback
    private func speakFeedback(_ text: String) {
        guard !isSpeaking else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.volume = 0.8
        isSpeaking = true
        speechSynthesizer.speak(utterance)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.isSpeaking = false
        }
    }

    func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    func reset() {
        frameCount = 0
        lastTriggeredRuleIDs.removeAll()
        cooldownFrames.removeAll()
        stopSpeaking()
    }
}

// MARK: - Feedback Delegate
protocol RealtimeFeedbackDelegate: AnyObject {
    func feedbackEngine(_ engine: RealtimeFeedbackEngine, didTriggerCue cue: CoachingCue)
}

// MARK: - Recommendation Engine (Post-Run Analysis)
final class RecommendationEngine {
    static let shared = RecommendationEngine()
    private init() {}

    func generateRecommendations(
        from snapshots: [BiomechanicsSnapshot],
        score: FormScore,
        athleteHistory: [FormScore]
    ) -> [CoachingCue] {
        guard !snapshots.isEmpty else { return [] }

        var recommendations: [CoachingCue] = []

        // Find worst-performing metrics
        let sortedMetrics = score.breakdown.sorted { $0.score < $1.score }
        let bottomMetrics = sortedMetrics.prefix(3)

        for metric in bottomMetrics {
            if let cue = recommendationForMetric(metric, snapshots: snapshots, history: athleteHistory) {
                recommendations.append(cue)
            }
        }

        // Add trend-based recommendations
        if let trendCue = assessTrends(history: athleteHistory) {
            recommendations.append(trendCue)
        }

        return recommendations.sorted { $0.priority.rawValue < $1.priority.rawValue }
    }

    private func recommendationForMetric(
        _ metric: MetricScore,
        snapshots: [BiomechanicsSnapshot],
        history: [FormScore]
    ) -> CoachingCue? {
        switch metric.metricName {
        case "Knee Drive":
            return CoachingCue(
                priority: metric.score < 50 ? .high : .medium,
                category: .technique,
                issue: "Below-optimal knee drive (avg \(Int(metric.measuredValue))°)",
                recommendation: "Incorporate high knees and A-skips into every warm-up. Focus on driving knee to hip pocket height.",
                voiceFeedback: "Focus on knee drive this session",
                suggestedDrills: ["high_knees", "a_skip", "b_skip", "wall_drives"],
                estimatedImprovementWeeks: 2
            )

        case "Block Start":
            return CoachingCue(
                priority: metric.score < 50 ? .high : .medium,
                category: .blockStart,
                issue: "Block start position needs improvement",
                recommendation: "Review shin angles (rear: 35-50°, front: 50-70°) and hip height positioning.",
                voiceFeedback: "Work on your block position",
                suggestedDrills: ["block_starts_drill", "fall_and_sprint", "push_starts"],
                estimatedImprovementWeeks: 1
            )

        case "Consistency":
            return CoachingCue(
                priority: metric.score < 60 ? .high : .medium,
                category: .strength,
                issue: "Form breaking down in later stages",
                recommendation: "Build speed endurance with 60-80m runs and specific conditioning work.",
                voiceFeedback: "Build your endurance",
                suggestedDrills: ["speed_endurance_runs", "tempo_runs", "special_endurance"],
                estimatedImprovementWeeks: 4
            )

        case "Symmetry":
            return CoachingCue(
                priority: metric.score < 60 ? .high : .medium,
                category: .strength,
                issue: "Bilateral asymmetry detected",
                recommendation: "Single-leg strength work to address imbalances. Bulgarian split squats and single-leg RDLs.",
                voiceFeedback: "Work on single-leg strength",
                suggestedDrills: ["single_leg_squat", "single_leg_rdl", "hurdle_hops_unilateral"],
                estimatedImprovementWeeks: 3
            )

        case "Max Velocity":
            return CoachingCue(
                priority: metric.score < 50 ? .high : .medium,
                category: .technique,
                issue: "Top-end form needs improvement",
                recommendation: "Wicket runs, flying sprints, and overspeed training to improve max velocity mechanics.",
                voiceFeedback: "Focus on relaxation at top speed",
                suggestedDrills: ["wicket_runs", "flying_30s", "downhill_sprints", "overspeed_towing"],
                estimatedImprovementWeeks: 3
            )

        default: return nil
        }
    }

    private func assessTrends(history: [FormScore]) -> CoachingCue? {
        guard history.count >= 3 else { return nil }
        let recent = history.suffix(3).map { $0.overall }
        let trend = recent.last! - recent.first!

        if trend < -5 {
            return CoachingCue(
                priority: .high,
                category: .technique,
                issue: "Performance declining over last 3 sessions",
                recommendation: "Consider a lighter training day or deload week. Review recent training load.",
                voiceFeedback: "Consider a recovery day",
                suggestedDrills: ["active_recovery", "form_drills_easy"],
                estimatedImprovementWeeks: 1
            )
        }
        return nil
    }
}
