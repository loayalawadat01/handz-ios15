import Foundation

@MainActor
final class ConversationListViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let messagesRepository: MessagesRepository

    init(messagesRepository: MessagesRepository = .shared) {
        self.messagesRepository = messagesRepository
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            conversations = try await messagesRepository.conversations()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
