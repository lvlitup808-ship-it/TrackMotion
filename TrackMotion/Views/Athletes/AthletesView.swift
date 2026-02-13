import SwiftUI
import PhotosUI

struct AthletesView: View {
    @StateObject private var store = AthleteStore.shared
    @State private var showingAddAthlete = false
    @State private var searchText = ""
    @State private var selectedFilter: EventType? = nil

    var filteredAthletes: [AthleteProfile] {
        var result = store.athletes
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        if let filter = selectedFilter {
            result = result.filter { $0.primaryEvents.contains(filter) }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter chips
                if !store.athletes.isEmpty {
                    filterRow
                }

                if store.athletes.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(filteredAthletes) { athlete in
                            NavigationLink {
                                AthleteDetailView(athlete: athlete)
                            } label: {
                                AthleteCardRow(athlete: athlete)
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        }
                        .onDelete { indices in
                            indices.forEach { store.removeAthlete(at: $0) }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .searchable(text: $searchText, prompt: "Search athletes")
            .navigationTitle("Athletes")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddAthlete = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddAthlete) {
            AddAthleteWizard()
        }
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "All", isSelected: selectedFilter == nil) {
                    selectedFilter = nil
                }
                ForEach(EventType.allCases) { event in
                    FilterChip(label: event.displayName, isSelected: selectedFilter == event) {
                        selectedFilter = selectedFilter == event ? nil : event
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color.backgroundSecondary)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 60))
                .foregroundStyle(.brandOrange.opacity(0.6))

            VStack(spacing: 8) {
                Text("No Athletes Yet")
                    .font(.title2.weight(.bold))

                Text("Add your first athlete to start tracking their sprint mechanics and progress.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                showingAddAthlete = true
            } label: {
                Label("Add First Athlete", systemImage: "person.badge.plus")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.brandOrange, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Athlete Card Row
struct AthleteCardRow: View {
    @ObservedObject var athlete: AthleteProfile

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.brandOrange.gradient)
                    .frame(width: 54, height: 54)

                if let image = athlete.profileImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 54, height: 54)
                        .clipShape(Circle())
                } else {
                    Text(athlete.name.prefix(2).uppercased())
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(athlete.name)
                    .font(.headline)

                HStack(spacing: 6) {
                    ForEach(athlete.primaryEvents.prefix(2)) { event in
                        Text(event.displayName)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.brandOrange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.brandOrange.opacity(0.15), in: Capsule())
                    }
                }

                if let lastSession = athlete.lastSession {
                    Text("Last: \(lastSession.displayDate)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Score badge
            VStack(spacing: 2) {
                Text("\(Int(athlete.overallScore))")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor(athlete.overallScore))
                Text("AVG")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
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

// MARK: - Filter Chip
struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.brandOrange : Color.backgroundPrimary,
                             in: Capsule())
        }
    }
}

// MARK: - Athlete Detail View
struct AthleteDetailView: View {
    @ObservedObject var athlete: AthleteProfile
    @State private var selectedTab = 0
    @State private var showingEdit = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                athleteHeader

                // Tabs
                Picker("", selection: $selectedTab) {
                    Text("Overview").tag(0)
                    Text("Sessions").tag(1)
                    Text("Goals").tag(2)
                    Text("Notes").tag(3)
                }
                .pickerStyle(.segmented)
                .padding()

