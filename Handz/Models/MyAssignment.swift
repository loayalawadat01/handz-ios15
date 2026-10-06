import Foundation

/// A worker's assignment summary, used by Home and My Work.
struct MyAssignment: Codable, Identifiable, Equatable {
    let id: String
    let jobId: String
    let status: JobWorkerStatus
    let startedAt: Date?
    let completedAt: Date?
    let jobTitle: String
    let jobStatus: JobStatus
    let hasReviewed: Int
    let scheduledAt: Date?
    let isFlexibleSchedule: Int?
    let durationHours: Double?
    let city: String?
    let area: String?
    let targetRate: Double?

    enum CodingKeys: String, CodingKey {
        case id, status, city, area
        case jobId = "job_id"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case jobTitle = "job_title"
        case jobStatus = "job_status"
        case hasReviewed = "has_reviewed"
        case scheduledAt = "scheduled_at"
        case isFlexibleSchedule = "is_flexible_schedule"
        case durationHours = "duration_hours"
        case targetRate = "target_rate"
    }
}
