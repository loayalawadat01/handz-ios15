import XCTest
@testable import Handz

@MainActor
final class PostJobValidationTests: XCTestCase {
    func testCannotSubmitWithoutRequiredFields() {
        let vm = PostJobViewModel()
        XCTAssertFalse(vm.canSubmit)

        vm.title = "Move furniture"
        vm.description = "Need help"
        vm.category = "moving"
        vm.city = "Atlanta"
        vm.address = "123 Main St"
        vm.durationHours = "3"

        XCTAssertTrue(vm.canSubmit)
    }

    func testDurationMustBeValidNumber() {
        let vm = PostJobViewModel()
        vm.title = "Move furniture"
        vm.description = "Need help"
        vm.category = "moving"
        vm.city = "Atlanta"
        vm.address = "123 Main St"
        vm.durationHours = "not a number"

        XCTAssertFalse(vm.canSubmit, "Should not allow submit with non-numeric duration")

        vm.durationHours = "2.5"
        XCTAssertTrue(vm.canSubmit)
    }

    func testWorkersNeededDefaultsToOne() {
        let vm = PostJobViewModel()
        XCTAssertEqual(vm.workersNeeded, 1)
    }
}
