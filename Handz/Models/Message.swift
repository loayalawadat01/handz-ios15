import Foundation

struct Message: Codable, Identifiable, Equatable {
    let id: String
    let conversationId: String
    let senderId: String
    let body: String
    let readAt: Date?
    let createdAt: Date
    let senderName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case body
        case readAt = "read_at"
        case createdAt = "created_at"
        case senderName = "sender_name"
    }
}

struct Conversation: Codable, Identifiable, Equatable {
    let otherUserId: String
    let otherUserName: String
    let lastMessage: Message?
    let unreadCount: Int

    var id: String { otherUserId }

    enum CodingKeys: String, CodingKey {
        case otherUserId = "other_user_id"
        case otherUserName = "other_user_name"
        case lastMessage = "last_message"
        case unreadCount = "unread_count"
    }
}
