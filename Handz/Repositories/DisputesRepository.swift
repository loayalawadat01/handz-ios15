import Foundation

final class DisputesRepository {
    static let shared = DisputesRepository()
    private init() {}

    private struct RaiseRequest: Encodable {
        let issue_type: String
        let details: String?
        let against_user_id: String?
    }

    /// Returns true if the job was reopened (worker no-show).
    func raiseDispute(jobId: String, issueType: String, details: String?, againstUserId: String?) async throws -> Bool {
        struct Response: Decodable { let job_reopened: Bool }
        let response: Response = try await APIClient.shared.request(
            "/disputes/jobs/\(jobId)", method: .post,
            body: RaiseRequest(issue_type: issueType, details: details, against_user_id: againstUserId)
        )
        return response.job_reopened
    }

    func disputesForJob(jobId: String) async throws -> [Dispute] {
        struct Response: Decodable { let disputes: [Dispute] }
        let response: Response = try await APIClient.shared.request("/disputes/jobs/\(jobId)")
        return response.disputes
    }

    /// The person a problem is about tells their side (Handz reads both sides).
    func respond(disputeId: String, response: String) async throws -> Dispute {
        struct Body: Encodable { let response: String }
        struct Response: Decodable { let dispute: Dispute }
        let result: Response = try await APIClient.shared.request(
            "/disputes/\(disputeId)/respond", method: .post, body: Body(response: response)
        )
        return result.dispute
    }

    func myDisputes() async throws -> [Dispute] {
        struct Response: Decodable { let disputes: [Dispute] }
        let response: Response = try await APIClient.shared.request("/disputes/mine")
        return response.disputes
    }
}
