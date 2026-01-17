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
    @State private var rotation: Double = 0

    var body: some View {
        VStack(spacing: 20) {
            // Animated kanji character
            Text("漢")
                .font(.system(size: 80))
                .rotationEffect(.degrees(rotation))
                .animation(
                    .linear(duration: 2)
                    .repeatForever(autoreverses: false),
                    value: rotation
                )
                .onAppear {
                    rotation = 360
                }

            Text("Loading Kanji Data...")
                .font(.headline)
                .foregroundStyle(.secondary)

            ProgressView()
                .progressViewStyle(.circular)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
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
