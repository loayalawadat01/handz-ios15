import Foundation

struct BlockedUser: Codable, Identifiable, Equatable {
    let id: String
    let name: String
}

final class SafetyRepository {
    static let shared = SafetyRepository()
    private init() {}

    private struct OkResponse: Decodable { let ok: Bool }

    func block(userId: String) async throws {
        let _: OkResponse = try await APIClient.shared.request("/safety/block/\(userId)", method: .post)
    }

    func unblock(userId: String) async throws {
        let _: OkResponse = try await APIClient.shared.request("/safety/block/\(userId)", method: .delete)
    }

    func isBlocked(userId: String) async throws -> Bool {
        struct Response: Decodable { let blocked: Bool }
        let response: Response = try await APIClient.shared.request("/safety/block-status/\(userId)")
        return response.blocked
    }

    func blockedUsers() async throws -> [BlockedUser] {
        struct Response: Decodable { let blocked: [BlockedUser] }
        let response: Response = try await APIClient.shared.request("/safety/blocked")
        return response.blocked
    }

    func report(userId: String, reason: String, details: String?) async throws {
        struct Body: Encodable { let reason: String; let details: String? }
        let _: OkResponse = try await APIClient.shared.request(
            "/safety/report/\(userId)", method: .post, body: Body(reason: reason, details: details)
        )
    }
}
