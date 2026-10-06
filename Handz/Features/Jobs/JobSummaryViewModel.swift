import Foundation

@MainActor
final class JobSummaryViewModel: ObservableObject {
    let jobWorkerId: String

    @Published var summary: JobWorkerSummary?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let repository: JobWorkersRepository

    init(jobWorkerId: String, repository: JobWorkersRepository = .shared) {
        self.jobWorkerId = jobWorkerId
        self.repository = repository
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            summary = try await repository.summary(id: jobWorkerId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
