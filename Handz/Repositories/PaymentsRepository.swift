import Foundation

struct EarningsSummary: Decodable {
    let last7Days: Double
    let last30Days: Double
    let allTime: Double
    let pending: Double
    let paidJobs: Int

    enum CodingKeys: String, CodingKey {
        case last7Days = "last_7_days"
        case last30Days = "last_30_days"
        case allTime = "all_time"
        case pending
        case paidJobs = "paid_jobs"
    }
}

struct PaymentsForJobResponse: Decodable {
    let payments: [Payment]
    let stripeLive: Bool

    enum CodingKeys: String, CodingKey {
        case payments
        case stripeLive = "stripe_live"
    }
}

struct MyPaymentsResponse: Decodable {
    let asWorker: [Payment]
    let asCustomer: [Payment]

    enum CodingKeys: String, CodingKey {
        case asWorker = "as_worker"
        case asCustomer = "as_customer"
    }
}

/// One saved card (Stripe keeps the card itself; we only see brand and last 4).
struct SavedCard: Decodable, Identifiable, Equatable {
    let id: String
    let brand: String
    let last4: String
    let expMonth: Int
    let expYear: Int
    let isDefault: Bool

    enum CodingKeys: String, CodingKey {
        case id, brand, last4
        case expMonth = "exp_month"
        case expYear = "exp_year"
        case isDefault = "is_default"
    }
}

struct SavedCardsResponse: Decodable {
    let cards: [SavedCard]
}

/// What Stripe's card form needs to save a new card.
struct CardSetupSession: Decodable {
    let setupIntentId: String
    let setupIntentClientSecret: String
    let customerId: String
    let ephemeralKey: String
    let publishableKey: String

    enum CodingKeys: String, CodingKey {
        case setupIntentId = "setup_intent_id"
        case setupIntentClientSecret = "setup_intent_client_secret"
        case customerId = "customer_id"
        case ephemeralKey = "ephemeral_key"
        case publishableKey = "publishable_key"
    }
}

/// What Stripe's payment form needs for the customer to confirm a hold.
struct ConfirmPaymentSession: Decodable {
    let paymentIntentId: String
    let paymentIntentClientSecret: String
    let customerId: String
    let ephemeralKey: String
    let publishableKey: String
    let amount: Double

    enum CodingKeys: String, CodingKey {
        case amount
        case paymentIntentId = "payment_intent_id"
        case paymentIntentClientSecret = "payment_intent_client_secret"
        case customerId = "customer_id"
        case ephemeralKey = "ephemeral_key"
        case publishableKey = "publishable_key"
    }
}

/// A receipt for one payment. The server works out every line, so the app only draws it.
struct Receipt: Decodable, Identifiable, Equatable {
    struct Line: Decodable, Equatable {
        let label: String
        let amount: Double
    }

    struct JobInfo: Decodable, Equatable {
        let id: String
        let title: String
        let category: String
        let scheduledAt: Date?
        let durationHours: Double
        let place: String
        let startedAt: Date?
        let completedAt: Date?
        let actualHours: Double?

        enum CodingKeys: String, CodingKey {
            case id, title, category, place
            case scheduledAt = "scheduled_at"
            case durationHours = "duration_hours"
            case startedAt = "started_at"
            case completedAt = "completed_at"
            case actualHours = "actual_hours"
        }
    }

    struct Person: Decodable, Equatable {
        let id: String
        let name: String
        let photoUrl: String?
        let role: String

        enum CodingKeys: String, CodingKey {
            case id, name, role
            case photoUrl = "photo_url"
        }
    }

    struct Card: Decodable, Equatable {
        let brand: String?
        let last4: String
    }

    struct RefundItem: Decodable, Equatable {
        let amount: Double
        let createdAt: Date

        enum CodingKeys: String, CodingKey {
            case amount
            case createdAt = "created_at"
        }
    }

    let id: String
    let receiptNumber: String?
    let role: String              // "customer" or "worker": whose receipt this is
    let status: PaymentStatus
    let statusLabel: String       // "Paid", "Partly refunded", "Held on card"...
    let kind: String?
    let title: String             // "Payment receipt", "Pay receipt", "Late-cancellation fee"
    let issuedAt: Date
    let job: JobInfo
    let otherPerson: Person
    let card: Card?
    let lines: [Line]
    let total: Line               // before any refund
    let refunded: Double
    let refunds: [RefundItem]
    let final: Line               // after refunds: "You paid" / "You received"
    let note: String

    var isWorker: Bool { role == "worker" }
    var wasRefunded: Bool { refunded > 0 }

    enum CodingKeys: String, CodingKey {
        case id, role, status, kind, title, job, card, lines, total, refunded, refunds, final, note
        case receiptNumber = "receipt_number"
        case statusLabel = "status_label"
        case issuedAt = "issued_at"
        case otherPerson = "other_person"
    }
}

private struct ReceiptResponse: Decodable {
    let receipt: Receipt
}

/// Talks to /api/payments.
final class PaymentsRepository {
    static let shared = PaymentsRepository()
    private init() {}
    
    func earnings() async throws -> EarningsSummary {
        try await APIClient.shared.request("/payments/earnings")
    }

    func myPayments() async throws -> MyPaymentsResponse {
        try await APIClient.shared.request("/payments/mine")
    }

    func paymentsForJob(jobId: String) async throws -> PaymentsForJobResponse {
        try await APIClient.shared.request("/payments/job/\(jobId)")
    }

    func receipt(paymentId: String) async throws -> Receipt {
        let response: ReceiptResponse = try await APIClient.shared.request("/payments/\(paymentId)/receipt")
        return response.receipt
    }

    // MARK: Saved cards

    func cards() async throws -> [SavedCard] {
        let response: SavedCardsResponse = try await APIClient.shared.request("/payments/cards")
        return response.cards
    }

    func startAddingCard() async throws -> CardSetupSession {
        try await APIClient.shared.request("/payments/setup-card", method: .post)
    }

    /// After Stripe's card form closes: the new card becomes the default.
    func finishAddingCard(setupIntentId: String) async throws -> [SavedCard] {
        let response: SavedCardsResponse = try await APIClient.shared.request(
            "/payments/setup-card/\(setupIntentId)/finish", method: .post
        )
        return response.cards
    }

    func makeDefault(cardId: String) async throws -> [SavedCard] {
        let response: SavedCardsResponse = try await APIClient.shared.request(
            "/payments/cards/\(cardId)/default", method: .post
        )
        return response.cards
    }

    func remove(cardId: String) async throws -> [SavedCard] {
        let response: SavedCardsResponse = try await APIClient.shared.request(
            "/payments/cards/\(cardId)", method: .delete
        )
        return response.cards
    }

    // MARK: Confirming a hold that didn't go through

    func startConfirming(paymentId: String) async throws -> ConfirmPaymentSession {
        try await APIClient.shared.request("/payments/\(paymentId)/confirm-session", method: .post)
    }

    func finishConfirming(paymentId: String, paymentIntentId: String) async throws {
        struct OkResponse: Decodable { let ok: Bool }
        let _: OkResponse = try await APIClient.shared.request(
            "/payments/\(paymentId)/confirm-session/\(paymentIntentId)/finish", method: .post
        )
    }

    func confirmSimulatedPayment(id: String) async throws {
        struct OkResponse: Decodable { let ok: Bool }
        let _: OkResponse = try await APIClient.shared.request(
            "/payments/\(id)/confirm-simulated", method: .post
        )
    }
}
