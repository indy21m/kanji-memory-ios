import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var authManager: AuthManager
    @Query private var userSettings: [UserSettings]
    @Query(filter: #Predicate<KanjiProgress> { progress in
        progress.nextReviewAt != nil
    }) private var allProgress: [KanjiProgress]
    @StateObject private var dataManager = DataManager.shared

    @State private var hasAppeared = false
    @State private var isRefreshing = false

    private var settings: UserSettings? {
        userSettings.first
    }

    private var dueReviewCount: Int {
        let now = Date()
        return allProgress.filter { progress in
            guard let nextReview = progress.nextReviewAt else { return false }
            return nextReview <= now
        }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Penguin Header
                    PenguinHeader(isAuthenticated: authManager.isAuthenticated)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: hasAppeared)

                    // Quick Stats
                    StatsCards()
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: hasAppeared)

                    // Review Button
                    ReviewButton(dueCount: dueReviewCount)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3), value: hasAppeared)

                    // Current Level Progress
                    CurrentLevelCard()
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.4), value: hasAppeared)

                    // Recent Activity
                    RecentActivityCard(progressCount: allProgress.count)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.5), value: hasAppeared)
                }
                .padding()
            }
            .background(
                // Subtle gradient background that adapts to color scheme
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color(.systemBackground), Color(.systemBackground)]
                        : [Color(.systemGroupedBackground), Color(.systemGroupedBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .refreshable {
                HapticManager.light()
                isRefreshing = true
                // Simulate refresh - in real app, this would sync data
                try? await Task.sleep(nanoseconds: 500_000_000)
                isRefreshing = false
                HapticManager.success()
            }
            .navigationTitle("Penguin Sensei")
            .onAppear {
                if !hasAppeared {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        hasAppeared = true
                    }
                }
            }
        }
    }
}

struct PenguinHeader: View {
    let isAuthenticated: Bool

    var body: some View {
        VStack(spacing: 12) {
            Text("🐧")
                .font(.system(size: 60))

            VStack(spacing: 4) {
                Text("Welcome back!")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(isAuthenticated ? "Ready to master some kanji?" : "Sign in to sync your progress")
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
    @Environment(\.colorScheme) var colorScheme
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
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 10, y: 5)
        )
    }
}

struct ReviewButton: View {
    let dueCount: Int
    @State private var isPressed = false

    var body: some View {
        NavigationLink(destination: ReviewSessionView()) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)

                VStack(alignment: .leading) {
                    Text("Start Review")
                        .font(.headline)
                    Text("\(dueCount) items due")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                if dueCount > 0 {
                    Text("\(dueCount)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.2))
                        .clipShape(Capsule())
                }

                Image(systemName: "chevron.right")
            }
            .foregroundStyle(.white)
            .padding()
            .background(
                LinearGradient(
                    colors: dueCount > 0 ? [.purple, .pink] : [.gray, .gray.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: dueCount > 0 ? .purple.opacity(0.3) : .clear, radius: 8, y: 4)
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        HapticManager.light()
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

struct CurrentLevelCard: View {
    @EnvironmentObject var authManager: AuthManager
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
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        )
    }
}

struct RecentActivityCard: View {
    let progressCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                Text("📊")
                Text("Recent Activity")
                    .font(.headline)
            }

            if progressCount > 0 {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.green)

                    Text("You're learning \(progressCount) kanji!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
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
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        )
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthManager.shared)
        .modelContainer(for: [
            KanjiProgress.self,
            UserSettings.self
        ], inMemory: true)
}
