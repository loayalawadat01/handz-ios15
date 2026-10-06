import Foundation

@MainActor
final class ReviewSubmissionViewModel: ObservableObject {
    let jobId: String

    @Published var pendingReviews: [ReviewPendingCounterpart] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var isSubmitting: Bool = false

    // Current review being composed.
    @Published var rating: Int = 5
    @Published var comment: String = ""

    private let reviewsRepository: ReviewsRepository

    init(jobId: String, reviewsRepository: ReviewsRepository = .shared) {
        self.jobId = jobId
        self.reviewsRepository = reviewsRepository
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            pendingReviews = try await reviewsRepository.pendingReviews(jobId: jobId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func submitReview(for counterpart: ReviewPendingCounterpart) async {
        isSubmitting = true
        do {
            _ = try await reviewsRepository.submitReview(
                jobId: jobId, revieweeId: counterpart.id, rating: rating, comment: comment.isEmpty ? nil : comment
            )
            successMessage = "Review submitted!"
            rating = 5
            comment = ""
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}
