import Foundation
import SwiftData

// MARK: - Meaning Structure
struct Meaning: Codable, Hashable {
    let meaning: String
    let primary: Bool

    init(meaning: String, primary: Bool = true) {
        self.meaning = meaning
        self.primary = primary
    }
}

// MARK: - Reading Structure
struct Reading: Codable, Hashable {
    let reading: String
    let primary: Bool

    init(reading: String, primary: Bool = true) {
        self.reading = reading
        self.primary = primary
    }
}

// MARK: - Radical Model (Bundled Data)
struct Radical: Codable, Identifiable, Hashable {
    let id: Int
    let characters: String?
    let image: String?
    let meanings: [Meaning]
    let level: Int
    let slug: String

    var displayCharacter: String {
        characters ?? "●" // Fallback for image-based radicals
    }

    var primaryMeaning: String {
        meanings.first(where: { $0.primary })?.meaning ?? meanings.first?.meaning ?? ""
    }

    var hasCharacter: Bool {
        characters != nil && !characters!.isEmpty
    }
}

// MARK: - Radical Data Container
struct RadicalDataContainer: Codable {
    let levels: [String: [Radical]]
    let count: Int
}

// MARK: - Radical Progress (SwiftData)
@Model
final class RadicalProgress {
    @Attribute(.unique) var radicalId: Int
    var mnemonic: String?
    var srsStage: Int
    var nextReviewAt: Date?
    var wanikaniAssignmentId: Int?  // Required for submitting reviews to WaniKani
    var createdAt: Date
    var updatedAt: Date

    var srs: SRSStage {
        get { SRSStage(rawValue: srsStage) ?? .lesson }
        set { srsStage = newValue.rawValue }
    }

    init(radicalId: Int, srsStage: SRSStage = .lesson, nextReviewAt: Date? = nil, wanikaniAssignmentId: Int? = nil) {
        self.radicalId = radicalId
        self.srsStage = srsStage.rawValue
        self.nextReviewAt = nextReviewAt
        self.wanikaniAssignmentId = wanikaniAssignmentId
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
