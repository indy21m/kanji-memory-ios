import SwiftUI
import SwiftData

struct LevelsView: View {
    @StateObject private var dataManager = DataManager.shared
    @State private var searchText = ""

    private var filteredLevels: [Int] {
        Array(1...60)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    ForEach(filteredLevels, id: \.self) { level in
                        NavigationLink(destination: LevelDetailView(level: level)) {
                            LevelCard(level: level)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Levels")
            .searchable(text: $searchText, prompt: "Search kanji...")
        }
    }
}

struct LevelCard: View {
    let level: Int
    @StateObject private var dataManager = DataManager.shared

    private var stats: LevelStats {
        dataManager.getLevelStats(level: level)
    }

    var body: some View {
        VStack(spacing: 6) {
            // Level number
            Text("\(level)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.purple, Color.pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Stats row
            HStack(spacing: 8) {
                StatBadge(label: "漢", count: stats.kanjiCount, color: .purple)
                StatBadge(label: "部", count: stats.radicalCount, color: .blue)
                StatBadge(label: "語", count: stats.vocabularyCount, color: .green)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 0) // TODO: Calculate progress
                }
            }
            .frame(height: 3)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

struct StatBadge: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
            Text("\(count)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundColor(color)
    }
}

#Preview {
    LevelsView()
        .modelContainer(for: [KanjiProgress.self], inMemory: true)
}
