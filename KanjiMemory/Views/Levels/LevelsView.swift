import SwiftUI
import SwiftData

// MARK: - Level Filter Types
enum LevelRangeFilter: String, CaseIterable {
    case all = "All"
    case pleasant = "1-10"
    case painful = "11-20"
    case death = "21-30"
    case hell = "31-40"
    case paradise = "41-50"
    case reality = "51-60"

    var range: ClosedRange<Int>? {
        switch self {
        case .all: return nil
        case .pleasant: return 1...10
        case .painful: return 11...20
        case .death: return 21...30
        case .hell: return 31...40
        case .paradise: return 41...50
        case .reality: return 51...60
        }
    }

    var color: Color {
        switch self {
        case .all: return .purple
        case .pleasant: return .green
        case .painful: return .yellow
        case .death: return .orange
        case .hell: return .red
        case .paradise: return .cyan
        case .reality: return .purple
        }
    }
}

struct LevelsView: View {
    @StateObject private var dataManager = DataManager.shared
    @Query private var allProgress: [KanjiProgress]
    @State private var searchText = ""
    @State private var hasAppeared = false
    @State private var selectedFilter: LevelRangeFilter = .all
    @Environment(\.colorScheme) private var colorScheme

    private var filteredLevels: [Int] {
        var levels = Array(1...60)

        // Apply range filter
        if let range = selectedFilter.range {
            levels = levels.filter { range.contains($0) }
        }

        // Apply search filter
        if !searchText.isEmpty {
            levels = levels.filter { level in
                String(level).contains(searchText) ||
                dataManager.getKanji(byLevel: level).contains { kanji in
                    kanji.character.contains(searchText) ||
                    kanji.meanings.contains { $0.lowercased().contains(searchText.lowercased()) }
                }
            }
        }

        return levels
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
            VStack(spacing: 0) {
                // Styled filter chips
                LevelFilterBar(selectedFilter: $selectedFilter)

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
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
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

// MARK: - Styled Filter Bar
struct LevelFilterBar: View {
    @Binding var selectedFilter: LevelRangeFilter
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LevelRangeFilter.allCases, id: \.self) { filter in
                    StyledFilterChip(
                        label: filter.rawValue,
                        isSelected: selectedFilter == filter,
                        color: filter.color
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
                        HapticManager.selection()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(
            colorScheme == .dark
                ? Color(.systemBackground).opacity(0.8)
                : Color.white.opacity(0.8)
        )
        .background(.ultraThinMaterial)
    }
}

// MARK: - Styled Filter Chip
struct StyledFilterChip: View {
    let label: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    isSelected
                        ? AnyShapeStyle(LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                          ))
                        : AnyShapeStyle(colorScheme == .dark
                            ? Color(.tertiarySystemFill)
                            : Color.white)
                )
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: isSelected ? color.opacity(0.3) : .clear, radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
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
    var isCurrent: Bool = false  // True if this is the user's current WaniKani level

    @StateObject private var dataManager = DataManager.shared
    @Environment(\.colorScheme) private var colorScheme

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

    /// Status emoji based on completion state
    private var statusEmoji: String? {
        if isComplete { return "✨" }
        if isCurrent { return "📚" }
        return nil
    }

    var body: some View {
        VStack(spacing: 6) {
            // Level number with status badge
            HStack {
                Text("\(level)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: isComplete ? [.green, .mint] : isCurrent ? [.blue, .cyan] : [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Spacer()

                // Status badge
                if let emoji = statusEmoji {
                    Text(emoji)
                        .font(.system(size: 12))
                }
            }

            // Stats row with content type breakdown
            HStack(spacing: 6) {
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
                                colors: isComplete ? [.green, .mint] : isCurrent ? [.blue, .cyan] : [.purple, .pink],
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
            // Glassmorphic background
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark
                    ? Color.white.opacity(0.05)
                    : Color.white.opacity(0.7))
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .overlay(
            // Animated gradient border for current level, glow for completed
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isCurrent
                        ? LinearGradient(colors: [.blue, .purple, .blue], startPoint: .leading, endPoint: .trailing)
                        : isComplete
                            ? LinearGradient(colors: [.green.opacity(0.5), .mint.opacity(0.5)], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing),
                    lineWidth: isCurrent ? 2 : isComplete ? 1 : 0
                )
        )
        .shadow(
            color: isCurrent ? .blue.opacity(0.2) : isComplete ? .green.opacity(0.1) : .clear,
            radius: 8, x: 0, y: 4
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
