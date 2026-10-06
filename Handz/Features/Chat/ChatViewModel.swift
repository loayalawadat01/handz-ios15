import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    let otherUserId: String
    let otherUserName: String

    @Published var messages: [Message] = []
    @Published var draftText: String = ""
    @Published var isLoading: Bool = false
    @Published var isSending: Bool = false
    @Published var errorMessage: String?
    /// The message being sent right now, shown faded until the server confirms it.
    @Published var pendingBody: String?

    private let messagesRepository: MessagesRepository

    /// How often the open chat checks for new messages.
    /// Kept at 15s so the app stays under the server's request limit.
    private let refreshInterval: UInt64 = 15_000_000_000

    init(otherUserId: String, otherUserName: String, messagesRepository: MessagesRepository = .shared) {
        self.otherUserId = otherUserId
        self.otherUserName = otherUserName
        self.messagesRepository = messagesRepository
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            messages = try await messagesRepository.messages(withUserId: otherUserId)
            try await messagesRepository.markRead(withUserId: otherUserId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Checks for new messages every few seconds while the chat is open.
    /// Stops by itself when the chat screen closes.
    func keepUpdated() async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(nanoseconds: refreshInterval)
            } catch {
                return
            }
            await refresh()
        }
    }

    private func refresh() async {
        guard !isSending else { return }
        guard let latest = try? await messagesRepository.messages(withUserId: otherUserId) else { return }
        guard latest.count != messages.count || latest.last?.id != messages.last?.id else { return }
        withHandzAnimation { messages = latest }
        try? await messagesRepository.markRead(withUserId: otherUserId)
    }

    func send() async {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        isSending = true
        errorMessage = nil

        // Show the message right away (faded) and clear the box
        withHandzAnimation {
            pendingBody = text
            draftText = ""
        }

        do {
            let message = try await messagesRepository.sendMessage(toUserId: otherUserId, body: text)
            withHandzAnimation {
                pendingBody = nil
                messages.append(message)
            }
        } catch {
            withHandzAnimation { pendingBody = nil }
            draftText = text          // give the text back so nothing is lost
            errorMessage = error.localizedDescription
            HandzHaptics.error()
        }
        isSending = false
    }
}
