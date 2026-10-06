import Foundation

/// The currently logged-in user, as returned by the backend on
/// login/signup. Matches the shape of your Node API's user object.
struct UserSkill: Codable, Identifiable, Equatable {
    let id: String
    let name: String

    var displayName: String {
        name.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

struct AuthUser: Codable, Identifiable, Equatable {
    let id: String
    let email: String?          // only present for your own account
    let name: String
    let role: String            // "customer" | "worker"
    let bio: String?
    let photoUrl: String?
    let phone: String?          // only present for your own account
    let dateOfBirth: String?    // only present for your own account
    let gender: String?
    let yearsExperience: Int?
    let certifications: String?
    let skills: [UserSkill]?
    let reliability: Reliability?
    let isAdmin: Bool?          // only present for your own account
    let identityVerified: Bool?
    let isAvailable: Bool?      // workers: online for job pop-ups (own account only)
    let state: String?          // two letters, e.g. "GA"
    let stateSupported: Bool?   // false when Handz isn't open in their state yet (own account only)

    enum CodingKeys: String, CodingKey {
        case id, email, name, role, bio, phone, gender, certifications, skills, reliability
        case isAdmin = "is_admin"
        case identityVerified = "identity_verified"
        case isAvailable = "is_available"
        case state
        case stateSupported = "state_supported"
        case photoUrl = "photo_url"
        case dateOfBirth = "date_of_birth"
        case yearsExperience = "years_experience"
    }
}

/// Holds the app's authentication state for the whole session:
/// current user, token, login/logout, and initial session restore on
/// launch. Published so SwiftUI views can react to login state changes.
@MainActor
final class AuthSession: ObservableObject {
    static let shared = AuthSession()

    @Published private(set) var currentUser: AuthUser?
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var isRestoringSession: Bool = true

    private var token: String? {
        didSet {
            // Every API request pulls the current token through this
            // closure, so APIClient always has the latest value.
            APIClient.shared.tokenProvider = { [weak self] in self?.token }
        }
    }

    /// Exposes the current token for the rare direct-URLSession case
    /// (multipart file uploads), which bypasses APIClient.
    var tokenForRequests: String? { token }

    private init() {
        APIClient.shared.tokenProvider = { [weak self] in self?.token }
    }

    /// Called once on app launch. Restores a saved session from
    /// Keychain if one exists, so the user doesn't have to log in every
    /// time they open the app (spec section 6: persistent session).
    func restoreSessionIfAvailable() async {
        defer { isRestoringSession = false }

        guard let savedToken = KeychainTokenStore.shared.loadToken() else {
            return
        }

        token = savedToken

        // Validate the token is still good by fetching the current
        // user. If it's expired/invalid, this throws and we clear it.
        do {
            let response: MeResponse = try await APIClient.shared.request("/auth/me")
            currentUser = response.user
            isAuthenticated = true
        } catch {
            // Expired or invalid token -- log out cleanly rather than
            // leaving the app in a broken half-authenticated state.
            logOut()
        }
    }

    struct SignupRequest: Encodable {
        let email: String
        let password: String
        let name: String
        let role: String
        let phone: String
        let gender: String?
        let date_of_birth: String?
        let skills: [String]?
        let years_experience: Int?
        let certifications: String?
        let home_address: String?
        let home_latitude: Double?
        let home_longitude: Double?
        let accepted_terms: Bool
        let state: String
    }

    struct LoginRequest: Encodable {
        let email: String
        let password: String
    }

    private struct AuthResponse: Decodable {
        let token: String
        let user: AuthUser
    }

    private struct MeResponse: Decodable {
        let user: AuthUser
    }

    func signUp(_ body: SignupRequest) async throws {
        let response: AuthResponse = try await APIClient.shared.request(
            "/auth/signup", method: .post, body: body, requiresAuth: false
        )
        applySession(response)
    }

    func logIn(email: String, password: String) async throws {
        let body = LoginRequest(email: email, password: password)
        let response: AuthResponse = try await APIClient.shared.request(
            "/auth/login", method: .post, body: body, requiresAuth: false
        )
        applySession(response)
    }
    
    /// Re-fetches the current user (e.g. after editing their name) so
    /// the greeting and profile update everywhere.
    func refreshCurrentUser() async {
        if let response: MeResponse = try? await APIClient.shared.request("/auth/me") {
            currentUser = response.user
        }
    }

    /// Changing the password logs out every other phone. This phone gets a fresh login back.
    func changePassword(current: String, new: String) async throws {
        struct Body: Encodable { let current_password: String; let new_password: String }
        struct Response: Decodable { let ok: Bool; let token: String? }
        let response: Response = try await APIClient.shared.request(
            "/auth/change-password", method: .post, body: Body(current_password: current, new_password: new)
        )
        if let fresh = response.token {
            token = fresh
            KeychainTokenStore.shared.save(token: fresh)
        }
    }

    struct DeleteAccountRequest: Encodable {
        let password: String
    }

    /// Anonymizes the account on the server, then logs out locally.
    func deleteAccount(password: String) async throws {
        struct OkResponse: Decodable { let ok: Bool }
        let _: OkResponse = try await APIClient.shared.request(
            "/auth/delete-account", method: .post, body: DeleteAccountRequest(password: password)
        )
        logOut()
    }
    
    func logOut() {
        token = nil
        currentUser = nil
        isAuthenticated = false
        KeychainTokenStore.shared.clear()
    }

    private func applySession(_ response: AuthResponse) {
        token = response.token
        currentUser = response.user
        isAuthenticated = true
        KeychainTokenStore.shared.save(token: response.token)
    }
}
