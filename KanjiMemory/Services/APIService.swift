import Foundation

/// Service for communicating with the Kanji Memory backend API
class APIService: ObservableObject {
    static let shared = APIService()

    #if DEBUG
    private let baseURL = "http://localhost:3000/api"
    #else
    private let baseURL = "https://your-vercel-app.vercel.app/api"
    #endif

    private var authToken: String?

    private init() {}

    func setAuthToken(_ token: String) {
        self.authToken = token
    }

    // MARK: - AI Generation
    func generateMnemonic(
        character: String,
        meanings: [String],
        readings: [String],
        style: MnemonicStyle,
        interests: String
    ) async throws -> String {
        let body: [String: Any] = [
            "character": character,
            "meanings": meanings,
            "readings": readings,
            "style": style.rawValue,
            "interests": interests
        ]

        let data = try await request(
            endpoint: "/ai/mnemonic",
            method: "POST",
            body: try JSONSerialization.data(withJSONObject: body)
        )

        let response = try JSONDecoder().decode(MnemonicResponse.self, from: data)
        return response.mnemonic
    }

    func generateImage(
        character: String,
        mnemonic: String,
        style: ImageStyle
    ) async throws -> String {
        let body: [String: Any] = [
            "character": character,
            "mnemonic": mnemonic,
            "style": style.rawValue
        ]

        let data = try await request(
            endpoint: "/ai/image",
            method: "POST",
            body: try JSONSerialization.data(withJSONObject: body)
        )

        let response = try JSONDecoder().decode(ImageResponse.self, from: data)
        return response.imageUrl
    }

    // MARK: - User
    func getProfile() async throws -> UserProfile {
        let data = try await request(endpoint: "/user/profile")
        return try JSONDecoder().decode(UserProfile.self, from: data)
    }

    func updatePreferences(preferences: AIPreferences) async throws {
        let body: [String: Any] = [
            "mnemonicStyle": preferences.mnemonicStyle.rawValue,
            "imageStyle": preferences.imageStyle.rawValue,
            "personalInterests": preferences.personalInterests
        ]

        _ = try await request(
            endpoint: "/user/preferences",
            method: "PUT",
            body: try JSONSerialization.data(withJSONObject: body)
        )
    }

    // MARK: - Images
    func getImages(forCharacter character: String) async throws -> [RemoteImage] {
        let data = try await request(endpoint: "/images/\(character)")
        return try JSONDecoder().decode([RemoteImage].self, from: data)
    }

    func uploadImage(character: String, imageData: Data) async throws -> String {
        // Create multipart form data
        let boundary = UUID().uuidString
        var body = Data()

        // Add character field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"character\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(character)\r\n".data(using: .utf8)!)

        // Add image file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        let data = try await request(
            endpoint: "/images/upload",
            method: "POST",
            body: body,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )

        let response = try JSONDecoder().decode(UploadResponse.self, from: data)
        return response.url
    }

    // MARK: - Auth
    func authenticateWithApple(identityToken: String, authorizationCode: String) async throws -> AuthResponse {
        let body: [String: Any] = [
            "identityToken": identityToken,
            "authorizationCode": authorizationCode
        ]

        let data = try await request(
            endpoint: "/auth/apple",
            method: "POST",
            body: try JSONSerialization.data(withJSONObject: body)
        )

        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }

    // MARK: - Private Request Helper
    private func request(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil,
        contentType: String = "application/json"
    ) async throws -> Data {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue(contentType, forHTTPHeaderField: "Content-Type")

        if let token = authToken {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = body
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 401:
            throw APIError.unauthorized
        case 402:
            throw APIError.subscriptionRequired
        case 429:
            throw APIError.rateLimited
        default:
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - Response Types
struct MnemonicResponse: Codable {
    let mnemonic: String
}

struct ImageResponse: Codable {
    let imageUrl: String
}

struct UserProfile: Codable {
    let id: String
    let email: String?
    let tier: String
    let aiGenerationsUsed: Int
    let aiGenerationsLimit: Int
    let preferences: APIPreferences?
}

struct APIPreferences: Codable {
    let mnemonicStyle: String?
    let imageStyle: String?
    let personalInterests: String?
}

struct RemoteImage: Codable, Identifiable {
    let id: String
    let url: String
    let isAIGenerated: Bool
    let createdAt: String
}

struct UploadResponse: Codable {
    let url: String
}

struct AuthResponse: Codable {
    let userId: String
    let accessToken: String
    let user: AuthUser
}

struct AuthUser: Codable {
    let id: String
    let email: String?
    let tier: String
}

// MARK: - Errors
enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case subscriptionRequired
    case rateLimited
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Please sign in to continue"
        case .subscriptionRequired:
            return "Premium subscription required"
        case .rateLimited:
            return "Too many requests - please try again later"
        case .httpError(let code):
            return "Server error: \(code)"
        }
    }
}
