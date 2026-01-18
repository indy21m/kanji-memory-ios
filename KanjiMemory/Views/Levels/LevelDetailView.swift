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

                // Content grids
                switch selectedType {
                case .all:
                    AllContentSection(level: level)
                case .radical:
                    RadicalsSection(level: level)
                case .kanji:
                    KanjiSection(level: level)
                case .vocabulary:
                    VocabularySection(level: level)
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

    var body: some View {
        VStack(spacing: 24) {
            // Radicals
            if !dataManager.getRadicals(byLevel: level).isEmpty {
                SectionHeader(title: "Radicals", count: dataManager.getRadicals(byLevel: level).count)
                RadicalsGrid(radicals: dataManager.getRadicals(byLevel: level))
            }

            // Kanji
            if !dataManager.getKanji(byLevel: level).isEmpty {
                SectionHeader(title: "Kanji", count: dataManager.getKanji(byLevel: level).count)
                KanjiGrid(kanji: dataManager.getKanji(byLevel: level))
            }

            // Vocabulary
            if !dataManager.getVocabulary(byLevel: level).isEmpty {
                SectionHeader(title: "Vocabulary", count: dataManager.getVocabulary(byLevel: level).count)
                VocabularyGrid(vocabulary: dataManager.getVocabulary(byLevel: level))
            }
        }
        .padding(.horizontal)
    }
}

struct RadicalsSection: View {
    let level: Int
    @StateObject private var dataManager = DataManager.shared

    var body: some View {
        RadicalsGrid(radicals: dataManager.getRadicals(byLevel: level))
            .padding(.horizontal)
    }
}

struct KanjiSection: View {
    let level: Int
    @StateObject private var dataManager = DataManager.shared

    var body: some View {
        KanjiGrid(kanji: dataManager.getKanji(byLevel: level))
            .padding(.horizontal)
    }
}

struct VocabularySection: View {
    let level: Int
    @StateObject private var dataManager = DataManager.shared

    var body: some View {
        VocabularyGrid(vocabulary: dataManager.getVocabulary(byLevel: level))
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

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible()), count: 6),
            spacing: 8
        ) {
            ForEach(radicals) { radical in
                NavigationLink(destination: RadicalDetailView(radical: radical)) {
                    RadicalCell(radical: radical)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct RadicalCell: View {
    let radical: Radical

    var body: some View {
        VStack {
            Text(radical.displayCharacter)
                .font(.title2)
        }
        .frame(width: 50, height: 50)
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct KanjiGrid: View {
    let kanji: [Kanji]

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible()), count: 6),
            spacing: 8
        ) {
            ForEach(kanji) { k in
                NavigationLink(destination: KanjiDetailView(kanji: k)) {
                    KanjiCell(kanji: k)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct KanjiCell: View {
    let kanji: Kanji

    var body: some View {
        VStack {
            Text(kanji.character)
                .font(.title2)
        }
        .frame(width: 50, height: 50)
        .background(Color.purple.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct VocabularyGrid: View {
    let vocabulary: [Vocabulary]

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible()), count: 4),
            spacing: 8
        ) {
            ForEach(vocabulary) { vocab in
                NavigationLink(destination: VocabularyDetailView(vocabulary: vocab)) {
                    VocabularyCell(vocabulary: vocab)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct VocabularyCell: View {
    let vocabulary: Vocabulary

    var body: some View {
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
    }
}

#Preview {
    NavigationStack {
        LevelDetailView(level: 1)
    }
    .environmentObject(AuthManager.shared)
    .modelContainer(for: [KanjiProgress.self], inMemory: true)
}
