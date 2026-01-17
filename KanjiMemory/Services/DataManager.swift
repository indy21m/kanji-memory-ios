import Foundation
import SwiftData

@MainActor
class DataManager: ObservableObject {
    static let shared = DataManager()

    @Published var kanji: [String: [Kanji]] = [:]
    @Published var radicals: [String: [Radical]] = [:]
    @Published var vocabulary: [String: [Vocabulary]] = [:]
    @Published var radicalCharMap: [String: String] = [:]
    @Published var isLoaded = false
    @Published var loadError: Error?

    // Computed properties
    var allKanji: [Kanji] {
        kanji.values.flatMap { $0 }
    }

    var allRadicals: [Radical] {
        radicals.values.flatMap { $0 }
    }

    var allVocabulary: [Vocabulary] {
        vocabulary.values.flatMap { $0 }
    }

    var totalLevels: Int { 60 }

    private init() {}

    // MARK: - Load Bundled Data
    func loadBundledData() async {
        do {
            // Load kanji
            if let kanjiData = await loadJSON(filename: "kanji_all", type: KanjiDataContainer.self) {
                self.kanji = kanjiData.levels
                print("Loaded \(kanjiData.count) kanji")
            }

            // Load radicals
            if let radicalData = await loadJSON(filename: "radicals_all", type: RadicalDataContainer.self) {
                self.radicals = radicalData.levels
                print("Loaded \(radicalData.count) radicals")
            }

            // Load vocabulary
            if let vocabData = await loadJSON(filename: "vocabulary_all", type: VocabularyDataContainer.self) {
                self.vocabulary = vocabData.levels
                print("Loaded \(vocabData.count) vocabulary")
            }

            // Load radical character map
            if let charMap = await loadJSON(filename: "radical_char_map", type: [String: String].self) {
                self.radicalCharMap = charMap
                print("Loaded \(charMap.count) radical mappings")
            }

            isLoaded = true
        } catch {
            loadError = error
            print("Error loading bundled data: \(error)")
        }
    }

    private func loadJSON<T: Decodable>(filename: String, type: T.Type) async -> T? {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            print("Could not find \(filename).json in bundle")
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(T.self, from: data)
            return decoded
        } catch {
            print("Error decoding \(filename).json: \(error)")
            return nil
        }
    }

    // MARK: - Getters
    func getKanji(byLevel level: Int) -> [Kanji] {
        kanji[String(level)] ?? []
    }

    func getKanji(byCharacter character: String) -> Kanji? {
        allKanji.first { $0.character == character }
    }

    func getRadicals(byLevel level: Int) -> [Radical] {
        radicals[String(level)] ?? []
    }

    func getRadical(byId id: Int) -> Radical? {
        allRadicals.first { $0.id == id }
    }

    func getVocabulary(byLevel level: Int) -> [Vocabulary] {
        vocabulary[String(level)] ?? []
    }

    func getVocabulary(byId id: Int) -> Vocabulary? {
        allVocabulary.first { $0.id == id }
    }

    func getRadicalCharacter(byName name: String) -> String {
        radicalCharMap[name] ?? name
    }

    // MARK: - Search
    func searchKanji(query: String) -> [Kanji] {
        let lowercaseQuery = query.lowercased()
        return allKanji.filter { kanji in
            // Search by character
            if kanji.character.contains(query) { return true }
            // Search by meanings
            if kanji.meanings.contains(where: { $0.lowercased().contains(lowercaseQuery) }) { return true }
            // Search by readings
            if kanji.onyomi.contains(where: { $0.contains(query) }) { return true }
            if kanji.kunyomi.contains(where: { $0.contains(query) }) { return true }
            return false
        }
    }

    // MARK: - Level Stats
    func getLevelStats(level: Int) -> LevelStats {
        let kanjiCount = getKanji(byLevel: level).count
        let radicalCount = getRadicals(byLevel: level).count
        let vocabCount = getVocabulary(byLevel: level).count

        return LevelStats(
            level: level,
            kanjiCount: kanjiCount,
            radicalCount: radicalCount,
            vocabularyCount: vocabCount
        )
    }
}

struct LevelStats {
    let level: Int
    let kanjiCount: Int
    let radicalCount: Int
    let vocabularyCount: Int

    var totalCount: Int {
        kanjiCount + radicalCount + vocabularyCount
    }
}
