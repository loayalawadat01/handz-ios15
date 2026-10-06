import Foundation

@MainActor
final class NotificationPreferencesViewModel: ObservableObject {
    @Published var notifyAllCategories: Bool = true
    @Published var selectedCategoryIds: Set<String> = []
    @Published var categories: [JobCategory] = []
    @Published var isLoading: Bool = false
    @Published var isSaving: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let preferencesRepository: PreferencesRepository
    private let jobsRepository: JobsRepository

    init(
        preferencesRepository: PreferencesRepository = .shared,
        jobsRepository: JobsRepository = .shared
    ) {
        self.preferencesRepository = preferencesRepository
        self.jobsRepository = jobsRepository
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let prefs = preferencesRepository.notificationCategories()
            async let jobsList = jobsRepository.listOpenJobs()
            let (prefsResult, jobsListResult) = try await (prefs, jobsList)
            notifyAllCategories = prefsResult.notifyAllCategories
            selectedCategoryIds = Set(prefsResult.categoryIds)
            categories = jobsListResult.categories
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func toggleCategory(_ id: String) {
        if selectedCategoryIds.contains(id) {
            selectedCategoryIds.remove(id)
        } else {
            selectedCategoryIds.insert(id)
        }
    }

    func save() async {
        isSaving = true
        do {
            try await preferencesRepository.updateNotificationCategories(
                notifyAll: notifyAllCategories,
                categoryIds: Array(selectedCategoryIds)
            )
            successMessage = "Preferences saved!"
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
