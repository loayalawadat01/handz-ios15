import Foundation

struct HomeLocationResponse: Decodable {
    let homeAddress: String?
    let homeLatitude: Double?
    let homeLongitude: Double?

    enum CodingKeys: String, CodingKey {
        case homeAddress = "home_address"
        case homeLatitude = "home_latitude"
        case homeLongitude = "home_longitude"
    }
}

struct UpdateHomeLocationRequest: Encodable {
    let home_address: String?
    let home_latitude: Double?
    let home_longitude: Double?
}

struct NotificationCategoriesResponse: Decodable {
    let notifyAllCategories: Bool
    let categoryIds: [String]

    enum CodingKeys: String, CodingKey {
        case notifyAllCategories = "notify_all_categories"
        case categoryIds = "category_ids"
    }
}

struct UpdateNotificationCategoriesRequest: Encodable {
    let notify_all_categories: Bool
    let category_ids: [String]
}

struct UpdateBioRequest: Encodable {
    let bio: String?
}

struct PublicUserResponse: Decodable {
    let user: AuthUser
}

final class PreferencesRepository {
    static let shared = PreferencesRepository()
    private init() {}
    
    func updateName(_ name: String) async throws {
        struct Body: Encodable { let name: String }
        struct OkResponse: Decodable { let ok: Bool }
        let _: OkResponse = try await APIClient.shared.request(
            "/preferences/name", method: .put, body: Body(name: name)
        )
    }

    func updatePhone(_ digits: String) async throws {
        struct Body: Encodable { let phone: String }
        struct Response: Decodable { let phone: String }
        let _: Response = try await APIClient.shared.request(
            "/preferences/phone", method: .put, body: Body(phone: digits)
        )
    }

    func updateState(_ code: String) async throws {
        struct Body: Encodable { let state: String }
        struct Response: Decodable { let state: String }
        let _: Response = try await APIClient.shared.request(
            "/preferences/state", method: .put, body: Body(state: code)
        )
    }

    /// Online = the worker gets pop-ups for new jobs; offline = no pop-ups.
    func setAvailability(_ available: Bool) async throws {
        struct Body: Encodable { let available: Bool }
        struct Response: Decodable { let available: Bool }
        let _: Response = try await APIClient.shared.request(
            "/preferences/availability", method: .put, body: Body(available: available)
        )
    }

    func updateBio(_ bio: String) async throws {
        struct OkResponse: Decodable { let ok: Bool }
        let body = UpdateBioRequest(bio: bio.isEmpty ? nil : bio)
        let _: OkResponse = try await APIClient.shared.request(
            "/preferences/bio", method: .put, body: body
        )
    }

    func publicProfile(userId: String) async throws -> AuthUser {
        let response: PublicUserResponse = try await APIClient.shared.request(
            "/auth/users/\(userId)", requiresAuth: false
        )
        return response.user
    }

    func homeLocation() async throws -> HomeLocationResponse {
        try await APIClient.shared.request("/preferences/home-location")
    }

    func updateHomeLocation(address: String?, latitude: Double?, longitude: Double?) async throws {
        struct OkResponse: Decodable { let ok: Bool }
        let body = UpdateHomeLocationRequest(home_address: address, home_latitude: latitude, home_longitude: longitude)
        let _: OkResponse = try await APIClient.shared.request(
            "/preferences/home-location", method: .put, body: body
        )
    }

    func notificationCategories() async throws -> NotificationCategoriesResponse {
        try await APIClient.shared.request("/preferences/notification-categories")
    }

    func updateNotificationCategories(notifyAll: Bool, categoryIds: [String]) async throws {
        struct OkResponse: Decodable { let ok: Bool }
        let body = UpdateNotificationCategoriesRequest(notify_all_categories: notifyAll, category_ids: categoryIds)
        let _: OkResponse = try await APIClient.shared.request(
            "/preferences/notification-categories", method: .put, body: body
        )
    }
}
