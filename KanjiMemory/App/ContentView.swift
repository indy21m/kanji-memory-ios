import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var dataManager = DataManager.shared
    @State private var selectedTab = 0
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                LoadingView()
            } else {
                TabView(selection: $selectedTab) {
                    HomeView()
                        .tabItem {
                            Label("Home", systemImage: "house.fill")
                        }
                        .tag(0)

                    LevelsView()
                        .tabItem {
                            Label("Levels", systemImage: "books.vertical.fill")
                        }
                        .tag(1)

                    ReviewsView()
                        .tabItem {
                            Label("Reviews", systemImage: "flame.fill")
                        }
                        .tag(2)

                    SettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "gearshape.fill")
                        }
                        .tag(3)
                }
                .tint(.purple)
                .onChange(of: selectedTab) { _, _ in
                    HapticManager.selection()
                }
            }
        }
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        // Load bundled JSON data on first launch
        await dataManager.loadBundledData()

        // Check auth state and refresh profile if authenticated
        if authManager.isAuthenticated {
            await authManager.refreshProfile()
        }

        // Initialize review queue for new users (Level 1 kanji)
        await initializeReviewQueueIfNeeded()

        isLoading = false
    }

    private func initializeReviewQueueIfNeeded() async {
        // Check if we have any KanjiProgress entries
        let descriptor = FetchDescriptor<KanjiProgress>()
        let existingProgress = (try? modelContext.fetch(descriptor)) ?? []

        // If no progress exists, create entries for Level 1 kanji
        if existingProgress.isEmpty {
            let level1Kanji = dataManager.getKanji(byLevel: 1)
            for kanji in level1Kanji {
                let progress = KanjiProgress(
                    character: kanji.character,
                    level: kanji.level,
                    srsStage: .lesson,
                    nextReviewAt: Date(), // Due now for new lessons
                    wanikaniId: kanji.wanikaniId
                )
                modelContext.insert(progress)
            }
            try? modelContext.save()
            print("Initialized \(level1Kanji.count) Level 1 kanji for review")
        }
    }
}

struct LoadingView: View {
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 24) {
            // Penguin logo with pulse animation
            Text("🐧")
                .font(.system(size: 80))
                .scaleEffect(isPulsing ? 1.1 : 1.0)
                .animation(
                    .easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: true),
                    value: isPulsing
                )

            VStack(spacing: 8) {
                Text("Penguin Sensei")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("Loading kanji data...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ProgressView()
                .progressViewStyle(.circular)
                .tint(.purple)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear {
            isPulsing = true
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager.shared)
        .modelContainer(for: [
            KanjiProgress.self,
            RadicalProgress.self,
            VocabularyProgress.self,
            CachedImage.self,
            UserSettings.self
        ], inMemory: true)
}
