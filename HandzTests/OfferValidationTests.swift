import XCTest
@testable import Handz

final class OfferValidationTests: XCTestCase {
    func testJobWorkerStatusRawValuesMatchBackend() {
        XCTAssertEqual(JobWorkerStatus.active.rawValue, "ACTIVE")
        XCTAssertEqual(JobWorkerStatus.cancelled.rawValue, "CANCELLED")
        XCTAssertEqual(JobWorkerStatus.completed.rawValue, "COMPLETED")
    }

    func testOfferStatusRawValuesMatchBackend() {
        XCTAssertEqual(OfferStatus.pending.rawValue, "PENDING")
        XCTAssertEqual(OfferStatus.accepted.rawValue, "ACCEPTED")
        XCTAssertEqual(OfferStatus.rejected.rawValue, "REJECTED")
        XCTAssertEqual(OfferStatus.withdrawn.rawValue, "WITHDRAWN")
    }

    func testPaymentStatusRawValuesMatchBackend() {
        XCTAssertEqual(PaymentStatus.pending.rawValue, "PENDING")
        XCTAssertEqual(PaymentStatus.succeeded.rawValue, "SUCCEEDED")
        XCTAssertEqual(PaymentStatus.failed.rawValue, "FAILED")
        XCTAssertEqual(PaymentStatus.simulated.rawValue, "SIMULATED")
    }

    func testStripeFeeModeRawValuesMatchBackend() {
        XCTAssertEqual(StripeFeeMode.customer.rawValue, "CUSTOMER")
        XCTAssertEqual(StripeFeeMode.platform.rawValue, "PLATFORM")
        XCTAssertEqual(StripeFeeMode.included.rawValue, "INCLUDED")
    }
}
