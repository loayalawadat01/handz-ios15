import Foundation

@MainActor
final class PaymentHistoryViewModel: ObservableObject {
    @Published var asWorker: [Payment] = []
    @Published var asCustomer: [Payment] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let paymentsRepository: PaymentsRepository

    init(paymentsRepository: PaymentsRepository = .shared) {
        self.paymentsRepository = paymentsRepository
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await paymentsRepository.myPayments()
            asWorker = response.asWorker
            asCustomer = response.asCustomer
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
