import Foundation

@MainActor
final class BrowseJobsViewModel: ObservableObject {
    @Published var jobs: [Job] = []
    @Published var categories: [JobCategory] = []
    @Published var selectedCategory: String?
    @Published var showingCategoryPicker: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let jobsRepository: JobsRepository

    init(jobsRepository: JobsRepository = .shared) {
        self.jobsRepository = jobsRepository
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await jobsRepository.listOpenJobs(category: selectedCategory)
            jobs = response.jobs
            categories = response.categories
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func selectCategory(_ category: String?) {
        selectedCategory = category
        Task { await load() }
    }

    func toggleSave(_ job: Job) async {
        do {
            if job.isSaved {
                try await jobsRepository.unsaveJob(id: job.id)
            } else {
                try await jobsRepository.saveJob(id: job.id)
            }
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
