import Foundation
import SwiftData

// MARK: - SRS Stage Enum
enum SRSStage: Int, Codable, CaseIterable {
    case lesson = 0
    case apprentice1 = 1
    case apprentice2 = 2
    case apprentice3 = 3
    case apprentice4 = 4
    case guru1 = 5
    case guru2 = 6
    case master = 7
    case enlightened = 8
    case burned = 9

    var name: String {
        switch self {
        case .lesson: return "Lesson"
        case .apprentice1: return "Apprentice I"
        case .apprentice2: return "Apprentice II"
        case .apprentice3: return "Apprentice III"
        case .apprentice4: return "Apprentice IV"
        case .guru1: return "Guru I"
        case .guru2: return "Guru II"
        case .master: return "Master"
        case .enlightened: return "Enlightened"
        case .burned: return "Burned"
        }
    }

    var color: String {
        switch self {
        case .lesson: return "srsLesson"
        case .apprentice1, .apprentice2, .apprentice3, .apprentice4: return "srsApprentice"
        case .guru1, .guru2: return "srsGuru"
        case .master: return "srsMaster"
        case .enlightened: return "srsEnlightened"
        case .burned: return "srsBurned"
        }
    }

    var isLearned: Bool {
        return self.rawValue >= SRSStage.guru1.rawValue
    }

    var isApprentice: Bool {
        return self.rawValue >= 1 && self.rawValue <= 4
    }

    /// Color for SRS indicator dots/borders (matching OG web app colors)
    var indicatorColor: Color {
        switch self {
        case .lesson: return Color(hex: "ff6b6b")         // Red
        case .apprentice1, .apprentice2, .apprentice3, .apprentice4:
            return Color(hex: "ff8f23")                    // Orange
        case .guru1, .guru2: return Color(hex: "9c4699")  // Purple
        case .master: return Color(hex: "3cb5e5")         // Blue
        case .enlightened: return Color(hex: "3cb5e5")    // Light Blue (same as master)
        case .burned: return Color(hex: "434343")         // Gray
        }
    }
}

// MARK: - Color Extension for Hex
import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Kanji Model (Bundled Data)
struct Kanji: Codable, Identifiable, Hashable {
    let character: String
    let meanings: [String]
    let onyomi: [String]
    let kunyomi: [String]
    let radicals: [String]
    let strokeCount: Int
    let wanikaniId: Int
    let level: Int

    var id: String { character }

    var primaryMeaning: String {
        meanings.first ?? ""
    }

    var allReadings: [String] {
        onyomi + kunyomi
    }
}

// MARK: - Kanji Data Container (from JSON)
struct KanjiDataContainer: Codable {
    let levels: [String: [Kanji]]
    let count: Int
}

// MARK: - User's Kanji Progress (SwiftData)
@Model
final class KanjiProgress {
    @Attribute(.unique) var character: String
    var level: Int
    var mnemonic: String?
    var srsStage: Int
    var nextReviewAt: Date?
    var wanikaniId: Int?
    var wanikaniAssignmentId: Int?  // Required for submitting reviews to WaniKani
    var timesReviewed: Int
    var timesCorrect: Int
    var createdAt: Date
    var updatedAt: Date

    // Computed SRS stage
    var srs: SRSStage {
        get { SRSStage(rawValue: srsStage) ?? .lesson }
        set { srsStage = newValue.rawValue }
    }

    init(
        character: String,
        level: Int,
        mnemonic: String? = nil,
        srsStage: SRSStage = .lesson,
        nextReviewAt: Date? = nil,
        wanikaniId: Int? = nil,
        wanikaniAssignmentId: Int? = nil
    ) {
        self.character = character
        self.level = level
        self.mnemonic = mnemonic
        self.srsStage = srsStage.rawValue
        self.nextReviewAt = nextReviewAt
        self.wanikaniId = wanikaniId
        self.wanikaniAssignmentId = wanikaniAssignmentId
        self.timesReviewed = 0
        self.timesCorrect = 0
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Cached Image (SwiftData)
@Model
final class CachedImage {
    @Attribute(.unique) var id: String
    var character: String
    var imageData: Data
    var isAIGenerated: Bool
    var prompt: String?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        character: String,
        imageData: Data,
        isAIGenerated: Bool,
        prompt: String? = nil
    ) {
        self.id = id
        self.character = character
        self.imageData = imageData
        self.isAIGenerated = isAIGenerated
        self.prompt = prompt
        self.createdAt = Date()
    }
}
