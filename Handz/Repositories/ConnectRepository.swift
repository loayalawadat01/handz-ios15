import Foundation

struct ConnectOnboardResponse: Decodable {
    let url: String
}

struct ConnectStatusResponse: Decodable {
    let connected: Bool
    let payoutsEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case connected
        case payoutsEnabled = "payouts_enabled"
    }
}

/// Talks to /api/connect -- Stripe Connect worker payout onboarding
/// (spec section 30).
final class ConnectRepository {
    static let shared = ConnectRepository()
    private init() {}

    func startOnboarding() async throws -> URL {
        let response: ConnectOnboardResponse = try await APIClient.shared.request(
            "/connect/onboard", method: .post
        )
        guard let url = URL(string: response.url) else {
            throw APIError.decodingFailed
        }
        return url
    }

    func status() async throws -> ConnectStatusResponse {
        try await APIClient.shared.request("/connect/status")
    }
}
