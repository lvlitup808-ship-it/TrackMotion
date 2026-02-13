import Foundation

// MARK: - Drill Model
struct Drill: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var category: DrillCategory
    var targetWeakness: [String]  // which metrics this drill improves
    var description: String
    var coachingCues: [String]
    var sets: String
    var reps: String
    var videoURL: URL?
    var thumbnailURL: URL?
    var difficulty: Difficulty
    var equipment: [String]
    var progressionDrills: [String]  // drill IDs for more advanced variations
    var regressionDrills: [String]   // drill IDs for easier variations

    enum DrillCategory: String, Codable, CaseIterable {
        case warmup         = "Warm-Up"
        case acceleration   = "Acceleration"
        case maxVelocity    = "Max Velocity"
        case armMechanics   = "Arm Mechanics"
        case blockStart     = "Block Start"
        case strength       = "Strength"
        case mobility       = "Mobility"
        case speedEndurance = "Speed Endurance"
        case recovery       = "Recovery"
    }

    enum Difficulty: String, Codable, CaseIterable {
        case beginner     = "Beginner"
        case intermediate = "Intermediate"
        case advanced     = "Advanced"
        case elite        = "Elite"
    }
}

// MARK: - Drill Library
final class DrillLibrary {
    static let shared = DrillLibrary()
    private(set) var drills: [Drill] = []

    private init() {
        loadBuiltInDrills()
    }

    // MARK: - Lookup
    func drill(id: String) -> Drill? {
        drills.first { $0.id == id }
    }

    func drills(for weakness: String) -> [Drill] {
        drills.filter { $0.targetWeakness.contains(weakness) }
    }

    func drills(in category: Drill.DrillCategory) -> [Drill] {
        drills.filter { $0.category == category }
    }

    func drills(for ids: [String]) -> [Drill] {
        ids.compactMap { drill(id: $0) }
    }

