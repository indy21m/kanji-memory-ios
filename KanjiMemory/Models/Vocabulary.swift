import Foundation
import SwiftData

// MARK: - Vocabulary Model (Bundled Data)
struct Vocabulary: Codable, Identifiable, Hashable {
    let id: Int
    let characters: String
    let meanings: [Meaning]
    let readings: [Reading]
    let level: Int
    let slug: String

    var primaryMeaning: String {
        meanings.first(where: { $0.primary })?.meaning ?? meanings.first?.meaning ?? ""
    }

    var primaryReading: String {
        readings.first(where: { $0.primary })?.reading ?? readings.first?.reading ?? ""
    }

    var allMeanings: [String] {
        meanings.map { $0.meaning }
    }

    var allReadings: [String] {
        readings.map { $0.reading }
    }

    var acceptedReadings: [String] {
        readings.map { $0.reading }
    }
}

// MARK: - Vocabulary Data Container
struct VocabularyDataContainer: Codable {
    let levels: [String: [Vocabulary]]
    let count: Int
}

// MARK: - Vocabulary Progress (SwiftData)
@Model
final class VocabularyProgress {
    @Attribute(.unique) var vocabularyId: Int
    var meaningMnemonic: String?
    var readingMnemonic: String?
    var srsStage: Int
    var nextReviewAt: Date?
    var wanikaniAssignmentId: Int?  // Required for submitting reviews to WaniKani
    var createdAt: Date
    var updatedAt: Date

    var srs: SRSStage {
        get { SRSStage(rawValue: srsStage) ?? .lesson }
        set { srsStage = newValue.rawValue }
    }

    init(vocabularyId: Int, srsStage: SRSStage = .lesson, nextReviewAt: Date? = nil, wanikaniAssignmentId: Int? = nil) {
        self.vocabularyId = vocabularyId
        self.srsStage = srsStage.rawValue
        self.nextReviewAt = nextReviewAt
        self.wanikaniAssignmentId = wanikaniAssignmentId
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
