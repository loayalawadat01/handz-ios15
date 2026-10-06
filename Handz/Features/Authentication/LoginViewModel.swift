import Foundation

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let authSession: AuthSession

    init(authSession: AuthSession = .shared) {
        self.authSession = authSession
    }

    var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && !isLoading
    }

    func logIn() async {
        guard canSubmit else { return }
        isLoading = true
        errorMessage = nil

        do {
            try await authSession.logIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
