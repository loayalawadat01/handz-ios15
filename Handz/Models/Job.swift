import Foundation
import SwiftUI

/// Matches the job lifecycle values from the backend's jobs.status
/// CHECK constraint exactly (server/src/db.js).
enum JobStatus: String, Codable {
    case open = "OPEN"
    case offerAccepted = "OFFER_ACCEPTED"
    case awaitingPayment = "AWAITING_PAYMENT"
    case paid = "PAID"
    case inProgress = "IN_PROGRESS"
    case completed = "COMPLETED"
    case cancelled = "CANCELLED"
    case paymentFailed = "PAYMENT_FAILED"
    case paymentOverdue = "PAYMENT_OVERDUE"
    case disputed = "DISPUTED"
    case expired = "EXPIRED"

    /// Human-readable label for UI display, since raw enum cases
    /// shouldn't be shown directly to users.
    var displayLabel: String {
        switch self {
        case .open: return "Open"
        case .offerAccepted: return "Workers Accepted"
        case .awaitingPayment: return "Awaiting Payment"
        case .paid: return "Paid"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        case .paymentFailed: return "Payment Failed"
        case .paymentOverdue: return "Payment Overdue"
        case .disputed: return "Disputed"
        case .expired: return "Expired"
        }
    }

    var color: Color {
        switch self {
        case .open: return HandzColor.statusOpen
        case .inProgress: return HandzColor.statusInProgress
        case .offerAccepted, .awaitingPayment, .paymentOverdue: return HandzColor.statusPending
        case .completed, .paid: return HandzColor.statusCompleted
        case .cancelled, .paymentFailed, .disputed, .expired: return HandzColor.danger
        }
    }
}

/// Minimal customer info attached to a job, as returned by
/// GET /jobs and GET /jobs/:id (server/src/routes/jobs.js jobWithExtras).
struct JobCustomer: Codable, Equatable {
    let id: String
    let name: String
}

struct Job: Codable, Identifiable, Equatable {
    let id: String
    let customerId: String
    let title: String
    let description: String
    let category: String
    let state: String
    let city: String
    let area: String?
    let address: String? // null when hidden from this viewer (privacy rules)
    let latitude: Double?
    let longitude: Double?
    /// True when the viewer only gets the rough area (about 1 km), not the exact spot.
    let locationIsApproximate: Bool?
    let scheduledAt: Date
    let isFlexibleSchedule: Int
    let durationHours: Double
    let workersNeeded: Int
    let targetRate: Double?
    let status: JobStatus
    let closedToNewOffers: Int
    let paymentDeadlineAt: Date?
    let createdAt: Date
    let offerCount: Int
    let acceptedWorkersCount: Int
    let customer: JobCustomer
    let isSaved: Bool
    let customerPhone: String?   // only sent to an accepted worker
    let arrivalInstructions: String?   // only sent to the hire and hired workers
    let tools: String?
    let photos: [String]?
    let replacementUntil: Date?
    let isUrgent: Int?
    let requestedWorkerId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case customerId = "customer_id"
        case title, description, category, state, city, area, address
        case latitude, longitude
        case locationIsApproximate = "location_is_approximate"
        case scheduledAt = "scheduled_at"
        case isFlexibleSchedule = "is_flexible_schedule"
        case durationHours = "duration_hours"
        case workersNeeded = "workers_needed"
        case targetRate = "target_rate"
        case status
        case closedToNewOffers = "closed_to_new_offers"
        case paymentDeadlineAt = "payment_deadline_at"
        case createdAt = "created_at"
        case offerCount = "offer_count"
        case acceptedWorkersCount = "accepted_workers_count"
        case customer
        case isSaved = "is_saved"
        case customerPhone = "customer_phone"
        case arrivalInstructions = "arrival_instructions"
        case tools, photos
        case replacementUntil = "replacement_until"
        case isUrgent = "is_urgent"
        case requestedWorkerId = "requested_worker_id"
    }
}

/// A category as returned by GET /jobs (categories array) --
/// server/src/db.js categories table.
struct JobCategory: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let groupName: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case groupName = "group_name"
    }

    var displayName: String {
        name.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
