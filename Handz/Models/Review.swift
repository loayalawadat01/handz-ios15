import Foundation

struct Review: Codable, Identifiable, Equatable {
    let id: String
    let jobId: String
    let reviewerId: String
    let revieweeId: String
    let rating: Int
    let comment: String?
    let createdAt: Date
    let reviewerName: String? // present on GET /reviews/user/:userId

    enum CodingKeys: String, CodingKey {
        case id
        case jobId = "job_id"
        case reviewerId = "reviewer_id"
        case revieweeId = "reviewee_id"
        case rating, comment
        case createdAt = "created_at"
        case reviewerName = "reviewer_name"
    }
}

/// Someone the current user still needs to review after a job
/// completes -- matches GET /reviews/jobs/:jobId/pending-for-me.
struct ReviewPendingCounterpart: Codable, Identifiable, Equatable {
    let id: String
    let name: String
}
