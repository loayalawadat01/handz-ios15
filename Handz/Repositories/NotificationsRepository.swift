import Foundation

struct NotificationsResponse: Decodable {
    let notifications: [AppNotification]
    let unreadCount: Int

    enum CodingKeys: String, CodingKey {
        case notifications
        case unreadCount = "unread_count"
    }
}

final class NotificationsRepository {
    static let shared = NotificationsRepository()
    private init() {}

    func list() async throws -> NotificationsResponse {
        try await APIClient.shared.request("/notifications")
    }

    func markRead(id: String) async throws {
        struct OkResponse: Decodable { let ok: Bool }
        let _: OkResponse = try await APIClient.shared.request(
            "/notifications/\(id)/mark-read", method: .post
        )
    }
    
    func nextPopup() async throws -> AppNotification? {
        struct Response: Decodable { let notification: AppNotification? }
        let response: Response = try await APIClient.shared.request("/notifications/next-popup")
        return response.notification
    }

    func markAllRead() async throws {
        struct OkResponse: Decodable { let ok: Bool }
        let _: OkResponse = try await APIClient.shared.request(
            "/notifications/mark-all-read", method: .post
        )
    }
}
