import Foundation
import AuthenticationServices
import SwiftUI

/// Manages authentication state and Sign in with Apple flow
@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isAuthenticated = false
    @Published var currentUser: AuthUser?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private init() {
        checkExistingSession()
    }

    // MARK: - Check Existing Session
    func checkExistingSession() {
        print("AuthManager: Checking existing session...")

        guard let token = KeychainHelper.getAuthToken() else {
            print("AuthManager: No auth token found in Keychain")
            isAuthenticated = false
            currentUser = nil
            return
        }

        print("AuthManager: Found auth token")

        guard let userData = KeychainHelper.getUserData() else {
            print("AuthManager: No user data found in Keychain")
            isAuthenticated = false
            currentUser = nil
            return
        }

        print("AuthManager: Found user data, attempting to decode...")

        guard let user = try? JSONDecoder().decode(AuthUser.self, from: userData) else {
            print("AuthManager: Failed to decode user data")
            isAuthenticated = false
            currentUser = nil
            return
        }

        // Set the token on APIService
        APIService.shared.setAuthToken(token)

        isAuthenticated = true
        currentUser = user
        print("AuthManager: Session restored for user \(user.id)")
    }

    // MARK: - Sign In with Apple
    func signInWithApple(authorization: ASAuthorization) async {
        print("AuthManager: Processing Sign in with Apple...")

        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            errorMessage = "Failed to get Apple ID credential"
            print("AuthManager: Failed to cast credential to ASAuthorizationAppleIDCredential")
            return
        }

        guard let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            errorMessage = "Failed to get identity token"
            print("AuthManager: Failed to get identity token")
            return
        }

        guard let authCodeData = appleIDCredential.authorizationCode,
              let authorizationCode = String(data: authCodeData, encoding: .utf8) else {
            errorMessage = "Failed to get authorization code"
            print("AuthManager: Failed to get authorization code")
            return
        }

        print("AuthManager: Got Apple credentials, calling backend...")

        isLoading = true
        errorMessage = nil

        do {
            // Call our backend to validate and create/login user
            let response = try await APIService.shared.authenticateWithApple(
                identityToken: identityToken,
                authorizationCode: authorizationCode
            )

            print("AuthManager: Backend returned success, saving to Keychain...")

            // Store token and user data securely
            KeychainHelper.saveAuthToken(response.accessToken)
            print("AuthManager: Saved auth token to Keychain")

            if let userData = try? JSONEncoder().encode(response.user) {
                KeychainHelper.saveUserData(userData)
                print("AuthManager: Saved user data to Keychain")
            } else {
                print("AuthManager: WARNING - Failed to encode user data")
            }

            // Set token on APIService for subsequent requests
            APIService.shared.setAuthToken(response.accessToken)

            // Update state
            isAuthenticated = true
            currentUser = response.user

            // Provide haptic feedback for successful sign in
            HapticManager.success()

            print("AuthManager: Successfully signed in user \(response.user.id)")

        } catch let error as APIError {
            errorMessage = error.errorDescription
            HapticManager.error()
            print("AuthManager: API error - \(error.errorDescription ?? "Unknown error")")
        } catch {
            errorMessage = "Connection failed. Please try again."
            HapticManager.error()
            print("AuthManager: Network/unknown error - \(error)")
        }

        isLoading = false
    }

    // MARK: - Sign Out
    func signOut() {
        // Clear stored credentials
        KeychainHelper.deleteAuthToken()
        KeychainHelper.deleteUserData()

        // Clear API token
        APIService.shared.setAuthToken(nil)

        // Update state
        isAuthenticated = false
        currentUser = nil

        print("Signed out successfully")
    }

    // MARK: - Refresh User Profile
    func refreshProfile() async {
        guard isAuthenticated else { return }

        do {
            let profile = try await APIService.shared.getProfile()

            // Update user with latest info
            let updatedUser = AuthUser(
                id: profile.id,
                email: profile.email,
                tier: profile.tier
            )

            if let userData = try? JSONEncoder().encode(updatedUser) {
                KeychainHelper.saveUserData(userData)
            }

            currentUser = updatedUser

        } catch {
            print("Failed to refresh profile: \(error)")
        }
    }
}

// MARK: - Sign In with Apple Button View
struct SignInWithAppleButtonView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.email]
        } onCompletion: { result in
            switch result {
            case .success(let authorization):
                Task {
                    await authManager.signInWithApple(authorization: authorization)
                }
            case .failure(let error):
                print("Sign in with Apple failed: \(error)")
            }
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
        .cornerRadius(10)
    }
}

// MARK: - Sign In with Apple Coordinator (for programmatic use)
class SignInWithAppleCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let authManager: AuthManager
    private var continuation: CheckedContinuation<ASAuthorization, Error>?

    init(authManager: AuthManager) {
        self.authManager = authManager
    }

    func signIn() async throws -> ASAuthorization {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.email]

            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            authorizationController.performRequests()
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation?.resume(returning: authorization)
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            fatalError("No window found")
        }
        return window
    }
}
