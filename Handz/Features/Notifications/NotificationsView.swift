import SwiftUI

struct NotificationsView: View {
    @StateObject private var viewModel = NotificationsViewModel()

    private var unread: [AppNotification] { viewModel.notifications.filter { !$0.isRead } }
    private var earlier: [AppNotification] { viewModel.notifications.filter { $0.isRead } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if viewModel.isLoading && viewModel.notifications.isEmpty {
                    HandzLoadingList(count: 4)
                } else if let errorMessage = viewModel.errorMessage, viewModel.notifications.isEmpty {
                    HandzErrorCard(message: errorMessage) {
                        Task { await viewModel.load() }
                    }
                } else if viewModel.notifications.isEmpty {
                    HandzEmptyState(
                        icon: "bell",
                        title: "You're all caught up",
                        message: "Updates about your jobs, payments and messages will show up here."
                    )
                } else {
                    if !unread.isEmpty {
                        group("New", unread)
                    }
                    if !earlier.isEmpty {
                        group("Earlier", earlier)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, HandzSpacing.sm)
            .padding(.bottom, HandzSpacing.lg)
            .animation(HandzMotion.safe(HandzMotion.standard), value: viewModel.notifications.map(\.isRead))
        }
        .handzScreenBackground()
        .navigationTitle("Notifications")
        .toolbar {
            if viewModel.unreadCount > 0 {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Mark all read") {
                        HandzHaptics.tap()
                        Task { await viewModel.markAllRead() }
                    }
                    .font(HandzTypography.callout.weight(.semibold))
                }
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private func group(_ title: String, _ items: [AppNotification]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HandzSectionHeader(title, count: title == "New" ? items.count : nil)
            ForEach(items) { notification in
                Button {
                    guard !notification.isRead else { return }
                    HandzHaptics.select()
                    Task { await viewModel.markRead(notification) }
                } label: {
                    notificationRow(notification)
                }
                .buttonStyle(HandzPressStyle())
            }
        }
    }

    private func notificationRow(_ notification: AppNotification) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: notification.iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(notification.isRead ? HandzColor.textSecondary : HandzColor.primaryInk)
                .frame(width: 40, height: 40)
                .background(Circle().fill(notification.isRead ? HandzColor.background : HandzColor.primaryTint))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(HandzTypography.headline)
                    .foregroundColor(HandzColor.textPrimary)
                    .multilineTextAlignment(.leading)
                if let body = notification.body {
                    Text(body)
                        .font(HandzTypography.callout)
                        .foregroundColor(HandzColor.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Text(notification.createdAt, style: .relative)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(HandzColor.textSecondary)
            }

            Spacer(minLength: 8)

            if !notification.isRead {
                Circle()
                    .fill(HandzColor.primary)
                    .frame(width: 10, height: 10)
                    .padding(.top, 6)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(notification.isRead ? "" : "Unread. ")\(notification.title). \(notification.body ?? "")")
    }
}

struct NotificationsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { NotificationsView() }
    }
}
