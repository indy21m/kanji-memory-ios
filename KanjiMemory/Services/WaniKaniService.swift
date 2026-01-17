import Foundation

class WaniKaniService: ObservableObject {
    static let shared = WaniKaniService()

    private let baseURL = "https://api.wanikani.com/v2"
    private var apiKey: String?

    private init() {}

    func setApiKey(_ key: String) {
        self.apiKey = key
    }

    // MARK: - User Info
    func fetchUser() async throws -> WaniKaniUser {
        let data = try await request(endpoint: "/user")
        let response = try JSONDecoder().decode(WaniKaniResponse<WaniKaniUser>.self, from: data)
        return response.data
    }

    // MARK: - Assignments
    func fetchAssignments(
        subjectTypes: [String] = ["kanji"],
        srsStages: [Int]? = nil,
        updatedAfter: Date? = nil
    ) async throws -> [WaniKaniAssignmentData] {
        var queryItems = [URLQueryItem]()
        queryItems.append(URLQueryItem(name: "subject_types", value: subjectTypes.joined(separator: ",")))

        if let stages = srsStages {
            queryItems.append(URLQueryItem(name: "srs_stages", value: stages.map(String.init).joined(separator: ",")))
        }

        if let date = updatedAfter {
            let formatter = ISO8601DateFormatter()
            queryItems.append(URLQueryItem(name: "updated_after", value: formatter.string(from: date)))
        }

        var allAssignments: [WaniKaniAssignmentData] = []
        var nextURL: String? = "/assignments"

        while let url = nextURL {
            let data = try await request(endpoint: url, queryItems: queryItems)
            let response = try JSONDecoder().decode(WaniKaniCollectionResponse<WaniKaniAssignmentData>.self, from: data)
            allAssignments.append(contentsOf: response.data)
            nextURL = response.pages.nextUrl
            queryItems = [] // Only use query items for first request
        }

        return allAssignments
    }

    // MARK: - Subjects
    func fetchSubjects(types: [String] = ["kanji"], levels: [Int]? = nil) async throws -> [WaniKaniSubjectData] {
        var queryItems = [URLQueryItem]()
        queryItems.append(URLQueryItem(name: "types", value: types.joined(separator: ",")))

        if let levels = levels {
            queryItems.append(URLQueryItem(name: "levels", value: levels.map(String.init).joined(separator: ",")))
        }

        var allSubjects: [WaniKaniSubjectData] = []
        var nextURL: String? = "/subjects"

        while let url = nextURL {
            let data = try await request(endpoint: url, queryItems: queryItems)
            let response = try JSONDecoder().decode(WaniKaniCollectionResponse<WaniKaniSubjectData>.self, from: data)
            allSubjects.append(contentsOf: response.data)
            nextURL = response.pages.nextUrl
            queryItems = []
        }

        return allSubjects
    }

    // MARK: - Submit Review
    func submitReview(assignmentId: Int, meaningIncorrect: Int, readingIncorrect: Int) async throws {
        let body: [String: Any] = [
            "review": [
                "assignment_id": assignmentId,
                "incorrect_meaning_answers": meaningIncorrect,
                "incorrect_reading_answers": readingIncorrect
            ]
        ]

        _ = try await request(
            endpoint: "/reviews",
            method: "POST",
            body: try JSONSerialization.data(withJSONObject: body)
        )
    }

    // MARK: - Private Request Helper
    private func request(
        endpoint: String,
        method: String = "GET",
        queryItems: [URLQueryItem] = [],
        body: Data? = nil
    ) async throws -> Data {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw WaniKaniError.noApiKey
        }

        var urlComponents: URLComponents

        if endpoint.starts(with: "http") {
            guard let components = URLComponents(string: endpoint) else {
                throw WaniKaniError.invalidURL
            }
            urlComponents = components
        } else {
            guard var components = URLComponents(string: baseURL + endpoint) else {
                throw WaniKaniError.invalidURL
            }
            if !queryItems.isEmpty {
                components.queryItems = queryItems
            }
            urlComponents = components
        }

