import Foundation

struct AppNotification: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    let type: String
    let title: String
    let body: String?
    let jobId: String?
    let readAt: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type, title, body
        case jobId = "job_id"
        case readAt = "read_at"
        case createdAt = "created_at"
    }

    var isRead: Bool { readAt != nil }

    var iconName: String {
        switch type {
        case "new_offer": return "hand.raised.fill"
        case "offer_accepted": return "checkmark.circle.fill"
        case "offer_rejected": return "xmark.circle.fill"
        case "job_started": return "play.circle.fill"
        case "payment_required": return "clock.fill"
        case "payment_succeeded": return "checkmark.seal.fill"
        case "new_message": return "message.fill"
        case "job_expired": return "calendar.badge.exclamationmark"
        case "job_starting_soon": return "alarm.fill"
        case "job_late_reminder", "worker_late": return "exclamationmark.clock.fill"
        case "worker_on_the_way": return "car.fill"
        case "confirm_attendance": return "questionmark.circle.fill"
        case "spot_opened": return "bolt.fill"
        case "job_requested": return "star.fill"        case "on_standby": return "hourglass"
        case "worker_dropped", "removed_from_job": return "person.fill.xmark"
        case "replacement_found": return "person.fill.checkmark"
        case "account_paused": return "pause.circle.fill"
        case "dispute_raised": return "exclamationmark.bubble.fill"
        default: return "bell.fill"
        }
    }
    
    var isWarning: Bool {
        ["worker_late", "job_late_reminder", "payment_required", "worker_dropped", "removed_from_job", "account_paused"].contains(type)
    }
}
