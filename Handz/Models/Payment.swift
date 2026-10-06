import SwiftUI

enum PaymentStatus: String, Codable {
    case authorized = "AUTHORIZED"
    case succeeded = "SUCCEEDED"
    case canceled = "CANCELED"
    case failed = "FAILED"
    case pending = "PENDING"
    case simulated = "SIMULATED"

    var displayLabel: String {
        switch self {
        case .authorized: return "Held on card"
        case .succeeded: return "Paid"
        case .canceled: return "Released"
        case .failed: return "Failed"
        case .pending: return "Scheduled"
        case .simulated: return "Pending"
        }
    }

    var color: Color {
        switch self {
        case .succeeded: return HandzColor.accent
        case .authorized, .pending, .simulated: return HandzColor.warning
        case .canceled: return HandzColor.textSecondary
        case .failed: return HandzColor.danger
        }
    }
}

enum StripeFeeMode: String, Codable {
    case customer = "CUSTOMER"
    case platform = "PLATFORM"
    case included = "INCLUDED"
}

struct Payment: Codable, Identifiable, Equatable {
    let id: String
    let jobId: String
    let jobWorkerId: String
    let workerId: String
    let workerAmount: Double
    let workerFeePercent: Double
    let workerFeeAmount: Double
    let workerPayoutAmount: Double
    let platformFeePercent: Double
    let platformFeeAmount: Double
    let stripeFeeMode: StripeFeeMode
    let stripeFeeAmount: Double
    let totalChargedToCustomer: Double
    let stripePaymentIntentId: String?
    let status: PaymentStatus
    let capturedAt: Date?
    let kind: String?
    let createdAt: Date
    let jobTitle: String?
    /// When the money will be held on the card (12 hours before the job).
    let holdDueAt: Date?
    /// "declined" or "needs_confirmation" when the hold didn't go through.
    let holdProblem: String?
    let refundedAmount: Double?
    /// Set once the payment is charged, e.g. "HZ-2026-000123".
    let receiptNumber: String?

    /// The customer has to confirm this payment in the app before work can start.
    var needsCustomerAction: Bool { status == .pending && holdProblem != nil }

    /// The amounts above are the full price. A refund comes back from the
    /// worker and Handz in the same proportion the payment was split.
    private var keptShare: Double {
        guard status == .succeeded, totalChargedToCustomer > 0 else { return 1 }
        return max(0, 1 - (refundedAmount ?? 0) / totalChargedToCustomer)
    }

    /// What the customer paid in the end, after any refund.
    var customerPaidAfterRefunds: Double {
        guard status == .succeeded else { return totalChargedToCustomer }
        return max(0, ((totalChargedToCustomer - (refundedAmount ?? 0)) * 100).rounded() / 100)
    }

    /// What the worker keeps, after any refund.
    var workerKeepsAfterRefunds: Double {
        (workerPayoutAmount * keptShare * 100).rounded() / 100
    }

    enum CodingKeys: String, CodingKey {
        case id, status
        case jobId = "job_id"
        case jobWorkerId = "job_worker_id"
        case workerId = "worker_id"
        case workerAmount = "worker_amount"
        case workerFeePercent = "worker_fee_percent"
        case workerFeeAmount = "worker_fee_amount"
        case workerPayoutAmount = "worker_payout_amount"
        case platformFeePercent = "platform_fee_percent"
        case platformFeeAmount = "platform_fee_amount"
        case stripeFeeMode = "stripe_fee_mode"
        case stripeFeeAmount = "stripe_fee_amount"
        case totalChargedToCustomer = "total_charged_to_customer"
        case stripePaymentIntentId = "stripe_payment_intent_id"
        case capturedAt = "captured_at"
        case kind
        case createdAt = "created_at"
        case jobTitle = "job_title"
        case holdDueAt = "hold_due_at"
        case holdProblem = "hold_problem"
        case refundedAmount = "refunded_amount"
        case receiptNumber = "receipt_number"
    }
}
