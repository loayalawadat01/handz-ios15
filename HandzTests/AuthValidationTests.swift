import XCTest
@testable import Handz

@MainActor
final class AuthValidationTests: XCTestCase {
    func testAccountStepRequiresPasswordAtLeast8Chars() {
        let vm = SignupViewModel()
        vm.name = "Test User"
        vm.email = "test@example.com"
        vm.password = "short"
        XCTAssertFalse(vm.canContinueAccount)

        vm.password = "longenough"
        XCTAssertTrue(vm.canContinueAccount)
    }

    func testCustomerHasTwoStepsWorkerHasThree() {
        let vm = SignupViewModel()
        vm.role = "customer"
        XCTAssertEqual(vm.totalSteps, 2)
        vm.role = "worker"
        XCTAssertEqual(vm.totalSteps, 3)
    }

    func testWorkerMustBe18() {
        let vm = SignupViewModel()
        vm.role = "worker"
        vm.phone = "4045550101"
        vm.photo = UIImage(systemName: "person")
        vm.dateOfBirth = Calendar.current.date(byAdding: .year, value: -16, to: Date())!
        XCTAssertFalse(vm.canContinueProfile, "Under-18 worker should be blocked")

        vm.dateOfBirth = Calendar.current.date(byAdding: .year, value: -25, to: Date())!
        XCTAssertTrue(vm.canContinueProfile)
    }

    func testWorkerPhotoIsRequired() {
        let vm = SignupViewModel()
        vm.role = "worker"
        vm.phone = "4045550101"
        vm.photo = nil
        XCTAssertFalse(vm.canContinueProfile)
    }

    func testLoginRequiresBothFields() {
        let vm = LoginViewModel()
        XCTAssertFalse(vm.canSubmit)
        vm.email = "test@example.com"
        XCTAssertFalse(vm.canSubmit)
        vm.password = "anything"
        XCTAssertTrue(vm.canSubmit)
    }
}
