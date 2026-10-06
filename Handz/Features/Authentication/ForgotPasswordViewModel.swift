import Foundation

@MainActor
final class ForgotPasswordViewModel: ObservableObject {
    enum Step { case enterEmail, enterCode, done }

    @Published var step: Step = .enterEmail
    @Published var email: String = ""
    @Published var code: String = ""
    @Published var newPassword: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private struct ForgotRequest: Encodable { let email: String }
    private struct ResetRequest: Encodable {
        let email: String
        let code: String
        let new_password: String
    }
    private struct OkResponse: Decodable { let ok: Bool }

    var canSendCode: Bool { !email.isEmpty && !isLoading }
    var canReset: Bool { code.count == 6 && newPassword.count >= 8 && !isLoading }

    func sendCode() async {
        isLoading = true
        errorMessage = nil
        do {
            let _: OkResponse = try await APIClient.shared.request(
                "/auth/forgot-password", method: .post,
                body: ForgotRequest(email: email), requiresAuth: false
            )
            step = .enterCode
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func resetPassword() async {
        isLoading = true
        errorMessage = nil
        do {
            let _: OkResponse = try await APIClient.shared.request(
                "/auth/reset-password", method: .post,
                body: ResetRequest(email: email, code: code, new_password: newPassword),
                requiresAuth: false
            )
            step = .done
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
