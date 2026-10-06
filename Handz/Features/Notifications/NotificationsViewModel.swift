import Foundation

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published var notifications: [AppNotification] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let repository: NotificationsRepository

    init(repository: NotificationsRepository = .shared) {
        self.repository = repository
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await repository.list()
            notifications = response.notifications
            unreadCount = response.unreadCount
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func markRead(_ notification: AppNotification) async {
        guard !notification.isRead else { return }
        do {
            try await repository.markRead(id: notification.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markAllRead() async {
        do {
            try await repository.markAllRead()
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
