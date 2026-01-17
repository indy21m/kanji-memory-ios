import Foundation
import SwiftData

// MARK: - User Preferences
struct AIPreferences: Codable {
    var mnemonicStyle: MnemonicStyle
    var imageStyle: ImageStyle
    var personalInterests: String

    init(
        mnemonicStyle: MnemonicStyle = .visual,
        imageStyle: ImageStyle = .minimalist,
        personalInterests: String = ""
    ) {
        self.mnemonicStyle = mnemonicStyle
        self.imageStyle = imageStyle
        self.personalInterests = personalInterests
    }
}

enum MnemonicStyle: String, Codable, CaseIterable {
    case visual = "visual"
    case story = "story"
    case humor = "humor"
    case personal = "personal"
    case logical = "logical"
    case cultural = "cultural"

    var displayName: String {
        switch self {
        case .visual: return "Visual"
        case .story: return "Story"
        case .humor: return "Humor"
        case .personal: return "Personal"
        case .logical: return "Logical"
        case .cultural: return "Cultural"
        }
    }

    var description: String {
        switch self {
        case .visual: return "Vivid mental images"
        case .story: return "Narrative connections"
        case .humor: return "Funny associations"
        case .personal: return "Personal experiences"
        case .logical: return "Etymology & patterns"
        case .cultural: return "Japanese culture"
        }
    }
}

enum ImageStyle: String, Codable, CaseIterable {
    case minimalist = "minimalist"
    case realistic = "realistic"
    case cartoon = "cartoon"
    case traditional = "traditional"
    case abstract = "abstract"

    var displayName: String {
        switch self {
        case .minimalist: return "Minimalist"
        case .realistic: return "Realistic"
        case .cartoon: return "Cartoon"
        case .traditional: return "Traditional"
        case .abstract: return "Abstract"
        }
    }
}

// MARK: - Subscription Tier
enum SubscriptionTier: String, Codable {
    case free = "free"
    case premium = "premium"

    var aiGenerationsLimit: Int {
        switch self {
        case .free: return 5
        case .premium: return Int.max
        }
    }
}

// MARK: - User Settings (SwiftData)
@Model
final class UserSettings {
    @Attribute(.unique) var id: String
    var wanikaniApiKey: String?
    var theme: String
    var aiPreferencesData: Data?
    var tier: String
    var aiGenerationsUsed: Int
    var aiGenerationsResetAt: Date?
    var appleUserId: String?
    var authToken: String?
    var createdAt: Date
    var updatedAt: Date

    var aiPreferences: AIPreferences {
        get {
            guard let data = aiPreferencesData else {
                return AIPreferences()
            }
            return (try? JSONDecoder().decode(AIPreferences.self, from: data)) ?? AIPreferences()
        }
        set {
            aiPreferencesData = try? JSONEncoder().encode(newValue)
        }
    }

    var subscriptionTier: SubscriptionTier {
        get { SubscriptionTier(rawValue: tier) ?? .free }
        set { tier = newValue.rawValue }
    }

    var canGenerateAI: Bool {
        if subscriptionTier == .premium { return true }
        return aiGenerationsUsed < subscriptionTier.aiGenerationsLimit
    }

    var remainingGenerations: Int {
        if subscriptionTier == .premium { return Int.max }
        return max(0, subscriptionTier.aiGenerationsLimit - aiGenerationsUsed)
    }

    init() {
        self.id = "main"
        self.theme = "system"
        self.tier = SubscriptionTier.free.rawValue
        self.aiGenerationsUsed = 0
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - WaniKani Assignment (for sync)
struct WaniKaniAssignment: Codable {
    let id: Int
    let subjectId: Int
    let srsStage: Int
    let burnedAt: String?
    let availableAt: String?
    let passedAt: String?
    let startedAt: String?
    let unlockedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case subjectId = "subject_id"
        case srsStage = "srs_stage"
        case burnedAt = "burned_at"
        case availableAt = "available_at"
        case passedAt = "passed_at"
        case startedAt = "started_at"
        case unlockedAt = "unlocked_at"
    }
}
