import WidgetKit
import SwiftUI

// MARK: - Widget Timeline Provider
struct TrackMotionWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TrackMotionEntry {
        TrackMotionEntry(
            date: Date(),
            athleteName: "Alex Johnson",
            overallScore: 78,
            lastSessionDate: "Today",
            formGrade: "B",
            sessionsThisWeek: 3,
            topIssue: "Knee drive"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TrackMotionEntry) -> Void) {
        let entry = loadCurrentEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TrackMotionEntry>) -> Void) {
        let entry = loadCurrentEntry()
        // Refresh widget every hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadCurrentEntry() -> TrackMotionEntry {
        // Read from shared UserDefaults (App Group)
        let defaults = UserDefaults(suiteName: "group.com.trackmotion.shared")
        let name = defaults?.string(forKey: "primaryAthleteName") ?? "Select Athlete"
        let score = defaults?.double(forKey: "primaryAthleteScore") ?? 0
        let sessionsCount = defaults?.integer(forKey: "sessionsThisWeek") ?? 0

        return TrackMotionEntry(
            date: Date(),
            athleteName: name,
            overallScore: Int(score),
            lastSessionDate: defaults?.string(forKey: "lastSessionDate") ?? "No sessions",
            formGrade: gradeFor(score: score),
            sessionsThisWeek: sessionsCount,
            topIssue: defaults?.string(forKey: "topIssue") ?? ""
        )
    }

    private func gradeFor(score: Double) -> String {
        switch score {
        case 90...100: return "A+"
        case 80..<90:  return "A"
        case 70..<80:  return "B"
        case 60..<70:  return "C"
        default:       return "D"
        }
    }
}

// MARK: - Widget Entry
struct TrackMotionEntry: TimelineEntry {
    var date: Date
    var athleteName: String
    var overallScore: Int
    var lastSessionDate: String
    var formGrade: String
    var sessionsThisWeek: Int
    var topIssue: String
}

// MARK: - Small Widget View
struct SmallWidgetView: View {
    let entry: TrackMotionEntry

    var body: some View {
        ZStack {
            Color(hex: "#0F0F0F")

            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "figure.run.circle.fill")
                        .foregroundStyle(.brandOrange)
                        .font(.system(size: 16))
                    Spacer()
                    Text("TM")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(entry.formGrade)
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(gradeColor)

                Text("FORM GRADE")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)

                Text("\(entry.sessionsThisWeek) sessions this week")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
        }
        .containerBackground(Color(hex: "#0F0F0F"), for: .widget)
    }

    private var gradeColor: Color {
        switch entry.formGrade {
        case "A+", "A": return .formSuccess
        case "B":       return .formWarning
        default:        return .formError
        }
    }
}

// MARK: - Medium Widget View
struct MediumWidgetView: View {
    let entry: TrackMotionEntry

    var body: some View {
        HStack(spacing: 16) {
            // Left: Score
            VStack(spacing: 4) {
                Text("\(entry.overallScore)")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(.brandOrange)
                Text("AVG SCORE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                Text(entry.athleteName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            Divider()
                .overlay(.white.opacity(0.2))

            // Right: Details
            VStack(alignment: .leading, spacing: 8) {
                Label("\(entry.sessionsThisWeek) this week", systemImage: "calendar.badge.checkmark")
                    .font(.caption)
                    .foregroundStyle(.primary)

                Label(entry.lastSessionDate, systemImage: "clock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !entry.topIssue.isEmpty {
                    Label(entry.topIssue, systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.formWarning)
                }

                Spacer()

                Text("TrackMotion")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.brandOrange)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .containerBackground(Color(hex: "#0F0F0F"), for: .widget)
    }
}

// MARK: - Widget Configuration
struct TrackMotionWidget: Widget {
    let kind = "TrackMotionWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TrackMotionWidgetProvider()) { entry in
            Group {
                SmallWidgetView(entry: entry)
            }
        }
        .configurationDisplayName("TrackMotion")
        .description("View your sprint form score and weekly training summary.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

// MARK: - Lock Screen Widget
struct LockScreenWidgetView: View {
    let entry: TrackMotionEntry

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "figure.run")
                .font(.caption)
            Text("\(entry.overallScore)")
                .font(.system(.caption, design: .monospaced).weight(.bold))
            Text("•")
            Text("\(entry.sessionsThisWeek)W")
                .font(.caption)
        }
        .containerBackground(.clear, for: .widget)
    }
}