    // MARK: - Built-In Drill Database (50+ exercises)
    private func loadBuiltInDrills() {
        drills = [

            // MARK: Acceleration Drills
            Drill(
                id: "wall_drives",
                name: "Wall Drives",
                category: .acceleration,
                targetWeakness: ["knee_drive", "drive_phase", "acceleration"],
                description: "Stand 45° from wall, drive alternating knees to hip height rapidly. Focuses on proper drive phase mechanics.",
                coachingCues: [
                    "Keep hips square to the wall",
                    "Drive knee to hip pocket height",
                    "Maintain forward lean angle",
                    "Arms drive in opposition"
                ],
                sets: "4-6",
                reps: "10-20 per leg",
                videoURL: nil,
                thumbnailURL: nil,
                difficulty: .beginner,
                equipment: ["Wall"],
                progressionDrills: ["falling_starts", "sled_push"],
                regressionDrills: []
            ),

            Drill(
                id: "falling_starts",
                name: "Falling Starts",
                category: .acceleration,
                targetWeakness: ["forward_lean", "acceleration", "drive_phase"],
                description: "Fall forward from standing position and sprint for 10-20m. Teaches natural forward lean in acceleration.",
                coachingCues: [
                    "Lean as one unit from the ankles",
                    "React before you fall too far",
                    "Aggressive first step",
                    "Low heel recovery for first 3-4 steps"
                ],
                sets: "4-6",
                reps: "20m sprints",
                videoURL: nil,
                thumbnailURL: nil,
                difficulty: .beginner,
                equipment: [],
                progressionDrills: ["push_starts", "block_starts_drill"],
                regressionDrills: ["wall_drives"]
            ),

            Drill(
                id: "sled_push",
                name: "Sled Push / Prowler",
                category: .acceleration,
                targetWeakness: ["drive_phase", "forward_lean", "strength"],
                description: "Push weighted sled for 10-30m. Overloads acceleration mechanics and builds specific strength.",
                coachingCues: [
                    "Keep arms straight and push into handles",
                    "Drive from your hips and legs",
                    "Maintain flat back",
                    "Quick, powerful steps"
                ],
                sets: "4-6",
                reps: "20-30m",
                videoURL: nil,
                thumbnailURL: nil,
                difficulty: .intermediate,
                equipment: ["Sled", "Weight plates"],
                progressionDrills: ["resisted_sprints"],
                regressionDrills: ["falling_starts"]
            ),

            Drill(
                id: "push_starts",
                name: "Push Starts",
                category: .blockStart,
                targetWeakness: ["block_start", "first_step"],
                description: "Partner pushes athlete from shoulder as they accelerate. Simulates block clearance forces.",
                coachingCues: [
                    "React with your whole body",
                    "First step should be a push, not a step",
                    "Low heel recovery",
                    "Drive arms aggressively"
                ],
                sets: "4-6",
                reps: "20m sprints",
                videoURL: nil,
                thumbnailURL: nil,
                difficulty: .intermediate,
                equipment: ["Partner"],
                progressionDrills: ["block_starts_drill"],
                regressionDrills: ["falling_starts"]
            ),

            Drill(
                id: "block_starts_drill",
                name: "Block Starts",
                category: .blockStart,
                targetWeakness: ["block_start", "rear_shin_angle", "front_shin_angle", "hip_height"],
                description: "Practice from starting blocks focusing on optimal set position and explosive clearance.",
                coachingCues: [
                    "Rear shin parallel to front shin",
                    "Hips at or slightly above shoulder height",
                    "Weight over hands",
                    "First movement is hips up and forward"
                ],
                sets: "6-10",
                reps: "30m sprints",
                videoURL: nil,
                thumbnailURL: nil,
                difficulty: .intermediate,
                equipment: ["Starting blocks"],
                progressionDrills: ["block_starts_with_gun", "flying_starts"],
                regressionDrills: ["push_starts", "falling_starts"]
            ),

            // MARK: Max Velocity Drills
            Drill(
                id: "high_knees",
                name: "High Knees",
                category: .maxVelocity,
                targetWeakness: ["knee_drive", "stride_frequency", "acceleration"],
                description: "Run in place or forward driving knees to hip height rapidly. Key warm-up and drill for knee drive.",
                coachingCues: [
                    "Drive knee to hip pocket",
                    "Stay on balls of feet",
                    "Arms drive in opposition",
                    "Keep torso tall and upright"
                ],
                sets: "4-6",
                reps: "10-20m or 10 seconds",
                videoURL: nil,
                thumbnailURL: nil,
                difficulty: .beginner,
                equipment: [],
                progressionDrills: ["a_skip", "fast_feet"],
                regressionDrills: []
            ),

            Drill(
                id: "a_skip",
                name: "A-Skip",
                category: .maxVelocity,
                targetWeakness: ["knee_drive", "coordination", "rhythm"],
                description: "Skip forward while driving front knee to hip height with each skip. Classic sprint drill for coordination.",
                coachingCues: [
                    "Drive knee straight up, not across",
                    "Active foot strike under hips",
                    "Opposite arm drives with knee",
                    "Stay relaxed in shoulders"
                ],
                sets: "4",
                reps: "20-30m",
                videoURL: nil,
                thumbnailURL: nil,
                difficulty: .beginner,
                equipment: [],
                progressionDrills: ["b_skip", "a_run"],
                regressionDrills: ["high_knees"]
            ),

            Drill(
                id: "b_skip",
                name: "B-Skip",
                category: .maxVelocity,
                targetWeakness: ["knee_drive", "hamstring_cycle", "trailing_leg"],
                description: "Like A-skip but extend and claw down with the lead leg. Works the full cycle of the sprint stride.",
                coachingCues: [
                    "Extend leg fully at peak",
                    "Claw foot actively down and back",
                    "Maintain tall posture",
                    "Rhythmical and coordinated"
                ],
                sets: "4",
                reps: "20-30m",
                videoURL: nil,
                thumbnailURL: nil,
                difficulty: .intermediate,
                equipment: [],
                progressionDrills: ["b_run", "wicket_runs"],
                regressionDrills: ["a_skip"]
            ),

            Drill(
                id: "wicket_runs",
                name: "Wicket Runs",
                category: .maxVelocity,
                targetWeakness: ["stride_length", "stride_frequency", "max_velocity_mechanics"],
                description: "Sprint over hurdles or sticks spaced to optimise stride length. Teaches proper stride mechanics at speed.",
                coachingCues: [
                    "Don't reach for the wickets",
                    "Let the spacing dictate your stride",
                    "High knee drive to clear each wicket",
                    "Maintain relaxed upper body"
                ],
                sets: "4-6",
                reps: "30-40m",
                videoURL: nil,
                thumbnailURL: nil,
                difficulty: .intermediate,
                equipment: ["Hurdle wickets or flat sticks", "Measuring tape"],
                progressionDrills: ["flying_30s"],
                regressionDrills: ["b_skip", "a_skip"]
            ),

            Drill(
                id: "flying_30s",
                name: "Flying 30s",
                category: .maxVelocity,
                targetWeakness: ["max_velocity", "top_end_speed"],
                description: "Build up for 30m then sprint maximally for 30m. Allows athlete to hit true top speed.",
                coachingCues: [
                    "Be fully upright by the fly zone",
                    "Relax your face, hands, shoulders",
                    "Quick ground contact times",
                    "Drive through to the finish"
                ],
                sets: "3-5",
                reps: "60m total (30 build + 30 fly)",
                videoURL: nil,
                thumbnailURL: nil,
                difficulty: .advanced,
                equipment: ["Cones"],
                progressionDrills: ["downhill_sprints", "overspeed_towing"],
                regressionDrills: ["wicket_runs"]
            ),

            Drill(
                id: "downhill_sprints",
                name: "Downhill Sprints",
                category: .maxVelocity,
                targetWeakness: ["max_velocity", "stride_frequency", "overspeed"],
                description: "Sprint down a 1-3° slope to train supramaximal stride frequency. Improves neuromuscular speed.",
                coachingCues: [
                    "Slight slope only (1-3°)",
                    "Stay in control throughout",
                    "Maintain proper mechanics",
                    "Don't let the slope collapse form"
                ],
                sets: "4-6",
                reps: "40-60m",
                videoURL: nil,
                thumbnailURL: nil,
                difficulty: .advanced,
                equipment: ["Sloped surface"],
                progressionDrills: ["overspeed_towing"],
                regressionDrills: ["flying_30s"]
            ),

            // MARK: Arm Mechanics
            Drill(
                id: "seated_arm_swings",
                name: "Seated Arm Swings",
                category: .armMechanics,
                targetWeakness: ["arm_swing", "arm_cross_body"],
                description: "Sit and practice arm mechanics at varying speeds. Isolates arm movement from legs.",
                coachingCues: [
                    "Elbows at ~90° throughout",
                    "Drive from the shoulder, not the elbow",
                    "Hands move cheek to back pocket",
                    "No cross-body movement"
                ],
                sets: "3-4",
                reps: "30 seconds",
                videoURL: nil,
                thumbnailURL: nil,
                difficulty: .beginner,
                equipment: [],
                progressionDrills: ["standing_arm_swings", "arm_circles"],
                regressionDrills: []
            ),

            Drill(
                id: "arm_circles",
                name: "Arm Swing Drills",
                category: .armMechanics,
                targetWeakness: ["arm_swing", "shoulder_mobility"],
                description: "Windmill and controlled arm swings to improve range of motion and coordination.",
                coachingCues: [
                    "Full range of motion",
                    "Keep shoulders relaxed",
                    "Forward swing reaches eye level",
                    "Back swing drives past hip"
                ],
                sets: "3",
                reps: "15 each direction",
                videoURL: nil,
                thumbnailURL: nil,
                difficulty: .beginner,
                equipment: [],
                progressionDrills: ["seated_arm_swings"],
                regressionDrills: []
            ),

            // MARK: Speed Endurance
            Drill(
                id: "speed_endurance_runs",
                name: "Speed Endurance Runs",
                category: .speedEndurance,
                targetWeakness: ["speed_endurance", "consistency", "form_breakdown"],
                description: "60-80m runs at 95% effort with full recovery. Trains ability to maintain form under fatigue.",
                coachingCues: [
                    "Push through the finish",
                    "Focus on knee drive when tired",
                    "Relax to run faster",
                    "Don't tie up"
                ],
                sets: "4-6",
                reps: "60-80m at 95%",
                videoURL: nil,
                thumbnailURL: nil,
                difficulty: .advanced,
                equipment: ["Cones"],
                progressionDrills: ["special_endurance"],
                regressionDrills: ["flying_30s"]
            ),

            Drill(
                id: "tempo_runs",
                name: "Tempo Runs",
                category: .speedEndurance,
                targetWeakness: ["speed_endurance", "aerobic_base"],
                description: "100-200m runs at 70-75% effort. Builds aerobic base for sprinters with high volume.",
                coachingCues: [
                    "Relaxed effort, conversational pace",
                    "Focus on mechanics, not speed",
                    "Walk back recovery",
                    "Keep upright posture throughout"
                ],
                sets: "8-12",
                reps: "100-200m at 70-75%",
                videoURL: nil,
                thumbnailURL: nil,
                difficulty: .intermediate,
                equipment: [],
                progressionDrills: ["speed_endurance_runs"],
                regressionDrills: []
            ),

            // MARK: Strength
            Drill(
                id: "glute_bridges",
                name: "Glute Bridges / Hip Thrusts",
                category: .strength,
                targetWeakness: ["hip_drop", "glute_strength", "symmetry"],
                description: "Lying hip extension to strengthen glutes for stable sprint mechanics and reduce hip drop.",
                coachingCues: [
                    "Drive through heels",
                    "Squeeze glutes at top",
                    "Hips fully extended at peak",
                    "Progress to single-leg variation"
                ],
                sets: "3-4",
                reps: "12-15",
                videoURL: nil,
                thumbnailURL: nil,
                difficulty: .beginner,
                equipment: ["Barbell (advanced)", "Bench (for hip thrust)"],
                progressionDrills: ["single_leg_rdl", "barbell_hip_thrusts"],
                regressionDrills: []
            ),

            Drill(
                id: "single_leg_rdl",
                name: "Single-Leg Romanian Deadlift",
                category: .strength,
                targetWeakness: ["symmetry", "hip_drop", "hamstring_strength"],
                description: "Unilateral hip hinge to correct strength imbalances and improve single-leg stability.",
                coachingCues: [
                    "Hinge at hip, not waist",
                    "Feel stretch in standing hamstring",
                    "Keep hips level throughout",
                    "Slow and controlled descent"
                ],
                sets: "3-4",
                reps: "8-12 per leg",
                videoURL: nil,
                thumbnailURL: nil,
                difficulty: .intermediate,
                equipment: ["Dumbbells or kettlebell"],
                progressionDrills: ["trap_bar_deadlift"],
                regressionDrills: ["glute_bridges"]
            ),

            Drill(
                id: "single_leg_bounds",
                name: "Single-Leg Bounds",
                category: .strength,
                targetWeakness: ["symmetry", "power", "stride_length"],
                description: "Alternating single-leg hops for distance. Develops power, coordination and symmetry.",
                coachingCues: [
                    "Drive knee up aggressively on each bound",
                    "Aim for maximum distance per bound",
                    "Land softly and rebound quickly",
                    "Compare left vs right distances"
                ],
                sets: "4-5",
                reps: "6-8 per leg",
                videoURL: nil,
                thumbnailURL: nil,
                difficulty: .intermediate,
                equipment: [],
                progressionDrills: ["triple_jumps", "depth_jumps"],
                regressionDrills: ["glute_bridges", "step_ups"]
            ),

            Drill(
                id: "step_ups",
                name: "Box Step-Ups",
                category: .strength,
                targetWeakness: ["symmetry", "quad_strength", "hip_drop"],
                description: "Unilateral stepping onto box to build leg strength symmetrically.",
                coachingCues: [
                    "Drive through heel of elevated leg",
                    "Don't push off the grounded foot",
                    "Tall posture throughout",
                    "Control the descent"
                ],
                sets: "3-4",
                reps: "10-12 per leg",
                videoURL: nil,
                thumbnailURL: nil,
                difficulty: .beginner,
                equipment: ["Plyo box or bench"],
                progressionDrills: ["single_leg_bounds", "single_leg_rdl"],
                regressionDrills: []
            ),

            // MARK: Mobility
            Drill(
                id: "hip_flexor_stretch",
                name: "Hip Flexor Stretch",
                category: .mobility,
                targetWeakness: ["hip_extension", "trailing_leg"],
                description: "Kneeling lunge hip flexor stretch to improve hip extension at toe-off.",
                coachingCues: [
                    "Drive hips forward, not down",
                    "Keep torso tall",
                    "Hold 30-60 seconds",
                    "Slight glute squeeze to deepen stretch"
                ],
                sets: "2-3",
                reps: "30-60 seconds per side",
                videoURL: nil,
                thumbnailURL: nil,
                difficulty: .beginner,
                equipment: ["Mat"],
                progressionDrills: ["couch_stretch"],
                regressionDrills: []
            ),

            Drill(
                id: "fast_feet",
                name: "Fast Feet Ladder",
                category: .maxVelocity,
                targetWeakness: ["stride_frequency", "foot_speed", "coordination"],
                description: "Rapid foot contacts through agility ladder. Develops high stride frequency and neuromuscular speed.",
                coachingCues: [
                    "Quick light contacts",
                    "Stay on balls of feet",
                    "Arms pump in rhythm",
                    "Eyes forward, not down"
                ],
                sets: "4-6",
                reps: "Through ladder 2-3x",
                videoURL: nil,
                thumbnailURL: nil,
                difficulty: .beginner,
                equipment: ["Agility ladder"],
                progressionDrills: ["wicket_runs", "downhill_sprints"],
                regressionDrills: ["high_knees"]
            ),

            Drill(
                id: "hurdle_hops",
                name: "Hurdle Hops",
                category: .strength,
                targetWeakness: ["power", "knee_drive", "symmetry"],
                description: "Two-foot jumps over mini hurdles for bilateral power and coordination.",
                coachingCues: [
                    "Drive knees up to clear hurdles",
                    "Land softly and rebound immediately",
                    "Maintain rhythm across all hurdles",
                    "Arms assist the jump"
                ],
                sets: "4-5",
                reps: "8-10 hurdles",
                videoURL: nil,
                thumbnailURL: nil,
                difficulty: .intermediate,
                equipment: ["Mini hurdles"],
                progressionDrills: ["single_leg_bounds", "depth_jumps"],
                regressionDrills: ["step_ups"]
            ),

            Drill(
                id: "active_recovery",
                name: "Active Recovery Walk/Jog",
                category: .recovery,
                targetWeakness: ["recovery"],
                description: "Light walking or jogging to promote blood flow and recovery between sessions.",
                coachingCues: [
                    "Easy, conversational pace",
                    "Focus on relaxation",
                    "Hydrate throughout",
                    "Include light stretching"
                ],
                sets: "1",
                reps: "20-30 minutes",
                videoURL: nil,
                thumbnailURL: nil,
                difficulty: .beginner,
                equipment: [],
                progressionDrills: [],
                regressionDrills: []
            ),

            Drill(
                id: "overspeed_towing",
                name: "Overspeed Towing",
                category: .maxVelocity,
                targetWeakness: ["max_velocity", "stride_frequency", "overspeed"],
                description: "Athlete pulled by elastic cord or device faster than max speed. Trains supramaximal neuromuscular patterns.",
                coachingCues: [
                    "Maintain perfect sprint mechanics",
                    "Don't let it collapse your form",
                    "Maximum relaxation",
                    "Only use with experienced athletes"
                ],
                sets: "3-5",
                reps: "30-40m",
                videoURL: nil,
                thumbnailURL: nil,
                difficulty: .elite,
                equipment: ["Towing device or bungee cord", "Partner"],
                progressionDrills: [],
                regressionDrills: ["downhill_sprints", "flying_30s"]
            )
        ]
    }
}
