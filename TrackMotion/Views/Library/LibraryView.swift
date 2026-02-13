import SwiftUI

struct LibraryView: View {
    @State private var searchText = ""
    @State private var selectedCategory: Drill.DrillCategory? = nil
    @State private var selectedDifficulty: Drill.Difficulty? = nil
    private let library = DrillLibrary.shared

    var filteredDrills: [Drill] {
        var drills = library.drills
        if !searchText.isEmpty {
            drills = drills.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText) ||
                $0.targetWeakness.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        if let cat = selectedCategory {
            drills = drills.filter { $0.category == cat }
        }
        if let diff = selectedDifficulty {
            drills = drills.filter { $0.difficulty == diff }
        }
        return drills
    }

    var groupedDrills: [(Drill.DrillCategory, [Drill])] {
        if selectedCategory != nil || !searchText.isEmpty || selectedDifficulty != nil {
            let grouped = Dictionary(grouping: filteredDrills) { $0.category }
            return grouped.sorted { $0.key.rawValue < $1.key.rawValue }
        }

        let grouped = Dictionary(grouping: library.drills) { $0.category }
        return grouped.sorted { $0.key.rawValue < $1.key.rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category filter
                categoryFilter

                // Difficulty filter
                difficultyFilter

                // Drill list
                List {
                    ForEach(groupedDrills, id: \.0) { category, drills in
                        Section {
                            ForEach(drills) { drill in
                                NavigationLink {
                                    DrillDetailView(drill: drill)
                                } label: {
                                    DrillRow(drill: drill)
                                }
                            }
                        } header: {
                            CategorySectionHeader(category: category)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .searchable(text: $searchText, prompt: "Search drills...")
            .navigationTitle("Drill Library")
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(Drill.DrillCategory.allCases, id: \.self) { cat in
                    FilterChip(label: cat.rawValue, isSelected: selectedCategory == cat) {
                        selectedCategory = selectedCategory == cat ? nil : cat
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color.backgroundSecondary)
    }

    private var difficultyFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "Any Level", isSelected: selectedDifficulty == nil) {
                    selectedDifficulty = nil
                }
                ForEach(Drill.Difficulty.allCases, id: \.self) { diff in
                    FilterChip(
                        label: diff.rawValue,
                        isSelected: selectedDifficulty == diff
                    ) {
                        selectedDifficulty = selectedDifficulty == diff ? nil : diff
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }
}

struct CategorySectionHeader: View {
    let category: Drill.DrillCategory

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: categoryIcon)
                .foregroundStyle(.brandOrange)
            Text(category.rawValue.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
    }

    private var categoryIcon: String {
        switch category {
        case .warmup:         return "flame.fill"
        case .acceleration:   return "bolt.fill"
        case .maxVelocity:    return "speedometer"
        case .armMechanics:   return "figure.arms.open"
        case .blockStart:     return "figure.run.circle.fill"
        case .strength:       return "dumbbell.fill"
        case .mobility:       return "figure.flexibility"
        case .speedEndurance: return "timer"
        case .recovery:       return "heart.fill"
        }
    }
}

struct DrillRow: View {
    let drill: Drill

    var body: some View {
        HStack(spacing: 12) {
            // Difficulty color indicator
            RoundedRectangle(cornerRadius: 4)
                .fill(difficultyColor)
                .frame(width: 4, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(drill.name)
                    .font(.subheadline.weight(.semibold))

                HStack(spacing: 6) {
                    Text(drill.sets + " sets × " + drill.reps)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.secondary)

                    Text(drill.difficulty.rawValue)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(difficultyColor)
                }
            }

            Spacer()

            // Equipment indicator
            if !drill.equipment.isEmpty {
                Image(systemName: "cube.box.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var difficultyColor: Color {
        switch drill.difficulty {
        case .beginner:     return .formSuccess
        case .intermediate: return .formWarning
        case .advanced:     return .brandOrange
        case .elite:        return .formError
        }
    }
}

// MARK: - Drill Detail View
struct DrillDetailView: View {
    let drill: Drill
    @State private var showingProgressions = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header card
                headerCard

                // Prescription
                prescriptionCard

                // Coaching cues
                coachingCuesCard

                // Equipment
                if !drill.equipment.isEmpty {
                    equipmentCard
                }

                // Target weaknesses
                targetMetricsCard

                // Progressions / regressions
                if !drill.progressionDrills.isEmpty || !drill.regressionDrills.isEmpty {
                    progressionCard
                }
            }
            .padding(16)
        }
        .navigationTitle(drill.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.backgroundPrimary)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(drill.category.rawValue.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.brandOrange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.brandOrange.opacity(0.15), in: Capsule())

                Spacer()

                Text(drill.difficulty.rawValue)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(difficultyColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(difficultyColor.opacity(0.15), in: Capsule())
            }

            Text(drill.description)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .padding(16)
        .background(Color.backgroundSecondary, in: RoundedRectangle(cornerRadius: 16))
    }

    private var prescriptionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prescription")
                .font(.headline)

            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text(drill.sets)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.brandOrange)
                    Text("SETS")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Divider()
                    .frame(height: 40)

                VStack(spacing: 4) {
                    Text(drill.reps)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.brandOrange)
                    Text("REPS/DISTANCE")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color.backgroundSecondary, in: RoundedRectangle(cornerRadius: 16))
    }

