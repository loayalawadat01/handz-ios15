import Foundation

struct ConversationsResponse: Decodable {
    let conversations: [Conversation]
}

struct MessagesWithUserResponse: Decodable {
    let messages: [Message]
}

struct SendMessageRequest: Encodable {
    let body: String
}

/// Talks to /api/messages -- one conversation per person, spanning
/// every job they've had together.
final class MessagesRepository {
    static let shared = MessagesRepository()
    private init() {}

    func conversations() async throws -> [Conversation] {
        let response: ConversationsResponse = try await APIClient.shared.request("/messages/conversations")
        return response.conversations
    }

    func messages(withUserId userId: String) async throws -> [Message] {
        let response: MessagesWithUserResponse = try await APIClient.shared.request("/messages/with/\(userId)")
        return response.messages
    }

    func sendMessage(toUserId userId: String, body: String) async throws -> Message {
        struct Response: Decodable { let message: Message }
        let request = SendMessageRequest(body: body)
        let response: Response = try await APIClient.shared.request(
            "/messages/with/\(userId)", method: .post, body: request
        )
        return response.message
    }

    func markRead(withUserId userId: String) async throws {
        struct OkResponse: Decodable { let ok: Bool }
        let _: OkResponse = try await APIClient.shared.request(
            "/messages/with/\(userId)/mark-read", method: .post
        )
    }
}
