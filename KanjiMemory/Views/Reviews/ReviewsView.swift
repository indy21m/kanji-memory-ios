import SwiftUI
import SwiftData

// Filter enum for review item types
enum ReviewItemTypeFilter: String, CaseIterable {
    case all = "All"
    case radicals = "Radicals"
    case kanji = "Kanji"
    case vocabulary = "Vocab"

    var color: Color {
        switch self {
        case .all: return .purple
        case .radicals: return .blue
        case .kanji: return .purple
        case .vocabulary: return .green
        }
    }
}

// Unified review item for display
struct DueReviewItem: Identifiable {
    enum ItemType {
        case radical
        case kanji
        case vocabulary
    }

    let id: String
    let type: ItemType
    let displayText: String
    let srsStage: SRSStage
    let nextReviewAt: Date
    let level: Int  // For level filtering

    var typeIndicator: String {
        switch type {
        case .radical: return "R"
        case .kanji: return "K"
        case .vocabulary: return "V"
        }
    }

    var typeColor: Color {
        switch type {
        case .radical: return .blue
        case .kanji: return .purple
        case .vocabulary: return .green
        }
    }
}

struct ReviewsView: View {
    // Query all three progress types
    @Query(filter: #Predicate<KanjiProgress> { $0.nextReviewAt != nil },
           sort: \KanjiProgress.nextReviewAt) private var kanjiProgress: [KanjiProgress]

    @Query(filter: #Predicate<RadicalProgress> { $0.nextReviewAt != nil },
           sort: \RadicalProgress.nextReviewAt) private var radicalProgress: [RadicalProgress]

    @Query(filter: #Predicate<VocabularyProgress> { $0.nextReviewAt != nil },
           sort: \VocabularyProgress.nextReviewAt) private var vocabProgress: [VocabularyProgress]

    @StateObject private var dataManager = DataManager.shared

    // Filter state
    @State private var selectedTypeFilter: ReviewItemTypeFilter = .all
    @State private var selectedLevelRange: ClosedRange<Int>? = nil  // nil = all levels

    // Cached computed values
    @State private var cachedDueItems: [DueReviewItem] = []
    @State private var cachedUpcomingCount: Int = 0
    @State private var lastRefresh: Date = .distantPast

    // Filtered items based on current filter selection
    private var filteredItems: [DueReviewItem] {
        var items = cachedDueItems

        // Filter by type
        switch selectedTypeFilter {
        case .all:
            break
        case .radicals:
            items = items.filter { $0.type == .radical }
        case .kanji:
            items = items.filter { $0.type == .kanji }
        case .vocabulary:
            items = items.filter { $0.type == .vocabulary }
        }

        // Filter by level range
        if let range = selectedLevelRange {
            items = items.filter { range.contains($0.level) }
        }

        return items
    }

    // Count by type for filter badges
    private var radicalCount: Int { cachedDueItems.filter { $0.type == .radical }.count }
    private var kanjiCount: Int { cachedDueItems.filter { $0.type == .kanji }.count }
    private var vocabCount: Int { cachedDueItems.filter { $0.type == .vocabulary }.count }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter bar
                if !cachedDueItems.isEmpty {
                    reviewFilterBar
                }

