import SwiftUI
import SwiftData

struct ReviewsView: View {
    @Query(filter: #Predicate<KanjiProgress> { progress in
        progress.nextReviewAt != nil
    }, sort: \KanjiProgress.nextReviewAt) private var allItemsWithReviewDate: [KanjiProgress]

    // Filter for items that are actually due NOW (nextReviewAt <= current time)
    private var dueItems: [KanjiProgress] {
        let now = Date()
        return allItemsWithReviewDate.filter { progress in
            guard let reviewDate = progress.nextReviewAt else { return false }
            return reviewDate <= now
        }
    }

    // Items with future review dates (for display purposes)
    private var upcomingItems: [KanjiProgress] {
        let now = Date()
        return allItemsWithReviewDate.filter { progress in
            guard let reviewDate = progress.nextReviewAt else { return false }
            return reviewDate > now
        }
    }

    var body: some View {
        NavigationStack {
            VStack {
                if dueItems.isEmpty {
                    EmptyReviewsView(upcomingCount: upcomingItems.count)
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
    let items: [KanjiProgress]

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
                        Text(item.character)
                            .font(.title2)
                            .frame(width: 40)

                        VStack(alignment: .leading) {
                            Text("Level \(item.level)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        SRSBadge(stage: item.srs)
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
        .modelContainer(for: [KanjiProgress.self], inMemory: true)
}
