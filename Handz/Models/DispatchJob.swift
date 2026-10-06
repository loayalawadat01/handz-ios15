import Foundation

/// A job pushed to a worker as a pop-up, with extra fields the regular
/// Job model doesn't carry (customer trust info, distance).
struct DispatchJob: Codable, Identifiable, Equatable {
    let id: String
    let customerId: String
    let title: String
    let description: String
    let category: String
    let state: String
    let city: String
    let area: String?
    let scheduledAt: Date
    let isFlexibleSchedule: Int
    let durationHours: Double
    let workersNeeded: Int
    let targetRate: Double?
    let customerName: String
    let customerRating: Double?
    let customerReviewCount: Int
    let distanceMiles: Double?
    let tools: String?
    let isUrgent: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case customerId = "customer_id"
        case title, description, category, state, city, area
        case scheduledAt = "scheduled_at"
        case isFlexibleSchedule = "is_flexible_schedule"
        case durationHours = "duration_hours"
        case workersNeeded = "workers_needed"
        case targetRate = "target_rate"
        case customerName = "customer_name"
        case customerRating = "customer_rating"
        case customerReviewCount = "customer_review_count"
        case distanceMiles = "distance_miles"
        case tools
        case isUrgent = "is_urgent"
    }
}
