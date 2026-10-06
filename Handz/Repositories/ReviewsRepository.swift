import Foundation

struct ReviewsForUserResponse: Decodable {
    let reviews: [Review]
    let averageRating: Double?
    let reviewCount: Int

    enum CodingKeys: String, CodingKey {
        case reviews
        case averageRating = "average_rating"
        case reviewCount = "review_count"
    }
}

struct PendingReviewsResponse: Decodable {
    let pending: [ReviewPendingCounterpart]
}

struct SubmitReviewRequest: Encodable {
    let revieweeId: String
    let rating: Int
    let comment: String?

    enum CodingKeys: String, CodingKey {
        case revieweeId = "reviewee_id"
        case rating, comment
    }
}

/// Talks to /api/reviews.
final class ReviewsRepository {
    static let shared = ReviewsRepository()
    private init() {}

    func reviewsForUser(userId: String) async throws -> ReviewsForUserResponse {
        try await APIClient.shared.request("/reviews/user/\(userId)", requiresAuth: false)
    }

    func pendingReviews(jobId: String) async throws -> [ReviewPendingCounterpart] {
        let response: PendingReviewsResponse = try await APIClient.shared.request(
            "/reviews/jobs/\(jobId)/pending-for-me"
        )
        return response.pending
    }

    func submitReview(jobId: String, revieweeId: String, rating: Int, comment: String?) async throws -> Review {
        struct Response: Decodable { let review: Review }
        let body = SubmitReviewRequest(revieweeId: revieweeId, rating: rating, comment: comment)
        let response: Response = try await APIClient.shared.request(
            "/reviews/jobs/\(jobId)", method: .post, body: body
        )
        return response.review
    }
}
