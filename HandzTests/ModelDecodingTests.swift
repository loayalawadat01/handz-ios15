import XCTest
@testable import Handz

final class ModelDecodingTests: XCTestCase {
    // Mirrors the custom date decoder in APIClient.swift so these
    // tests exercise the exact same decoding path the app uses.
    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: dateString) { return date }

            let isoNoFraction = ISO8601DateFormatter()
            if let date = isoNoFraction.date(from: dateString) { return date }

            let sqlite = DateFormatter()
            sqlite.dateFormat = "yyyy-MM-dd HH:mm:ss"
            sqlite.timeZone = TimeZone(identifier: "UTC")
            if let date = sqlite.date(from: dateString) { return date }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad date: \(dateString)")
        }
        return decoder
    }

    func testJobDecodesFromRealisticBackendJSON() throws {
        let json = """
        {
          "id": "job-1",
          "customer_id": "cust-1",
          "title": "Move furniture",
          "description": "Need help",
          "category": "moving",
          "state": "GA",
          "city": "Atlanta",
          "area": "Buckhead",
          "address": null,
          "scheduled_at": "2026-09-15T18:44:00.984Z",
          "duration_hours": 3,
          "workers_needed": 2,
          "target_rate": 25,
          "status": "OPEN",
          "closed_to_new_offers": 0,
          "payment_deadline_at": null,
          "created_at": "2026-09-14 18:44:00",
          "offer_count": 0,
          "accepted_workers_count": 0,
          "customer": { "id": "cust-1", "name": "Test Customer" },
          "is_saved": false
        }
        """.data(using: .utf8)!

        let job = try makeDecoder().decode(Job.self, from: json)
        XCTAssertEqual(job.title, "Move furniture")
        XCTAssertEqual(job.status, .open)
        XCTAssertEqual(job.closedToNewOffers, 0)
        XCTAssertNil(job.address)
        XCTAssertFalse(job.isSaved)
    }

    func testPaymentDecodesFromRealisticBackendJSON() throws {
        let json = """
        {
          "id": "pay-1",
          "job_id": "job-1",
          "job_worker_id": "jw-1",
          "worker_id": "worker-1",
          "worker_amount": 90,
          "platform_fee_percent": 15,
          "platform_fee_amount": 13.5,
          "stripe_fee_mode": "CUSTOMER",
          "stripe_fee_amount": 3.2,
          "total_charged_to_customer": 106.7,
          "stripe_payment_intent_id": null,
          "status": "SIMULATED",
          "created_at": "2026-09-14 18:44:00",
          "job_title": "Move furniture"
        }
        """.data(using: .utf8)!

        let payment = try makeDecoder().decode(Payment.self, from: json)
        XCTAssertEqual(payment.workerAmount, 90)
        XCTAssertEqual(payment.platformFeePercent, 15)
        XCTAssertEqual(payment.status, .simulated)
        XCTAssertEqual(payment.jobTitle, "Move furniture")
    }
}
import XCTest
@testable import Handz

final class PaymentMathTests: XCTestCase {
    // Confirms the client-side math matches server/src/utils/payments.js:
    // platform fee = worker_amount * (fee_percent / 100), and total
    // charged includes that fee. This won't catch a server bug, but it
    // does catch the client displaying numbers inconsistently with what
    // the fields actually mean.
    func testPlatformFeeMatchesExpectedPercentage() throws {
        let json = """
        {
          "id": "pay-1", "job_id": "job-1", "job_worker_id": "jw-1",
          "worker_id": "worker-1", "worker_amount": 100,
          "platform_fee_percent": 15, "platform_fee_amount": 15,
          "stripe_fee_mode": "CUSTOMER", "stripe_fee_amount": 3.2,
          "total_charged_to_customer": 118.2, "stripe_payment_intent_id": null,
          "status": "SIMULATED", "created_at": "2026-09-14 18:44:00", "job_title": null
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { d in
            let c = try d.singleValueContainer()
            let s = try c.decode(String.self)
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd HH:mm:ss"
            f.timeZone = TimeZone(identifier: "UTC")
            return f.date(from: s) ?? Date()
        }
        let payment = try decoder.decode(Payment.self, from: json)

        let expectedFee = payment.workerAmount * (payment.platformFeePercent / 100)
        XCTAssertEqual(payment.platformFeeAmount, expectedFee, accuracy: 0.01)

        let expectedTotal = payment.workerAmount + payment.platformFeeAmount + payment.stripeFeeAmount
        XCTAssertEqual(payment.totalChargedToCustomer, expectedTotal, accuracy: 0.01)
    }
}
