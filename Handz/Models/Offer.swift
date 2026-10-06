import Foundation

/// Matches offers.status CHECK constraint exactly.
enum OfferStatus: String, Codable {
    case pending = "PENDING"
    case accepted = "ACCEPTED"
    case rejected = "REJECTED"
    case withdrawn = "WITHDRAWN"
    case standby = "STANDBY"

    var displayLabel: String {
        switch self {
        case .pending: return "Waiting"
        case .accepted: return "Hired"
        case .rejected: return "Not selected"
        case .withdrawn: return "Withdrawn"
        case .standby: return "On standby"
        }
    }
}

struct Offer: Codable, Identifiable, Equatable {
    let id: String
    let jobId: String
    let workerId: String
    let amount: Double
    let message: String?
    let status: OfferStatus
    let createdAt: Date
    let workerName: String? // present on GET /jobs/:id (joined), absent elsewhere
    let workerReliability: Reliability?
    let workerPhotoUrl: String?
    let workerBio: String?
    let workerYearsExperience: Int?
    let workerIdentityVerified: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case jobId = "job_id"
        case workerId = "worker_id"
        case amount, message, status
        case createdAt = "created_at"
        case workerName = "worker_name"
        case workerReliability = "worker_reliability"
        case workerPhotoUrl = "worker_photo_url"
        case workerBio = "worker_bio"
        case workerYearsExperience = "worker_years_experience"
        case workerIdentityVerified = "worker_identity_verified"
    }
}

/// A worker's own offer, with job context attached -- matches
/// GET /offers/mine response shape.
struct MyOffer: Codable, Identifiable, Equatable {
    let id: String
    let jobId: String
    let workerId: String
    let amount: Double
    let message: String?
    let status: OfferStatus
    let createdAt: Date
    let jobTitle: String
    let jobStatus: JobStatus
    let scheduledAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case jobId = "job_id"
        case workerId = "worker_id"
        case amount, message, status
        case createdAt = "created_at"
        case jobTitle = "job_title"
        case jobStatus = "job_status"
        case scheduledAt = "scheduled_at"
    }
}
