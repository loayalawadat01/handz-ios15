import Foundation

/// A reported problem as an admin sees it, with the money involved.
struct AdminDispute: Decodable, Identifiable, Equatable {
    struct PaymentInfo: Decodable, Equatable {
        let id: String
        let status: PaymentStatus
        let totalChargedToCustomer: Double
        let workerPayoutAmount: Double
        let refundedAmount: Double
        let refundableAmount: Double

        enum CodingKeys: String, CodingKey {
            case id, status
            case totalChargedToCustomer = "total_charged_to_customer"
            case workerPayoutAmount = "worker_payout_amount"
            case refundedAmount = "refunded_amount"
            case refundableAmount = "refundable_amount"
        }
    }

    let id: String
    let jobId: String
    let jobTitle: String
    let jobStatus: String
    let issueType: String
    let reason: String
    let status: DisputeStatus
    let resolution: String?
    let refundAmount: Double?
    let resolutionNotes: String?
    let createdAt: Date
    let resolvedAt: Date?
    let customerName: String?
    let workerName: String?
    let raisedByName: String?
    let raisedByRole: String
    let payment: PaymentInfo?

    var isOpen: Bool { status == .open || status == .underReview }
    var isBankChargeback: Bool { issueType == "bank_chargeback" }

    var issueLabel: String {
        isBankChargeback ? "Bank chargeback" : issueType.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var resolutionLabel: String? {
        switch resolution {
        case "full_refund": return "Full refund"
        case "partial_refund": return "Partial refund"
        case "pay_worker": return "Worker paid"
        case "dismiss": return "Closed"
        default: return nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, reason, status, resolution, payment
        case jobId = "job_id"
        case jobTitle = "job_title"
        case jobStatus = "job_status"
        case issueType = "issue_type"
        case refundAmount = "refund_amount"
        case resolutionNotes = "resolution_notes"
        case createdAt = "created_at"
        case resolvedAt = "resolved_at"
        case customerName = "customer_name"
        case workerName = "worker_name"
        case raisedByName = "raised_by_name"
        case raisedByRole = "raised_by_role"
    }
}

enum AdminDecision: String {
    case fullRefund = "full_refund"
    case partialRefund = "partial_refund"
    case payWorker = "pay_worker"
    case dismiss = "dismiss"
}

/// Talks to /api/admin (only works for Handz admins).
final class AdminRepository {
    static let shared = AdminRepository()
    private init() {}

    private struct DisputesResponse: Decodable { let disputes: [AdminDispute] }
    private struct DisputeResponse: Decodable { let dispute: AdminDispute }

    func disputes(open: Bool) async throws -> [AdminDispute] {
        let response: DisputesResponse = try await APIClient.shared.request(
            "/admin/disputes?status=\(open ? "open" : "closed")"
        )
        return response.disputes
    }

    func resolve(disputeId: String, decision: AdminDecision, amount: Double?, notes: String) async throws -> AdminDispute {
        struct Body: Encodable {
            let action: String
            let amount: Double?
            let notes: String
        }
        let response: DisputeResponse = try await APIClient.shared.request(
            "/admin/disputes/\(disputeId)/resolve",
            method: .post,
            body: Body(action: decision.rawValue, amount: amount, notes: notes)
        )
        return response.dispute
    }
}
