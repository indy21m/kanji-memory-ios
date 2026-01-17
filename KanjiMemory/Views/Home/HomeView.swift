import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var userSettings: [UserSettings]
    @StateObject private var dataManager = DataManager.shared

    private var settings: UserSettings? {
        userSettings.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Welcome Header
                    WelcomeHeader()

                    // Quick Stats
                    StatsCards()

                    // Review Button
                    ReviewButton()

                    // Current Level Progress
                    CurrentLevelCard()

                    // Recent Activity
                    RecentActivityCard()
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Kanji Memory")
        }
    }
}

struct WelcomeHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome back!")
                .font(.title2)
                .fontWeight(.bold)

            Text("Ready to learn some kanji?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StatsCards: View {
    @StateObject private var dataManager = DataManager.shared

    var body: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Kanji",
                value: "\(dataManager.allKanji.count)",
                icon: "character.book.closed.fill",
                color: .purple
            )

            StatCard(
                title: "Radicals",
                value: "\(dataManager.allRadicals.count)",
                icon: "square.grid.2x2.fill",
                color: .blue
            )

            StatCard(
                title: "Vocabulary",
                value: "\(dataManager.allVocabulary.count)",
                icon: "text.book.closed.fill",
                color: .green
            )
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

struct ReviewButton: View {
    var body: some View {
        NavigationLink(destination: ReviewSessionView()) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)

                VStack(alignment: .leading) {
                    Text("Start Review")
                        .font(.headline)
                    Text("0 items due")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                Image(systemName: "chevron.right")
            }
            .foregroundStyle(.white)
            .padding()
            .background(
                LinearGradient(
                    colors: [.purple, .indigo],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

struct CurrentLevelCard: View {
    @StateObject private var dataManager = DataManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Level 1")
                    .font(.headline)

                Spacer()

                NavigationLink(destination: LevelDetailView(level: 1)) {
                    Text("View All")
                        .font(.caption)
                        .foregroundStyle(.purple)
                }
            }

            // Preview of kanji
            let levelKanji = dataManager.getKanji(byLevel: 1)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                ForEach(levelKanji.prefix(12)) { kanji in
                    NavigationLink(destination: KanjiDetailView(kanji: kanji)) {
                        Text(kanji.character)
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(Color.purple.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

struct RecentActivityCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)

            VStack(spacing: 8) {
                Text("No recent activity")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [
            KanjiProgress.self,
            UserSettings.self
        ], inMemory: true)
}