    private var coachingCuesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Coaching Cues", systemImage: "quote.bubble.fill")
                .font(.headline)

            ForEach(Array(drill.coachingCues.enumerated()), id: \.offset) { index, cue in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.brandOrange, in: Circle())
                    Text(cue)
                        .font(.subheadline)
                }
            }
        }
        .padding(16)
        .background(Color.backgroundSecondary, in: RoundedRectangle(cornerRadius: 16))
    }

    private var equipmentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Equipment Needed", systemImage: "cube.box.fill")
                .font(.headline)

            FlowLayout(items: drill.equipment) { item in
                Text(item)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.backgroundPrimary, in: Capsule())
            }
        }
        .padding(16)
        .background(Color.backgroundSecondary, in: RoundedRectangle(cornerRadius: 16))
    }

    private var targetMetricsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Targets", systemImage: "target")
                .font(.headline)

            FlowLayout(items: drill.targetWeakness.map { $0.replacingOccurrences(of: "_", with: " ").capitalized }) { item in
                Text(item)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.brandOrange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.brandOrange.opacity(0.15), in: Capsule())
            }
        }
        .padding(16)
        .background(Color.backgroundSecondary, in: RoundedRectangle(cornerRadius: 16))
    }

    private var progressionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progressions & Regressions")
                .font(.headline)

            if !drill.progressionDrills.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("More Advanced", systemImage: "arrow.up.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.formSuccess)
                    ForEach(DrillLibrary.shared.drills(for: drill.progressionDrills)) { d in
                        NavigationLink(d.name) {
                            DrillDetailView(drill: d)
                        }
                        .font(.subheadline)
                    }
                }
            }

            if !drill.regressionDrills.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Easier Alternative", systemImage: "arrow.down.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.formWarning)
                    ForEach(DrillLibrary.shared.drills(for: drill.regressionDrills)) { d in
                        NavigationLink(d.name) {
                            DrillDetailView(drill: d)
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.backgroundSecondary, in: RoundedRectangle(cornerRadius: 16))
    }

    private var difficultyColor: Color {
        switch drill.difficulty {
        case .beginner:     return .formSuccess
        case .intermediate: return .formWarning
        case .advanced:     return .brandOrange
        case .elite:        return .formError
        }
    }
}

// MARK: - Flow Layout
struct FlowLayout<T: Hashable, Content: View>: View {
    let items: [T]
    @ViewBuilder let content: (T) -> Content

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 80))],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(items, id: \.self) { item in
                content(item)
            }
        }
    }
}
