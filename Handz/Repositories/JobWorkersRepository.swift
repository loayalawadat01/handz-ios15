import Foundation

/// Talks to /api/job-workers -- starting/completing a worker's own
/// assignment on a job, the geofenced start and code-fallback flow
/// (spec item 10), and the duration-locked completion with its own
/// code fallback.
final class JobWorkersRepository {
    static let shared = JobWorkersRepository()
    private init() {}

    struct StartJobRequest: Encodable {
        let latitude: Double?
        let longitude: Double?
        let start_code: String?
    }

    struct CompleteJobRequest: Encodable {
        let completion_code: String?
    }

    func startJobWorker(id: String, latitude: Double?, longitude: Double?, startCode: String?) async throws {
        struct OkResponse: Decodable { let ok: Bool }
        let body = StartJobRequest(latitude: latitude, longitude: longitude, start_code: startCode)
        let _: OkResponse = try await APIClient.shared.request(
            "/job-workers/\(id)/start", method: .patch, body: body
        )
    }

    /// Returns the payment, or nil when the pay is on hold because of a reported problem.
    @discardableResult
    func completeJobWorker(id: String, completionCode: String? = nil) async throws -> Payment? {
        struct Response: Decodable { let ok: Bool; let payment: Payment? }
        let body = CompleteJobRequest(completion_code: completionCode)
        let response: Response = try await APIClient.shared.request(
            "/job-workers/\(id)/complete", method: .patch, body: body
        )
        return response.payment
    }

    func generateStartCode(id: String) async throws -> String {
        struct Response: Decodable { let code: String }
        let response: Response = try await APIClient.shared.request(
            "/job-workers/\(id)/generate-start-code", method: .post
        )
        return response.code
    }

    func generateCompletionCode(id: String) async throws -> String {
        struct Response: Decodable { let code: String }
        let response: Response = try await APIClient.shared.request(
            "/job-workers/\(id)/generate-completion-code", method: .post
        )
        return response.code
    }

    func summary(id: String) async throws -> JobWorkerSummary {
        try await APIClient.shared.request("/job-workers/\(id)/summary")
    }
    
    /// The worker's position while on the way (only the customer sees it).
    func shareLocation(id: String, latitude: Double, longitude: Double) async throws {
        struct Body: Encodable { let latitude: Double; let longitude: Double }
        struct OkResponse: Decodable { let ok: Bool }
        let _: OkResponse = try await APIClient.shared.request(
            "/job-workers/\(id)/location", method: .patch, body: Body(latitude: latitude, longitude: longitude)
        )
    }

    func markOnTheWay(id: String, etaMinutes: Int) async throws {
        struct Body: Encodable { let eta_minutes: Int }
        struct OkResponse: Decodable { let ok: Bool }
        let _: OkResponse = try await APIClient.shared.request(
            "/job-workers/\(id)/on-the-way", method: .patch, body: Body(eta_minutes: etaMinutes)
        )
    }
    
    func confirmAttendance(id: String) async throws {
        struct OkResponse: Decodable { let ok: Bool }
        let _: OkResponse = try await APIClient.shared.request("/job-workers/\(id)/confirm", method: .patch)
    }

    /// Returns true if it counted as a late cancellation.
    func cancelAssignment(id: String, reason: String) async throws -> Bool {
        struct Body: Encodable { let reason: String }
        struct Response: Decodable { let ok: Bool; let late: Bool }
        let response: Response = try await APIClient.shared.request(
            "/job-workers/\(id)/cancel", method: .patch, body: Body(reason: reason)
        )
        return response.late
    }

    func removeWorker(id: String) async throws {
        struct OkResponse: Decodable { let ok: Bool }
        let _: OkResponse = try await APIClient.shared.request("/job-workers/\(id)/remove", method: .patch)
    }

    func myAssignments() async throws -> [MyAssignment] {
        struct Response: Decodable { let assignments: [MyAssignment] }
        let response: Response = try await APIClient.shared.request("/job-workers/mine")
        return response.assignments
    }
}
