import SwiftUI
import SwiftData

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

    // Combine all due items
    private var dueItems: [DueReviewItem] {
        let now = Date()
        var items: [DueReviewItem] = []

        // Add due radicals
        for progress in radicalProgress {
            guard let reviewDate = progress.nextReviewAt, reviewDate <= now else { continue }
            if let radical = dataManager.allRadicals.first(where: { $0.id == progress.radicalId }) {
                items.append(DueReviewItem(
                    id: "radical-\(progress.radicalId)",
                    type: .radical,
                    displayText: radical.displayCharacter,
                    srsStage: progress.srs,
                    nextReviewAt: reviewDate
                ))
            }
        }

        // Add due kanji
        for progress in kanjiProgress {
            guard let reviewDate = progress.nextReviewAt, reviewDate <= now else { continue }
            items.append(DueReviewItem(
                id: "kanji-\(progress.character)",
                type: .kanji,
                displayText: progress.character,
                srsStage: progress.srs,
                nextReviewAt: reviewDate
            ))
        }

        // Add due vocabulary
        for progress in vocabProgress {
            guard let reviewDate = progress.nextReviewAt, reviewDate <= now else { continue }
            if let vocab = dataManager.allVocabulary.first(where: { $0.id == progress.vocabularyId }) {
                items.append(DueReviewItem(
                    id: "vocab-\(progress.vocabularyId)",
                    type: .vocabulary,
                    displayText: vocab.characters,
                    srsStage: progress.srs,
                    nextReviewAt: reviewDate
                ))
            }
        }

        return items.sorted { $0.nextReviewAt < $1.nextReviewAt }
    }

    // Count upcoming items
    private var upcomingCount: Int {
        let now = Date()
        let radicalUpcoming = radicalProgress.filter { ($0.nextReviewAt ?? .distantFuture) > now }.count
        let kanjiUpcoming = kanjiProgress.filter { ($0.nextReviewAt ?? .distantFuture) > now }.count
        let vocabUpcoming = vocabProgress.filter { ($0.nextReviewAt ?? .distantFuture) > now }.count
        return radicalUpcoming + kanjiUpcoming + vocabUpcoming
    }

    var body: some View {
        NavigationStack {
            VStack {
                if dueItems.isEmpty {
                    EmptyReviewsView(upcomingCount: upcomingCount)
                } else {
                    ReviewQueueView(items: dueItems)
                }
            }
            .navigationTitle("Reviews")
        }
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
            // Stats header
            HStack(spacing: 24) {
                VStack {
                    Text("\(items.count)")
                        .font(.title)
                        .fontWeight(.bold)
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
                    .fill(Color(.secondarySystemGroupedBackground))
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

#Preview {
    ReviewsView()
        .modelContainer(for: [KanjiProgress.self, RadicalProgress.self, VocabularyProgress.self], inMemory: true)
}
