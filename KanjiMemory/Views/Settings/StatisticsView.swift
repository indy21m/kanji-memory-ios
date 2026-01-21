import SwiftUI
import SwiftData

/// Statistics view showing review performance and SRS distribution
/// Web app inspired design with colorful stat cards and progress visualization
struct StatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var kanjiProgress: [KanjiProgress]
    @Query private var radicalProgress: [RadicalProgress]
    @Query private var vocabularyProgress: [VocabularyProgress]
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Computed Stats

    /// Total reviews completed (approximated from progress data)
    private var totalReviews: Int {
        kanjiProgress.reduce(0) { $0 + $1.timesReviewed }
    }

    /// Overall accuracy percentage
    private var accuracy: Int {
        let totalReviewed = kanjiProgress.reduce(0) { $0 + $1.timesReviewed }
        let totalCorrect = kanjiProgress.reduce(0) { $0 + $1.timesCorrect }
        guard totalReviewed > 0 else { return 100 }
        return Int(Double(totalCorrect) / Double(totalReviewed) * 100)
    }

    /// Total items learned (Guru+)
    private var itemsLearned: Int {
        let kanjiLearned = kanjiProgress.filter { $0.srs.isLearned }.count
        let radicalLearned = radicalProgress.filter { $0.srs.isLearned }.count
        let vocabLearned = vocabularyProgress.filter { $0.srs.isLearned }.count
        return kanjiLearned + radicalLearned + vocabLearned
    }

    /// Reviews due today
    private var reviewsToday: Int {
        let now = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let kanjiDue = kanjiProgress.filter { progress in
            guard let reviewAt = progress.nextReviewAt else { return false }
            return reviewAt >= startOfDay && reviewAt < endOfDay
        }.count

        let radicalDue = radicalProgress.filter { progress in
            guard let reviewAt = progress.nextReviewAt else { return false }
            return reviewAt >= startOfDay && reviewAt < endOfDay
        }.count

        let vocabDue = vocabularyProgress.filter { progress in
            guard let reviewAt = progress.nextReviewAt else { return false }
            return reviewAt >= startOfDay && reviewAt < endOfDay
        }.count

        return kanjiDue + radicalDue + vocabDue
    }

    // MARK: - SRS Distribution

    private func countForStage(_ stage: SRSStage) -> Int {
        let kanjiCount = kanjiProgress.filter { $0.srs == stage }.count
        let radicalCount = radicalProgress.filter { $0.srs == stage }.count
        let vocabCount = vocabularyProgress.filter { $0.srs == stage }.count
        return kanjiCount + radicalCount + vocabCount
    }

    /// Grouped SRS stages for display
    private var srsDistribution: [(name: String, color: Color, count: Int)] {
        [
            ("Apprentice", SRSStage.apprentice1.indicatorColor,
             countForStage(.apprentice1) + countForStage(.apprentice2) + countForStage(.apprentice3) + countForStage(.apprentice4)),
            ("Guru", SRSStage.guru1.indicatorColor,
             countForStage(.guru1) + countForStage(.guru2)),
            ("Master", SRSStage.master.indicatorColor,
             countForStage(.master)),
            ("Enlightened", SRSStage.enlightened.indicatorColor,
             countForStage(.enlightened)),
            ("Burned", SRSStage.burned.indicatorColor,
             countForStage(.burned))
        ]
    }

    /// Total items in the system
    private var totalItems: Int {
        srsDistribution.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                Text("Your Progress")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.top, 8)

                // Stats cards grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatsCard(title: "Total Reviews", value: "\(totalReviews)", icon: "chart.bar.fill", color: .purple)
                    StatsCard(title: "Accuracy", value: "\(accuracy)%", icon: "checkmark.circle.fill", color: .green)
                    StatsCard(title: "Items Learned", value: "\(itemsLearned)", icon: "book.fill", color: .blue)
                    StatsCard(title: "Due Today", value: "\(reviewsToday)", icon: "calendar", color: .orange)
                }

                // SRS Stage Distribution
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "chart.pie.fill")
                            .foregroundStyle(.purple)
                        Text("SRS Distribution")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }

                    if totalItems > 0 {
                        // Progress bar visualization
                        GeometryReader { geometry in
                            HStack(spacing: 2) {
                                ForEach(srsDistribution, id: \.name) { stage in
                                    if stage.count > 0 {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(stage.color)
                                            .frame(width: geometry.size.width * CGFloat(stage.count) / CGFloat(totalItems))
                                    }
                                }
                            }
                        }
                        .frame(height: 12)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .padding(.bottom, 8)
                    }

                    // Stage list
                    ForEach(srsDistribution, id: \.name) { stage in
                        SRSStageRow(name: stage.name, color: stage.color, count: stage.count)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colorScheme == .dark
                            ? Color.white.opacity(0.05)
                            : Color.white.opacity(0.7))
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                        )
                )

                // Content type breakdown
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "square.grid.3x3.fill")
                            .foregroundStyle(.blue)
                        Text("Content Breakdown")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }

                    ContentTypeRow(
                        label: "漢 Kanji",
                        learned: kanjiProgress.filter { $0.srs.isLearned }.count,
                        total: kanjiProgress.count,
                        color: .purple
                    )

                    ContentTypeRow(
                        label: "部 Radicals",
                        learned: radicalProgress.filter { $0.srs.isLearned }.count,
                        total: radicalProgress.count,
                        color: .blue
                    )

                    ContentTypeRow(
                        label: "語 Vocabulary",
                        learned: vocabularyProgress.filter { $0.srs.isLearned }.count,
                        total: vocabularyProgress.count,
                        color: .green
                    )
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colorScheme == .dark
                            ? Color.white.opacity(0.05)
                            : Color.white.opacity(0.7))
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                        )
                )

                Spacer(minLength: 20)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Statistics")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Stats Card (Statistics View specific)

struct StatsCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(color)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark
                    ? Color.white.opacity(0.05)
                    : Color.white.opacity(0.7))
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - SRS Stage Row

struct SRSStageRow: View {
    let name: String
    let color: Color
    let count: Int

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)

            Text(name)
                .font(.subheadline)

            Spacer()

            Text("\(count)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
    }
}

// MARK: - Content Type Row

struct ContentTypeRow: View {
    let label: String
    let learned: Int
    let total: Int
    let color: Color

    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(learned) / Double(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(color)

                Spacer()

                Text("\(learned)/\(total)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 6)
        }
    }
}

#Preview {
    NavigationStack {
        StatisticsView()
    }
    .modelContainer(for: [KanjiProgress.self, RadicalProgress.self, VocabularyProgress.self], inMemory: true)
}
