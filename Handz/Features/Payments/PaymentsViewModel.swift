import Foundation

@MainActor
final class PaymentsViewModel: ObservableObject {
    let jobId: String

    @Published var payments: [Payment] = []
    @Published var stripeLive: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var actionInProgress: Bool = false

    private let paymentsRepository: PaymentsRepository

    init(jobId: String, paymentsRepository: PaymentsRepository = .shared) {
        self.jobId = jobId
        self.paymentsRepository = paymentsRepository
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await paymentsRepository.paymentsForJob(jobId: jobId)
            payments = response.payments
            stripeLive = response.stripeLive
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func confirmPayment(_ payment: Payment) async {
        actionInProgress = true
        do {
            try await paymentsRepository.confirmSimulatedPayment(id: payment.id)
            successMessage = "Payment confirmed!"
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
        actionInProgress = false
    }

    var totalOutstanding: Double {
        payments
            .filter { $0.status != .succeeded }
            .reduce(0) { $0 + $1.totalChargedToCustomer }
    }

    var allPaid: Bool {
        !payments.isEmpty && payments.allSatisfy { $0.status == .succeeded }
    }
}
