import Foundation

enum DisputeStatus: String, Codable {
    case open = "OPEN"
    case underReview = "UNDER_REVIEW"
    case resolved = "RESOLVED"
    case dismissed = "DISMISSED"

    var displayLabel: String {
        switch self {
        case .open: return "Submitted"
        case .underReview: return "Under review"
        case .resolved: return "Resolved"
        case .dismissed: return "Closed"
        }
    }
}

struct Dispute: Codable, Identifiable, Equatable {
    let id: String
    let jobId: String
    let raisedBy: String
    let againstUserId: String?
    let issueType: String
    let reason: String
    let status: DisputeStatus
    let resolutionNotes: String?
    let createdAt: Date
    let resolvedAt: Date?
    let raisedByName: String?
    let jobTitle: String?
    // The case tracker
    let resolution: String?        // full_refund, partial_refund, pay_worker, dismiss
    let refundAmount: Double?
    let response: String?          // your own side, if you're the one it's about
    let respondedAt: Date?
    let hasResponse: Bool?
    let canRespond: Bool?
    let payPaused: Bool?

    enum CodingKeys: String, CodingKey {
        case id, reason, status
        case jobId = "job_id"
        case raisedBy = "raised_by"
        case againstUserId = "against_user_id"
        case issueType = "issue_type"
        case resolutionNotes = "resolution_notes"
        case createdAt = "created_at"
        case resolvedAt = "resolved_at"
        case raisedByName = "raised_by_name"
        case jobTitle = "job_title"
        case resolution, response
        case refundAmount = "refund_amount"
        case respondedAt = "responded_at"
        case hasResponse = "has_response"
        case canRespond = "can_respond"
        case payPaused = "pay_paused"
    }

    var isOpen: Bool { status == .open || status == .underReview }

    /// What Handz decided, in plain words.
    var decisionText: String? {
        switch resolution {
        case "full_refund": return "Full refund"
        case "partial_refund":
            if let amount = refundAmount { return "Partial refund of \(amount.formatted(.currency(code: "USD")))" }
            return "Partial refund"
        case "pay_worker": return "Worker paid"
        case "dismiss", "dismissed": return "Closed by Handz"
        default: return isOpen ? nil : status.displayLabel
        }
    }

    var issueLabel: String { HelpIssue.label(for: issueType) }
}
