import SwiftUI
import SwiftData

struct LevelsView: View {
    @StateObject private var dataManager = DataManager.shared
    @Query private var allProgress: [KanjiProgress]
    @State private var searchText = ""
    @State private var hasAppeared = false

    private var filteredLevels: [Int] {
        if searchText.isEmpty {
            return Array(1...60)
        }
        // Filter levels by search text (could be level number or kanji character)
        return Array(1...60).filter { level in
            String(level).contains(searchText) ||
            dataManager.getKanji(byLevel: level).contains { kanji in
                kanji.character.contains(searchText) ||
                kanji.meanings.contains { $0.lowercased().contains(searchText.lowercased()) }
            }
        }
    }

    /// Get progress count for a specific level
    private func getProgressForLevel(_ level: Int) -> (learned: Int, total: Int) {
        let levelProgress = allProgress.filter { $0.level == level }
        let learnedCount = levelProgress.filter { $0.srs.isLearned }.count
        let totalKanji = dataManager.getKanji(byLevel: level).count
        return (learnedCount, totalKanji)
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
                    ForEach(Array(filteredLevels.enumerated()), id: \.element) { index, level in
                        let progress = getProgressForLevel(level)
                        NavigationLink(destination: LevelDetailView(level: level)) {
                            LevelCard(
                                level: level,
                                learnedCount: progress.learned,
                                totalCount: progress.total
                            )
                        }
                        .buttonStyle(LevelCardButtonStyle())
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 20)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.8)
                            .delay(Double(index) * 0.02),
                            value: hasAppeared
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Levels")
            .searchable(text: $searchText, prompt: "Search kanji...")
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

/// Custom button style with haptic feedback
struct LevelCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticManager.light()
                }
            }
    }
}

struct LevelCard: View {
    let level: Int
    var learnedCount: Int = 0
    var totalCount: Int = 0

    @StateObject private var dataManager = DataManager.shared

    private var stats: LevelStats {
        dataManager.getLevelStats(level: level)
    }

    private var progressPercentage: CGFloat {
        guard totalCount > 0 else { return 0 }
        return CGFloat(learnedCount) / CGFloat(totalCount)
    }

    private var isComplete: Bool {
        totalCount > 0 && learnedCount == totalCount
    }

    var body: some View {
        VStack(spacing: 6) {
            // Level number with completion indicator
            ZStack {
                Text("\(level)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: isComplete ? [.green, .mint] : [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Completion checkmark
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.green)
                        .offset(x: 18, y: -10)
                }
            }

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
                                colors: isComplete ? [.green, .mint] : [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progressPercentage)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progressPercentage)
                }
            }
            .frame(height: 3)

            // Progress text (only show if there's progress)
            if learnedCount > 0 {
                Text("\(learnedCount)/\(totalCount)")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .overlay(
            // Subtle glow for completed levels
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isComplete ? Color.green.opacity(0.3) : Color.clear,
                    lineWidth: 2
                )
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
        .environmentObject(AuthManager.shared)
        .modelContainer(for: [KanjiProgress.self], inMemory: true)
}
