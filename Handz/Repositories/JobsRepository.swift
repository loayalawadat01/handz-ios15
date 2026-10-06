import Foundation

/// Matches GET /jobs response shape.
struct JobsListResponse: Decodable {
    let jobs: [Job]
    let categories: [JobCategory]
}

/// Matches GET /jobs/mine response shape.
struct MyJobsResponse: Decodable {
    let jobs: [Job]
}

/// Matches GET /jobs/:id response shape.
struct JobDetailResponse: Decodable {
    let job: Job
    let offers: [Offer]
    let workers: [JobWorker]
}

struct PostJobRequest: Encodable {
    let title: String
    let description: String
    let category: String
    let city: String
    let area: String?
    let address: String
    let state: String
    let latitude: Double?
    let longitude: Double?
    let scheduledAt: String // ISO8601 string
    let isFlexibleSchedule: Bool
    let durationHours: Double
    let workersNeeded: Int
    let targetRate: Double?
    let arrivalInstructions: String?
    let tools: String?
    let photoUrls: [String]
    let requestedWorkerId: String?

    enum CodingKeys: String, CodingKey {
        case title, description, category, city, area, address, state, latitude, longitude, tools
        case scheduledAt = "scheduled_at"
        case isFlexibleSchedule = "is_flexible_schedule"
        case durationHours = "duration_hours"
        case workersNeeded = "workers_needed"
        case targetRate = "target_rate"
        case arrivalInstructions = "arrival_instructions"
        case photoUrls = "photo_urls"
        case requestedWorkerId = "requested_worker_id"
    }
}

/// Talks to /api/jobs. ViewModels call this rather than APIClient
/// directly, per spec section 38's layered architecture.
final class JobsRepository {
    static let shared = JobsRepository()
    private init() {}

    func listOpenJobs(category: String? = nil) async throws -> JobsListResponse {
        var path = "/jobs"
        if let category {
            path += "?category=\(category)"
        }
        return try await APIClient.shared.request(path, requiresAuth: false)
    }

    func myJobs() async throws -> [Job] {
        let response: MyJobsResponse = try await APIClient.shared.request("/jobs/mine")
        return response.jobs
    }

    func jobDetail(id: String) async throws -> JobDetailResponse {
        try await APIClient.shared.request("/jobs/\(id)", requiresAuth: false)
    }
    func savedJobs() async throws -> [Job] {
        let response: MyJobsResponse = try await APIClient.shared.request("/jobs/saved")
        return response.jobs
    }

    func saveJob(id: String) async throws {
        struct OkResponse: Decodable { let ok: Bool }
        let _: OkResponse = try await APIClient.shared.request(
            "/jobs/\(id)/save", method: .post
        )
    }

    func unsaveJob(id: String) async throws {
        struct OkResponse: Decodable { let ok: Bool }
        let _: OkResponse = try await APIClient.shared.request(
            "/jobs/\(id)/save", method: .delete
        )
    }
    
    func rateGuidance(category: String, durationHours: Double?) async throws -> RateGuidance {
        var path = "/jobs/rate-guidance?category=\(category)"
        if let hours = durationHours {
            path += "&duration_hours=\(hours)"
        }
        return try await APIClient.shared.request(path, requiresAuth: false)
    }

    func postJob(_ request: PostJobRequest) async throws -> Job {
        struct Response: Decodable { let job: Job }
        let response: Response = try await APIClient.shared.request(
            "/jobs", method: .post, body: request
        )
        return response.job
    }

    func cancelJob(id: String) async throws {
        struct OkResponse: Decodable { let ok: Bool }
        let _: OkResponse = try await APIClient.shared.request(
            "/jobs/\(id)/cancel", method: .patch
        )
    }

    struct CancelWithReasonRequest: Encodable {
        let reason: String
    }

    func cancelJobWithReason(id: String, reason: String) async throws {
        struct OkResponse: Decodable { let ok: Bool }
        let body = CancelWithReasonRequest(reason: reason)
        let _: OkResponse = try await APIClient.shared.request(
            "/jobs/\(id)/cancel-with-reason", method: .patch, body: body
        )
    }

    func closeJobToOffers(id: String) async throws {
        struct OkResponse: Decodable { let ok: Bool }
        let _: OkResponse = try await APIClient.shared.request(
            "/jobs/\(id)/close-to-offers", method: .patch
        )
    }

    func completeJob(id: String) async throws {
        struct OkResponse: Decodable { let ok: Bool }
        let _: OkResponse = try await APIClient.shared.request(
            "/jobs/\(id)/complete", method: .patch
        )
    }
}
