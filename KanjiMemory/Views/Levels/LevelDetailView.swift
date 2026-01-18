import SwiftUI
import SwiftData

enum SubjectType: String, CaseIterable {
    case all = "All"
    case radical = "Radicals"
    case kanji = "Kanji"
    case vocabulary = "Vocabulary"
}

struct LevelDetailView: View {
    let level: Int
    @StateObject private var dataManager = DataManager.shared
    @State private var selectedType: SubjectType = .all
    @State private var selectedSRSFilter: SRSStage? = nil

    // Query all progress types for SRS indicators
    @Query private var kanjiProgress: [KanjiProgress]
    @Query private var radicalProgress: [RadicalProgress]
    @Query private var vocabProgress: [VocabularyProgress]

    // Create lookup dictionaries for fast access
    private var kanjiProgressLookup: [String: KanjiProgress] {
        Dictionary(uniqueKeysWithValues: kanjiProgress.map { ($0.character, $0) })
    }

    private var radicalProgressLookup: [Int: RadicalProgress] {
        Dictionary(uniqueKeysWithValues: radicalProgress.map { ($0.radicalId, $0) })
    }

    private var vocabProgressLookup: [Int: VocabularyProgress] {
        Dictionary(uniqueKeysWithValues: vocabProgress.map { ($0.vocabularyId, $0) })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Type filter
                Picker("Type", selection: $selectedType) {
                    ForEach(SubjectType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Content grids with progress lookups
                switch selectedType {
                case .all:
                    AllContentSection(
                        level: level,
                        kanjiProgressLookup: kanjiProgressLookup,
                        radicalProgressLookup: radicalProgressLookup,
                        vocabProgressLookup: vocabProgressLookup
                    )
                case .radical:
                    RadicalsSection(level: level, radicalProgressLookup: radicalProgressLookup)
                case .kanji:
                    KanjiSection(level: level, kanjiProgressLookup: kanjiProgressLookup)
                case .vocabulary:
                    VocabularySection(level: level, vocabProgressLookup: vocabProgressLookup)
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Level \(level)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AllContentSection: View {
    let level: Int
    @StateObject private var dataManager = DataManager.shared
    let kanjiProgressLookup: [String: KanjiProgress]
    let radicalProgressLookup: [Int: RadicalProgress]
    let vocabProgressLookup: [Int: VocabularyProgress]

    var body: some View {
        VStack(spacing: 24) {
            // Radicals
            if !dataManager.getRadicals(byLevel: level).isEmpty {
                SectionHeader(title: "Radicals", count: dataManager.getRadicals(byLevel: level).count)
                RadicalsGrid(radicals: dataManager.getRadicals(byLevel: level), progressLookup: radicalProgressLookup)
            }

            // Kanji
            if !dataManager.getKanji(byLevel: level).isEmpty {
                SectionHeader(title: "Kanji", count: dataManager.getKanji(byLevel: level).count)
                KanjiGrid(kanji: dataManager.getKanji(byLevel: level), progressLookup: kanjiProgressLookup)
            }

            // Vocabulary
            if !dataManager.getVocabulary(byLevel: level).isEmpty {
                SectionHeader(title: "Vocabulary", count: dataManager.getVocabulary(byLevel: level).count)
                VocabularyGrid(vocabulary: dataManager.getVocabulary(byLevel: level), progressLookup: vocabProgressLookup)
            }
        }
        .padding(.horizontal)
    }
}

struct RadicalsSection: View {
    let level: Int
    @StateObject private var dataManager = DataManager.shared
    let radicalProgressLookup: [Int: RadicalProgress]

    var body: some View {
        RadicalsGrid(radicals: dataManager.getRadicals(byLevel: level), progressLookup: radicalProgressLookup)
            .padding(.horizontal)
    }
}

struct KanjiSection: View {
    let level: Int
    @StateObject private var dataManager = DataManager.shared
    let kanjiProgressLookup: [String: KanjiProgress]

    var body: some View {
        KanjiGrid(kanji: dataManager.getKanji(byLevel: level), progressLookup: kanjiProgressLookup)
            .padding(.horizontal)
    }
}

struct VocabularySection: View {
    let level: Int
    @StateObject private var dataManager = DataManager.shared
    let vocabProgressLookup: [Int: VocabularyProgress]

    var body: some View {
        VocabularyGrid(vocabulary: dataManager.getVocabulary(byLevel: level), progressLookup: vocabProgressLookup)
            .padding(.horizontal)
    }
}

struct SectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Text("(\(count))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

struct RadicalsGrid: View {
    let radicals: [Radical]
    let progressLookup: [Int: RadicalProgress]

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible()), count: 6),
            spacing: 8
        ) {
            ForEach(radicals) { radical in
                NavigationLink(destination: RadicalDetailView(radical: radical)) {
                    RadicalCell(radical: radical, progress: progressLookup[radical.id])
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct RadicalCell: View {
    let radical: Radical
    let progress: RadicalProgress?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack {
                Text(radical.displayCharacter)
                    .font(.title2)
            }
            .frame(width: 50, height: 50)
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                // Bottom border accent showing SRS stage
                VStack {
                    Spacer()
                    if let srs = progress?.srs {
                        Rectangle()
                            .fill(srs.indicatorColor)
                            .frame(height: 2)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            )

            // SRS dot indicator in top-right corner
            if let srs = progress?.srs {
                Circle()
                    .fill(srs.indicatorColor)
                    .frame(width: 6, height: 6)
                    .offset(x: -4, y: 4)
            }
        }
    }
}

struct KanjiGrid: View {
    let kanji: [Kanji]
    let progressLookup: [String: KanjiProgress]

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible()), count: 6),
            spacing: 8
        ) {
            ForEach(kanji) { k in
                NavigationLink(destination: KanjiDetailView(kanji: k)) {
                    KanjiCell(kanji: k, progress: progressLookup[k.character])
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct KanjiCell: View {
    let kanji: Kanji
    let progress: KanjiProgress?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack {
                Text(kanji.character)
                    .font(.title2)
            }
            .frame(width: 50, height: 50)
            .background(Color.purple.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                // Bottom border accent showing SRS stage
                VStack {
                    Spacer()
                    if let srs = progress?.srs {
                        Rectangle()
                            .fill(srs.indicatorColor)
                            .frame(height: 2)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            )

            // SRS dot indicator in top-right corner
            if let srs = progress?.srs {
                Circle()
                    .fill(srs.indicatorColor)
                    .frame(width: 6, height: 6)
                    .offset(x: -4, y: 4)
            }
        }
    }
}

struct VocabularyGrid: View {
    let vocabulary: [Vocabulary]
    let progressLookup: [Int: VocabularyProgress]

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible()), count: 4),
            spacing: 8
        ) {
            ForEach(vocabulary) { vocab in
                NavigationLink(destination: VocabularyDetailView(vocabulary: vocab)) {
                    VocabularyCell(vocabulary: vocab, progress: progressLookup[vocab.id])
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct VocabularyCell: View {
    let vocabulary: Vocabulary
    let progress: VocabularyProgress?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 2) {
                Text(vocabulary.characters)
                    .font(.headline)
                Text(vocabulary.primaryReading)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.green.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                // Bottom border accent showing SRS stage
                VStack {
                    Spacer()
                    if let srs = progress?.srs {
                        Rectangle()
                            .fill(srs.indicatorColor)
                            .frame(height: 2)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            )

            // SRS dot indicator in top-right corner
            if let srs = progress?.srs {
                Circle()
                    .fill(srs.indicatorColor)
                    .frame(width: 6, height: 6)
                    .offset(x: -4, y: 4)
            }
        }
    }
}

#Preview {
    NavigationStack {
        LevelDetailView(level: 1)
    }
    .environmentObject(AuthManager.shared)
    .modelContainer(for: [KanjiProgress.self], inMemory: true)
}
