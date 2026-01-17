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
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
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
                .padding()
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
        VStack(spacing: 8) {
            Text("\(level)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(.purple)

            HStack(spacing: 4) {
                // Kanji count
                HStack(spacing: 2) {
                    Text("漢")
                        .font(.caption2)
                    Text("\(stats.kanjiCount)")
                        .font(.caption)
                }
                .foregroundStyle(.purple)

                // Radical count
                HStack(spacing: 2) {
                    Text("部")
                        .font(.caption2)
                    Text("\(stats.radicalCount)")
                        .font(.caption)
                }
                .foregroundStyle(.blue)

                // Vocab count
                HStack(spacing: 2) {
                    Text("語")
                        .font(.caption2)
                    Text("\(stats.vocabularyCount)")
                        .font(.caption)
                }
                .foregroundStyle(.green)
            }

            // Progress bar placeholder
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.purple)
                        .frame(width: 0) // TODO: Calculate progress
                }
            }
            .frame(height: 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

#Preview {
    LevelsView()
        .modelContainer(for: [KanjiProgress.self], inMemory: true)
}