        guard let url = urlComponents.url else {
            throw WaniKaniError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("20170710", forHTTPHeaderField: "Wanikani-Revision")

        if let body = body {
            request.httpBody = body
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WaniKaniError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 401:
            throw WaniKaniError.unauthorized
        case 429:
            throw WaniKaniError.rateLimited
        default:
            throw WaniKaniError.httpError(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - Response Types
struct WaniKaniResponse<T: Codable>: Codable {
    let data: T
}

struct WaniKaniCollectionResponse<T: Codable>: Codable {
    let data: [T]
    let pages: WaniKaniPages
}

struct WaniKaniPages: Codable {
    let perPage: Int
    let nextUrl: String?
    let previousUrl: String?

    enum CodingKeys: String, CodingKey {
        case perPage = "per_page"
        case nextUrl = "next_url"
        case previousUrl = "previous_url"
    }
}

struct WaniKaniUser: Codable {
    let id: String
    let username: String
    let level: Int
    let profileUrl: String
    let startedAt: String?
    let currentVacationStartedAt: String?
    let subscription: WaniKaniSubscription

    enum CodingKeys: String, CodingKey {
        case id, username, level
        case profileUrl = "profile_url"
        case startedAt = "started_at"
        case currentVacationStartedAt = "current_vacation_started_at"
        case subscription
    }
}

struct WaniKaniSubscription: Codable {
    let active: Bool
    let type: String
    let maxLevelGranted: Int
    let periodEndsAt: String?

    enum CodingKeys: String, CodingKey {
        case active, type
        case maxLevelGranted = "max_level_granted"
        case periodEndsAt = "period_ends_at"
    }
}

struct WaniKaniAssignmentData: Codable {
    let id: Int
    let data: WaniKaniAssignmentInfo
}

struct WaniKaniAssignmentInfo: Codable {
    let subjectId: Int
    let subjectType: String
    let srsStage: Int
    let availableAt: String?
    let burnedAt: String?
    let passedAt: String?
    let startedAt: String?
    let unlockedAt: String?

    enum CodingKeys: String, CodingKey {
        case subjectId = "subject_id"
        case subjectType = "subject_type"
        case srsStage = "srs_stage"
        case availableAt = "available_at"
        case burnedAt = "burned_at"
        case passedAt = "passed_at"
        case startedAt = "started_at"
        case unlockedAt = "unlocked_at"
    }
}

struct WaniKaniSubjectData: Codable {
    let id: Int
    let object: String
    let data: WaniKaniSubjectInfo
}

struct WaniKaniSubjectInfo: Codable {
    let level: Int
    let slug: String
    let characters: String?
    let meanings: [WaniKaniMeaning]
    let readings: [WaniKaniReading]?

    enum CodingKeys: String, CodingKey {
        case level, slug, characters, meanings, readings
    }
}

struct WaniKaniMeaning: Codable {
    let meaning: String
    let primary: Bool
    let acceptedAnswer: Bool

    enum CodingKeys: String, CodingKey {
        case meaning, primary
        case acceptedAnswer = "accepted_answer"
    }
}

struct WaniKaniReading: Codable {
    let reading: String
    let primary: Bool
    let acceptedAnswer: Bool
    let type: String?

    enum CodingKeys: String, CodingKey {
        case reading, primary, type
        case acceptedAnswer = "accepted_answer"
    }
}

// MARK: - Errors
enum WaniKaniError: LocalizedError {
    case noApiKey
    case invalidURL
    case invalidResponse
    case unauthorized
    case rateLimited
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .noApiKey:
            return "No WaniKani API key configured"
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Invalid API key"
        case .rateLimited:
            return "Rate limited - please try again later"
        case .httpError(let code):
            return "HTTP error: \(code)"
        }
    }
}
