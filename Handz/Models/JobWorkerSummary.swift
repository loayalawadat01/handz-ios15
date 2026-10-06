import Foundation

struct SummaryPerson: Codable, Equatable {
    let id: String
    let name: String
}

struct JobWorkerSummary: Codable, Equatable {
    let jobTitle: String
    let category: String
    let city: String
    let area: String?
    let scheduledDurationHours: Double
    let actualDurationHours: Double?
    let startedAt: Date?
    let completedAt: Date?
    let worker: SummaryPerson
    let customer: SummaryPerson
    let payment: Payment?

    enum CodingKeys: String, CodingKey {
        case jobTitle = "job_title"
        case category, city, area
        case scheduledDurationHours = "scheduled_duration_hours"
        case actualDurationHours = "actual_duration_hours"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case worker, customer, payment
    }
}
