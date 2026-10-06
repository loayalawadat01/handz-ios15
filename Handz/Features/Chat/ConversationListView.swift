import SwiftUI

struct ConversationListView: View {
    @StateObject private var viewModel = ConversationListViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, HandzSpacing.sm)
            .padding(.bottom, HandzSpacing.lg)
        }
        .handzScreenBackground()
        .navigationTitle("Messages")
        .task { await viewModel.load() }
        .handzRefreshable { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.conversations.isEmpty {
            loadingRows
        } else if let errorMessage = viewModel.errorMessage, viewModel.conversations.isEmpty {
            HandzErrorCard(message: errorMessage) {
                Task { await viewModel.load() }
            }
        } else if viewModel.conversations.isEmpty {
            HandzEmptyState(
                icon: "bubble.left.and.bubble.right",
                title: "No messages yet",
                message: "Once someone is hired, you can message each other here. Every job you do together stays in one chat."
            )
        } else {
            ForEach(viewModel.conversations) { conversation in
                NavigationLink {
                    ChatView(otherUserId: conversation.otherUserId, otherUserName: conversation.otherUserName)
                } label: {
                    conversationRow(conversation)
                }
                .buttonStyle(HandzPressStyle())
            }
        }
    }

    private func conversationRow(_ conversation: Conversation) -> some View {
        let unread = conversation.unreadCount > 0
        let preview = conversation.lastMessage?.body ?? "No messages yet"
        return HStack(spacing: 12) {
            Text(initials(conversation.otherUserName))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(HandzColor.primaryInk)
                .frame(width: 48, height: 48)
                .background(Circle().fill(HandzColor.primaryTint))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(conversation.otherUserName)
                    .font(HandzTypography.headline)
                    .foregroundColor(HandzColor.textPrimary)
                Text(preview)
                    .font(HandzTypography.callout.weight(unread ? .semibold : .regular))
                    .foregroundColor(unread ? HandzColor.textPrimary : HandzColor.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 8)

            if unread {
                Text("\(conversation.unreadCount)")
                    .font(HandzTypography.captionBold)
                    .foregroundColor(HandzColor.onFill)
                    .padding(.horizontal, 8)
                    .frame(minWidth: 24, minHeight: 24)
                    .background(Capsule().fill(HandzColor.primary))
                    .transition(.scale.combined(with: .opacity))
            }

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundColor(HandzColor.textSecondary)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(conversation.otherUserName)\(unread ? ", \(conversation.unreadCount) unread" : ""). \(preview)")
    }

    private var loadingRows: some View {
        VStack(spacing: 10) {
            ForEach(0..<4, id: \.self) { _ in
                HStack(spacing: 12) {
                    Circle()
                        .fill(HandzColor.border)
                        .frame(width: 48, height: 48)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Marcus Thompson")
                            .font(HandzTypography.headline)
                        Text("See you Saturday at nine")
                            .font(HandzTypography.callout)
                    }
                    Spacer()
                }
                .cardStyle(padding: 14)
            }
        }
        .loadingPlaceholder(true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading messages")
    }

    private func initials(_ name: String) -> String {
        let letters = name.split(separator: " ").prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}

struct ConversationListView_Previews: PreviewProvider {
    static var previews: some View {
        HandzNavigationStack { ConversationListView() }
    }
}
