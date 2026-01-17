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
                    // Penguin Header
                    PenguinHeader()

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
            .navigationTitle("Penguin Sensei")
        }
    }
}

struct PenguinHeader: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("🐧")
                .font(.system(size: 60))

            VStack(spacing: 4) {
                Text("Welcome back!")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Ready to master some kanji?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

struct StatsCards: View {
    @StateObject private var dataManager = DataManager.shared

    var body: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Kanji",
                value: "\(dataManager.allKanji.count)",
                icon: "漢",
                color: .purple,
                isEmoji: true
            )

            StatCard(
                title: "Radicals",
                value: "\(dataManager.allRadicals.count)",
                icon: "部",
                color: .blue,
                isEmoji: true
            )

            StatCard(
                title: "Vocabulary",
                value: "\(dataManager.allVocabulary.count)",
                icon: "語",
                color: .green,
                isEmoji: true
            )
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var isEmoji: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            if isEmoji {
                Text(icon)
                    .font(.title2)
                    .foregroundStyle(color)
            } else {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
            }

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
                    colors: [.purple, .pink],
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
                HStack(spacing: 4) {
                    Text("📚")
                    Text("Level 1")
                        .font(.headline)
                }

                Spacer()

                NavigationLink(destination: LevelDetailView(level: 1)) {
                    Text("View All")
                        .font(.caption)
                        .fontWeight(.medium)
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
                            .background(
                                LinearGradient(
                                    colors: [.purple.opacity(0.2), .pink.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
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
            HStack(spacing: 4) {
                Text("📊")
                Text("Recent Activity")
                    .font(.headline)
            }

            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary.opacity(0.5))

                Text("Start learning to see your progress!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
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
