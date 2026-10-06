import XCTest
@testable import Handz

final class JobStatusTests: XCTestCase {
    func testAllStatusesHaveDisplayLabels() {
        let allStatuses: [JobStatus] = [
            .open, .offerAccepted, .awaitingPayment, .paid, .inProgress,
            .completed, .cancelled, .paymentFailed, .paymentOverdue, .disputed, .expired
        ]
        for status in allStatuses {
            XCTAssertFalse(status.displayLabel.isEmpty, "Status \(status) has an empty display label")
        }
    }

    func testStatusRawValuesMatchBackend() {
        XCTAssertEqual(JobStatus.open.rawValue, "OPEN")
        XCTAssertEqual(JobStatus.offerAccepted.rawValue, "OFFER_ACCEPTED")
        XCTAssertEqual(JobStatus.awaitingPayment.rawValue, "AWAITING_PAYMENT")
        XCTAssertEqual(JobStatus.paid.rawValue, "PAID")
        XCTAssertEqual(JobStatus.inProgress.rawValue, "IN_PROGRESS")
        XCTAssertEqual(JobStatus.completed.rawValue, "COMPLETED")
        XCTAssertEqual(JobStatus.cancelled.rawValue, "CANCELLED")
        XCTAssertEqual(JobStatus.paymentFailed.rawValue, "PAYMENT_FAILED")
        XCTAssertEqual(JobStatus.paymentOverdue.rawValue, "PAYMENT_OVERDUE")
        XCTAssertEqual(JobStatus.disputed.rawValue, "DISPUTED")
        XCTAssertEqual(JobStatus.expired.rawValue, "EXPIRED")
    }
}