                // Tab content
                switch selectedTab {
                case 0: overviewTab
                case 1: sessionsTab
                case 2: goalsTab
                case 3: notesTab
                default: EmptyView()
                }
            }
        }
        .navigationTitle(athlete.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            EditAthleteView(athlete: athlete)
        }
    }

    private var athleteHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.brandOrange.gradient)
                    .frame(width: 90, height: 90)

                if let image = athlete.profileImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 90, height: 90)
                        .clipShape(Circle())
                } else {
                    Text(athlete.name.prefix(2).uppercased())
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)
                }
            }

            Text(athlete.name)
                .font(.title.weight(.bold))

            HStack(spacing: 12) {
                Text("Age \(athlete.age)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("•")
                    .foregroundStyle(.secondary)
                Text(athlete.gender.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                ForEach(athlete.primaryEvents) { event in
                    Text(event.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.brandOrange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.brandOrange.opacity(0.15), in: Capsule())
                }
            }

            // Quick stats
            HStack(spacing: 24) {
                StatBadge(value: "\(Int(athlete.overallScore))", label: "Avg Score")
                StatBadge(value: "\(Int(athlete.bestFormScore))", label: "Best Score")
                StatBadge(value: "\(athlete.totalRuns)", label: "Total Runs")
                StatBadge(value: "\(athlete.sessions.count)", label: "Sessions")
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(Color.backgroundSecondary)
    }

    private var overviewTab: some View {
        VStack(spacing: 16) {
            // Recent recommendations
            if let lastSession = athlete.lastSession, let bestRun = lastSession.bestRun {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Latest Coaching Cues")
                        .font(.headline)
                        .padding(.horizontal, 16)

                    ForEach(bestRun.aiRecommendations.prefix(3)) { cue in
                        CoachingCueRow(cue: cue)
                            .padding(.horizontal, 16)
                    }
                }
            }

            // Personal records
            if !athlete.personalRecords.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Personal Records")
                        .font(.headline)
                        .padding(.horizontal, 16)

                    ForEach(Array(athlete.personalRecords.sorted(by: { $0.key.rawValue < $1.key.rawValue })), id: \.key) { event, time in
                        HStack {
                            Text(event.displayName)
                                .font(.subheadline)
                            Spacer()
                            Text(formatTime(time))
                                .font(.system(.subheadline, design: .monospaced).weight(.bold))
                                .foregroundStyle(.brandOrange)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                    }
                }
                .padding(.vertical, 12)
                .background(Color.backgroundSecondary, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 16)
    }

    private var sessionsTab: some View {
        VStack(spacing: 0) {
            ForEach(athlete.sessions.sorted { $0.date > $1.date }) { session in
                NavigationLink {
                    SessionDetailView(session: session)
                } label: {
                    SessionRowView(session: session)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .tint(.primary)
                Divider()
                    .padding(.leading, 16)
            }
        }
    }

    private var goalsTab: some View {
        VStack(spacing: 16) {
            ForEach(athlete.primaryEvents) { event in
                GoalProgressRow(
                    event: event,
                    goalTime: athlete.goalTimes[event],
                    prTime: athlete.personalRecords[event]
                )
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var notesTab: some View {
        TextEditor(text: Binding(
            get: { athlete.notes },
            set: { athlete.notes = $0 }
        ))
        .frame(minHeight: 200)
        .padding(16)
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let seconds = Int(interval)
        let ms = Int((interval - Double(seconds)) * 100)
        if seconds >= 60 {
            return String(format: "%d:%02d.%02d", seconds / 60, seconds % 60, ms)
        }
        return String(format: "%d.%02d", seconds, ms)
    }
}

struct StatBadge: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct CoachingCueRow: View {
    let cue: CoachingCue

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: priorityIcon)
                .foregroundStyle(Color(hex: cue.priority.color))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(cue.issue)
                    .font(.subheadline.weight(.medium))
                Text(cue.recommendation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var priorityIcon: String {
        switch cue.priority {
        case .high:   return "exclamationmark.circle.fill"
        case .medium: return "info.circle.fill"
        case .low:    return "checkmark.circle.fill"
        }
    }
}

struct GoalProgressRow: View {
    let event: EventType
    let goalTime: TimeInterval?
    let prTime: TimeInterval?

    var progress: Double {
        guard let goal = goalTime, let pr = prTime, goal > 0 else { return 0 }
        // Progress is inverse: lower time = better
        let maxTime = goal * 1.2 // 20% above goal as baseline
        let progress = (maxTime - pr) / (maxTime - goal)
        return max(0, min(1, progress))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(event.displayName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let pr = prTime {
                    Text("PR: \(formatTime(pr))")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.brandOrange)
                }
                if let goal = goalTime {
                    Text("Goal: \(formatTime(goal))")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: progress)
                .tint(progressColor)
        }
        .padding(12)
        .background(Color.backgroundSecondary, in: RoundedRectangle(cornerRadius: 12))
    }

    private var progressColor: Color {
        switch progress {
        case 0.8...1.0: return .formSuccess
        case 0.5..<0.8: return .formWarning
        default:         return .brandOrange
        }
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        String(format: "%.2f", interval)
    }
}

// MARK: - Add Athlete Wizard
struct AddAthleteWizard: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var store = AthleteStore.shared
    @State private var step = 0
    @State private var name = ""
    @State private var dateOfBirth = Date(timeIntervalSinceNow: -18 * 365 * 24 * 3600)
    @State private var gender: AthleteProfile.Gender = .preferNotToSay
    @State private var selectedEvents: Set<EventType> = [.sprint100m]
    @State private var goalTime100m = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImageData: Data?

    var body: some View {
        NavigationStack {
            VStack {
                // Progress indicator
                ProgressView(value: Double(step + 1), total: 4)
                    .tint(.brandOrange)
                    .padding(.horizontal)

                Text("Step \(step + 1) of 4")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                // Step content
                TabView(selection: $step) {
                    step1.tag(0)
                    step2.tag(1)
                    step3.tag(2)
                    step4.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: step)

                // Navigation buttons
                HStack {
                    if step > 0 {
                        Button("Back") { step -= 1 }
                            .buttonStyle(.bordered)
                    }
                    Spacer()
                    if step < 3 {
                        Button("Next") { step += 1 }
                            .buttonStyle(.borderedProminent)
                            .tint(.brandOrange)
                            .disabled(step == 0 && name.isEmpty)
                    } else {
                        Button("Create Athlete") {
                            createAthlete()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.brandOrange)
                    }
                }
                .padding()
            }
            .navigationTitle("New Athlete")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var step1: some View {
        Form {
            Section("Basic Info") {
                TextField("Full Name", text: $name)
                DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                Picker("Gender", selection: $gender) {
                    ForEach(AthleteProfile.Gender.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
            }

            Section("Profile Photo (Optional)") {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    HStack {
                        if let data = profileImageData, let img = UIImage(data: data) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                        }
                        Text("Choose Photo")
                    }
                }
                .onChange(of: selectedPhoto) { _, photo in
                    Task {
                        profileImageData = try? await photo?.loadTransferable(type: Data.self)
                    }
                }
            }
        }
        .tag(0)
    }

    private var step2: some View {
        Form {
            Section("Primary Events") {
                ForEach(EventType.allCases) { event in
                    Toggle(event.displayName, isOn: Binding(
                        get: { selectedEvents.contains(event) },
                        set: { isOn in
                            if isOn { selectedEvents.insert(event) }
                            else { selectedEvents.remove(event) }
                        }
                    ))
                }
            }
        }
        .tag(1)
    }

    private var step3: some View {
        Form {
            Section("Goal Times (Optional)") {
                TextField("100m Goal (e.g. 10.80)", text: $goalTime100m)
                    .keyboardType(.decimalPad)
            }

            Section {
                Text("Goal times help us calculate progress percentage and personalize coaching recommendations.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .tag(2)
    }

    private var step4: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.formSuccess)

            Text("Ready to Create Profile")
                .font(.title2.weight(.bold))

            VStack(alignment: .leading, spacing: 8) {
                summaryRow(label: "Name", value: name)
                summaryRow(label: "Age", value: "\(Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0)")
                summaryRow(label: "Events", value: selectedEvents.map { $0.displayName }.joined(separator: ", "))
            }
            .padding()
            .background(Color.backgroundSecondary, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
        .padding()
        .tag(3)
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
        }
    }

    private func createAthlete() {
        var goalTimes: [EventType: TimeInterval] = [:]
        if let time = Double(goalTime100m) {
            goalTimes[.sprint100m] = time
        }

        let athlete = AthleteProfile(
            name: name,
            dateOfBirth: dateOfBirth,
            gender: gender,
            primaryEvents: Array(selectedEvents),
            goalTimes: goalTimes,
            profileImageData: profileImageData
        )

        store.addAthlete(athlete)
        dismiss()
    }
}

struct EditAthleteView: View {
    @ObservedObject var athlete: AthleteProfile
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    TextField("Name", text: $athlete.name)
                    DatePicker("Date of Birth", selection: $athlete.dateOfBirth, displayedComponents: .date)
                    Picker("Gender", selection: $athlete.gender) {
                        ForEach(AthleteProfile.Gender.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                }

                Section("Notes") {
                    TextEditor(text: $athlete.notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Edit Athlete")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