                // Content
                if cachedDueItems.isEmpty {
                    EmptyReviewsView(upcomingCount: cachedUpcomingCount)
                } else if filteredItems.isEmpty {
                    // All items filtered out
                    noMatchingItemsView
                } else {
                    ReviewQueueView(items: filteredItems)
                }
            }
            .navigationTitle("Reviews")
        }
        .onAppear {
            refreshIfNeeded()
        }
        .onChange(of: kanjiProgress.count) { _, _ in refreshIfNeeded() }
        .onChange(of: radicalProgress.count) { _, _ in refreshIfNeeded() }
        .onChange(of: vocabProgress.count) { _, _ in refreshIfNeeded() }
    }

    // MARK: - Filter Bar
    private var reviewFilterBar: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Type filters
                    ForEach(ReviewItemTypeFilter.allCases, id: \.self) { filter in
                        FilterChip(
                            label: filterLabel(for: filter),
                            isSelected: selectedTypeFilter == filter,
                            color: filter.color
                        ) {
                            HapticManager.selection()
                            selectedTypeFilter = filter
                        }
                    }

                    Divider()
                        .frame(height: 24)

                    // Level filter menu
                    Menu {
                        Button("All Levels") {
                            selectedLevelRange = nil
                        }
                        Divider()
                        Button("Level 1-10") {
                            selectedLevelRange = 1...10
                        }
                        Button("Level 11-20") {
                            selectedLevelRange = 11...20
                        }
                        Button("Level 21-30") {
                            selectedLevelRange = 21...30
                        }
                        Button("Level 31-40") {
                            selectedLevelRange = 31...40
                        }
                        Button("Level 41-50") {
                            selectedLevelRange = 41...50
                        }
                        Button("Level 51-60") {
                            selectedLevelRange = 51...60
                        }
                    } label: {
                        FilterChip(
                            label: levelFilterLabel,
                            isSelected: selectedLevelRange != nil,
                            color: .purple
                        ) {}
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
    }

    private func filterLabel(for filter: ReviewItemTypeFilter) -> String {
        switch filter {
        case .all:
            return "All (\(cachedDueItems.count))"
        case .radicals:
            return "R (\(radicalCount))"
        case .kanji:
            return "K (\(kanjiCount))"
        case .vocabulary:
            return "V (\(vocabCount))"
        }
    }

    private var levelFilterLabel: String {
        if let range = selectedLevelRange {
            return "Lvl \(range.lowerBound)-\(range.upperBound)"
        }
        return "All Levels"
    }

    // MARK: - No Matching Items View
    private var noMatchingItemsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)

            Text("No matching reviews")
                .font(.headline)

            Text("Try adjusting your filters")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Clear Filters") {
                selectedTypeFilter = .all
                selectedLevelRange = nil
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private func refreshIfNeeded() {
        // Only refresh if data changed or more than 1 second since last refresh
        guard Date().timeIntervalSince(lastRefresh) > 1 else { return }
        lastRefresh = Date()

        // Build lookup dictionaries for fast access (O(1) instead of O(n))
        // Use reduce to safely handle potential duplicates (last one wins)
        let radicalLookup = dataManager.allRadicals.reduce(into: [Int: Radical]()) { $0[$1.id] = $1 }
        let vocabLookup = dataManager.allVocabulary.reduce(into: [Int: Vocabulary]()) { $0[$1.id] = $1 }
        let kanjiLookup = dataManager.allKanji.reduce(into: [String: Kanji]()) { $0[$1.character] = $1 }

        let now = Date()
        var items: [DueReviewItem] = []
        var upcoming = 0

        // Process radicals
        for progress in radicalProgress {
            guard let reviewDate = progress.nextReviewAt else { continue }
            if reviewDate <= now {
                if let radical = radicalLookup[progress.radicalId] {
                    items.append(DueReviewItem(
                        id: "radical-\(progress.radicalId)",
                        type: .radical,
                        displayText: radical.displayCharacter,
                        srsStage: progress.srs,
                        nextReviewAt: reviewDate,
                        level: radical.level
                    ))
                }
            } else {
                upcoming += 1
            }
        }

        // Process kanji
        for progress in kanjiProgress {
            guard let reviewDate = progress.nextReviewAt else { continue }
            if reviewDate <= now {
                let level = kanjiLookup[progress.character]?.level ?? progress.level
                items.append(DueReviewItem(
                    id: "kanji-\(progress.character)",
                    type: .kanji,
                    displayText: progress.character,
                    srsStage: progress.srs,
                    nextReviewAt: reviewDate,
                    level: level
                ))
            } else {
                upcoming += 1
            }
        }

        // Process vocabulary
        for progress in vocabProgress {
            guard let reviewDate = progress.nextReviewAt else { continue }
            if reviewDate <= now {
                if let vocab = vocabLookup[progress.vocabularyId] {
                    items.append(DueReviewItem(
                        id: "vocab-\(progress.vocabularyId)",
                        type: .vocabulary,
                        displayText: vocab.characters,
                        srsStage: progress.srs,
                        nextReviewAt: reviewDate,
                        level: vocab.level
                    ))
                }
            } else {
                upcoming += 1
            }
        }

        cachedDueItems = items.sorted { $0.nextReviewAt < $1.nextReviewAt }
        cachedUpcomingCount = upcoming
    }
}

struct EmptyReviewsView: View {
    var upcomingCount: Int = 0

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("All caught up!")
                .font(.title2)
                .fontWeight(.bold)

            Text("No reviews due right now.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if upcomingCount > 0 {
                Text("\(upcomingCount) reviews coming up later")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }

            NavigationLink(destination: LevelsView()) {
                Text("Learn New Kanji")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.purple)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

struct ReviewQueueView: View {
    let items: [DueReviewItem]

    var body: some View {
        VStack(spacing: 16) {
            // Stats header with glassmorphism
            HStack(spacing: 24) {
                VStack {
                    Text("\(items.count)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("Due")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()
                    .frame(height: 40)

                VStack {
                    Text("0")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Completed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
            )
            .padding(.horizontal)

            // Start button
            NavigationLink(destination: ReviewSessionView()) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Reviews")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.purple, .indigo],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)

            // Queue list
            List {
                ForEach(items.prefix(20)) { item in
                    HStack {
                        Text(item.displayText)
                            .font(.title2)
                            .frame(minWidth: 40)

                        // Type indicator
                        Text(item.typeIndicator)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(item.typeColor)
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                        Spacer()

                        SRSBadge(stage: item.srsStage)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Filter Chip Component
struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color.opacity(0.2) : Color(.tertiarySystemFill))
                .foregroundColor(isSelected ? color : .primary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? color : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ReviewsView()
        .modelContainer(for: [KanjiProgress.self, RadicalProgress.self, VocabularyProgress.self], inMemory: true)
}
