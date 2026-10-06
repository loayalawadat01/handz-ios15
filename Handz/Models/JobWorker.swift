import Foundation

enum JobWorkerStatus: String, Codable {
    case active = "ACTIVE"
    case cancelled = "CANCELLED"
    case completed = "COMPLETED"
}

/// Where a worker is right now, while they're on the way (customer only).
struct LiveLocation: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case latitude, longitude
        case updatedAt = "updated_at"
    }
}

struct JobWorker: Codable, Identifiable, Equatable {
    let id: String
    let jobId: String
    let workerId: String
    let offerId: String
    let status: JobWorkerStatus
    let startedAt: Date?
    let completedAt: Date?
    let cancelledAt: Date?
    let cancelledReason: String?
    let onTheWayAt: Date?
    let etaMinutes: Int?
    let confirmedAt: Date?
    let cancelledBy: String?
    let createdAt: Date
    let workerName: String?
    let workerPhotoUrl: String?
    let workerPhone: String?   // only sent to the customer, from acceptance until 24h after finishing
    let workerIdentityVerified: Bool?
    let liveLocation: LiveLocation?   // only sent to the customer, while the worker is on the way

    enum CodingKeys: String, CodingKey {
        case id, status
        case jobId = "job_id"
        case workerId = "worker_id"
        case offerId = "offer_id"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case cancelledAt = "cancelled_at"
        case cancelledReason = "cancelled_reason"
        case onTheWayAt = "on_the_way_at"
        case etaMinutes = "eta_minutes"
        case confirmedAt = "confirmed_at"
        case cancelledBy = "cancelled_by"
        case createdAt = "created_at"
        case workerName = "worker_name"
        case workerPhotoUrl = "worker_photo_url"
        case workerPhone = "worker_phone"
        case workerIdentityVerified = "worker_identity_verified"
        case liveLocation = "live_location"
    }
}
