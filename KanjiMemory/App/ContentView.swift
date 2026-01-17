import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
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
                            Label("Levels", systemImage: "square.grid.3x3.fill")
                        }
                        .tag(1)

                    ReviewsView()
                        .tabItem {
                            Label("Reviews", systemImage: "brain.head.profile")
                        }
                        .tag(2)

                    SettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "gearshape.fill")
                        }
                        .tag(3)
                }
                .tint(.purple)
            }
        }
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        // Load bundled JSON data on first launch
        await dataManager.loadBundledData()
        isLoading = false
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
        .modelContainer(for: [
            KanjiProgress.self,
            RadicalProgress.self,
            VocabularyProgress.self,
            CachedImage.self,
            UserSettings.self
        ], inMemory: true)
}
