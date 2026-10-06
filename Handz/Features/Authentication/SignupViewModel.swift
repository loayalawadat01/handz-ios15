import Foundation
import UIKit

@MainActor
final class SignupViewModel: ObservableObject {
    enum Step: Int { case account = 1, profile = 2, work = 3 }

    @Published var step: Step = .account

    // Step 1: account
    @Published var role: String = "customer"
    @Published var name: String = ""
    @Published var email: String = ""
    @Published var password: String = ""

    // Step 2: profile
    @Published var photo: UIImage?
    @Published var phone: String = ""
    @Published var gender: String = "prefer_not_to_say"
    @Published var state: String = ""      // two letters, e.g. "GA"
    @Published var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()

    // Step 3: work (workers only)
    @Published var skills: Set<String> = []
    @Published var yearsExperience: String = ""
    @Published var certifications: String = ""
    @Published var homeAddress: String = ""
    @Published var homeLatitude: Double?
    @Published var homeLongitude: Double?
    @Published var categories: [JobCategory] = []
    @Published var showingSkillPicker = false

    // Final
    @Published var acceptedTerms = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authSession: AuthSession

    init(authSession: AuthSession = .shared) {
        self.authSession = authSession
    }

    var isWorker: Bool { role == "worker" }
    var totalSteps: Int { isWorker ? 3 : 2 }
    var isLastStep: Bool { step.rawValue == totalSteps }

    var phoneDigits: String { phone.filter { $0.isNumber } }

    var age: Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
    }

    static var latestAllowedBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    }

    var canContinueAccount: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && email.contains("@") && password.count >= 8
    }

    var canContinueProfile: Bool {
        let phoneOK = (10...15).contains(phoneDigits.count) && !state.isEmpty
        if isWorker {
            return phoneOK && photo != nil && age >= 18
        }
        return phoneOK
    }

    var canContinueWork: Bool {
        !skills.isEmpty && !homeAddress.isEmpty && homeLatitude != nil
    }

    var canGoNext: Bool {
        switch step {
        case .account: return canContinueAccount
        case .profile: return canContinueProfile
        case .work: return canContinueWork
        }
    }

    var canSubmit: Bool { isLastStep && canGoNext && acceptedTerms && !isLoading }

    var selectedSkillNames: String {
        let names = categories.filter { skills.contains($0.id) }.map { $0.displayName }
        return names.isEmpty ? "None selected" : names.joined(separator: ", ")
    }

    func next() {
        errorMessage = nil
        if let nextStep = Step(rawValue: step.rawValue + 1), nextStep.rawValue <= totalSteps {
            step = nextStep
        }
    }

    func back() {
        errorMessage = nil
        if let previous = Step(rawValue: step.rawValue - 1) {
            step = previous
        }
    }

    func loadCategories() async {
        guard categories.isEmpty else { return }
        if let response = try? await JobsRepository.shared.listOpenJobs() {
            categories = response.categories
        }
    }

    func signUp() async {
        guard canSubmit else { return }
        isLoading = true
        errorMessage = nil

        let dobFormatter = DateFormatter()
        dobFormatter.locale = Locale(identifier: "en_US_POSIX")
        dobFormatter.dateFormat = "yyyy-MM-dd"

        let body = AuthSession.SignupRequest(
            email: email.trimmingCharacters(in: .whitespaces),
            password: password,
            name: name.trimmingCharacters(in: .whitespaces),
            role: role,
            phone: phoneDigits,
            gender: gender,
            date_of_birth: isWorker ? dobFormatter.string(from: dateOfBirth) : nil,
            skills: isWorker ? Array(skills) : nil,
            years_experience: isWorker ? Int(yearsExperience) : nil,
            certifications: isWorker && !certifications.isEmpty ? certifications : nil,
            home_address: isWorker ? homeAddress : nil,
            home_latitude: isWorker ? homeLatitude : nil,
            home_longitude: isWorker ? homeLongitude : nil,
            accepted_terms: true,
            state: state
        )

        do {
            try await authSession.signUp(body)
            // Account exists and we're logged in -- now upload the photo.
            // If this fails, the account is fine; they can add it from Profile.
            if let photo {
                _ = try? await UploadsRepository.shared.uploadProfilePhoto(photo)
                await authSession.refreshCurrentUser()
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
