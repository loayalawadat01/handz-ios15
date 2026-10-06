import SwiftUI
import UIKit

struct ChatView: View {
    @EnvironmentObject private var authSession: AuthSession
    @StateObject private var viewModel: ChatViewModel
    @FocusState private var composerFocused: Bool

    init(otherUserId: String, otherUserName: String) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(otherUserId: otherUserId, otherUserName: otherUserName))
    }

    private var currentUserId: String? { authSession.currentUser?.id }

    private var firstName: String {
        viewModel.otherUserName.split(separator: " ").first.map(String.init) ?? viewModel.otherUserName
    }

    private var canSend: Bool {
        !viewModel.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isSending
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading && viewModel.messages.isEmpty {
                loadingBubbles
            } else if let errorMessage = viewModel.errorMessage, viewModel.messages.isEmpty, viewModel.pendingBody == nil {
                loadError(errorMessage)
            } else if viewModel.messages.isEmpty && viewModel.pendingBody == nil {
                emptyState
            } else {
                messageList
            }

            composer
        }
        .handzScreenBackground()
        .navigationTitle(viewModel.otherUserName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                header
            }
        }
        .hidesHandzTabBar()
        .task {
            await viewModel.load()
            await viewModel.keepUpdated()
        }
    }

    // MARK: - Header (name + link to profile)

    private var header: some View {
        NavigationLink {
            ProfileView(userId: viewModel.otherUserId, userName: viewModel.otherUserName)
        } label: {
            HStack(spacing: 8) {
                Text(initials(viewModel.otherUserName))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(HandzColor.primaryInk)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(HandzColor.primaryTint))
                VStack(alignment: .leading, spacing: 0) {
                    Text(viewModel.otherUserName)
                        .font(HandzTypography.headline)
                        .foregroundColor(HandzColor.textPrimary)
                        .lineLimit(1)
                    Text("View profile")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(HandzColor.primary)
                }
            }
        }
        .accessibilityLabel("\(viewModel.otherUserName), view profile")
    }

    // MARK: - Messages

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(rows) { row in
                        rowView(row)
                            .id(row.id)
                    }

                    if let pending = viewModel.pendingBody {
                        pendingBubble(pending)
                            .id("pending")
                    }

                    Color.clear
                        .frame(height: 8)
                        .id("bottom")
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }
            .handzScrollDismissesKeyboard()
            .onAppear {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
            .onChange(of: viewModel.messages.count) { _ in
                withHandzAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: viewModel.pendingBody) { _ in
                withHandzAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: composerFocused) { focused in
                if focused {
                    withHandzAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
        }
    }

    @ViewBuilder
    private func rowView(_ row: ChatRow) -> some View {
        switch row.kind {
        case .day(let label):
            Text(label)
                .font(HandzTypography.captionBold)
                .foregroundColor(HandzColor.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(HandzColor.surface))
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
        case .message(let message, let isMine, let isFirst, let isLast):
            bubble(message, isMine: isMine, isFirst: isFirst, isLast: isLast)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func bubble(_ message: Message, isMine: Bool, isFirst: Bool, isLast: Bool) -> some View {
        let shape = BubbleShape(isMine: isMine, isFirst: isFirst, isLast: isLast)
        return VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
            Text(message.body)
                .font(HandzTypography.body)
                .foregroundColor(isMine ? HandzColor.onFill : HandzColor.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(shape.fill(isMine ? HandzColor.primary : HandzColor.surface))
                .overlay(shape.stroke(HandzColor.border, lineWidth: isMine ? 0 : 1))
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = message.body
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }

            if isLast {
                Text(message.createdAt, style: .time)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(HandzColor.textSecondary)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
        .padding(isMine ? .leading : .trailing, 56)
        .padding(.top, isFirst ? 6 : 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isMine ? "You" : viewModel.otherUserName): \(message.body), \(message.createdAt.formatted(date: .omitted, time: .shortened))")
    }

    /// The message you just sent, faded until the server confirms it.
    private func pendingBubble(_ body: String) -> some View {
        let shape = BubbleShape(isMine: true, isFirst: true, isLast: true)
        return VStack(alignment: .trailing, spacing: 4) {
            Text(body)
                .font(HandzTypography.body)
                .foregroundColor(HandzColor.onFill)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(shape.fill(HandzColor.primary))
                .opacity(0.6)
            Text("Sending…")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(HandzColor.textSecondary)
                .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.leading, 56)
        .padding(.top, 6)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sending: \(body)")
    }

    // MARK: - Grouping messages by day and by sender

    private struct ChatRow: Identifiable {
        enum Kind {
            case day(String)
            case message(Message, isMine: Bool, isFirst: Bool, isLast: Bool)
        }
        let id: String
        let kind: Kind
    }

    /// Adds a day label ("Today", "Yesterday"…) where the day changes, and groups
    /// messages one person sent within 5 minutes so only the last one shows the time.
    private var rows: [ChatRow] {
        let calendar = Calendar.current
        let all = viewModel.messages
        var result: [ChatRow] = []

        for index in all.indices {
            let message = all[index]
            let previous: Message? = index > 0 ? all[index - 1] : nil
            let next: Message? = index + 1 < all.count ? all[index + 1] : nil

            let newDay = previous.map { !calendar.isDate($0.createdAt, inSameDayAs: message.createdAt) } ?? true
            if newDay {
                let dayStart = calendar.startOfDay(for: message.createdAt)
                result.append(ChatRow(id: "day-\(dayStart.timeIntervalSince1970)", kind: .day(dayLabel(message.createdAt))))
            }

            let joinsPrevious = previous.map { isSameGroup($0, message, calendar) } ?? false
            let joinsNext = next.map { isSameGroup(message, $0, calendar) } ?? false

            result.append(ChatRow(
                id: "m-\(message.id)",
                kind: .message(message,
                               isMine: message.senderId == currentUserId,
                               isFirst: !joinsPrevious,
                               isLast: !joinsNext)
            ))
        }
        return result
    }

    private func isSameGroup(_ earlier: Message, _ later: Message, _ calendar: Calendar) -> Bool {
        earlier.senderId == later.senderId
            && later.createdAt.timeIntervalSince(earlier.createdAt) < 5 * 60
            && calendar.isDate(earlier.createdAt, inSameDayAs: later.createdAt)
    }

    private func dayLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        if let days = calendar.dateComponents([.day], from: date, to: Date()).day, days < 7 {
            return date.formatted(.dateTime.weekday(.wide))
        }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(spacing: 6) {
            if let errorMessage = viewModel.errorMessage, !viewModel.messages.isEmpty {
                Label(errorMessage, systemImage: "exclamationmark.circle")
                    .font(HandzTypography.caption.weight(.semibold))
                    .foregroundColor(HandzColor.dangerInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .transition(.opacity)
            }

            HStack(alignment: .bottom, spacing: 10) {
                HandzGrowingTextField("Message \(firstName)…", text: $viewModel.draftText, lines: 1...5)
                    .focused($composerFocused)
                    .font(HandzTypography.body)
                    .foregroundColor(HandzColor.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(HandzColor.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(composerFocused ? HandzColor.primary : HandzColor.textFaint,
                                    lineWidth: composerFocused ? 2 : 1)
                    )
                    .animation(HandzMotion.quick, value: composerFocused)

                Button {
                    HandzHaptics.tap()
                    Task { await viewModel.send() }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(canSend ? HandzColor.onFill : HandzColor.textSecondary)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(canSend ? HandzColor.primary : HandzColor.border))
                }
                .buttonStyle(HandzPressStyle())
                .disabled(!canSend)
                .accessibilityLabel("Send message")
                .animation(HandzMotion.quick, value: canSend)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(
            HandzColor.background
                .overlay(alignment: .top) { Rectangle().fill(HandzColor.border).frame(height: 1) }
                .ignoresSafeArea()
        )
        .animation(HandzMotion.safe(HandzMotion.standard), value: viewModel.errorMessage)
    }

    // MARK: - Empty, loading and error states

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "hand.wave")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(HandzColor.primaryInk)
                .frame(width: 64, height: 64)
                .background(Circle().fill(HandzColor.primaryTint))
                .accessibilityHidden(true)
            Text("Say hi to \(firstName)")
                .font(HandzTypography.sectionTitle)
                .foregroundColor(HandzColor.textPrimary)
            Text("All your messages with \(firstName) stay here, across every job you do together.")
                .font(HandzTypography.callout)
                .foregroundColor(HandzColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { composerFocused = true }
    }

    private var loadingBubbles: some View {
        VStack(spacing: 10) {
            ForEach(0..<5, id: \.self) { index in
                Text(index % 2 == 0 ? "Hi! Are you still okay for Saturday?" : "Yes, see you at nine")
                    .font(HandzTypography.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(HandzColor.surface)
                    )
                    .frame(maxWidth: .infinity, alignment: index % 2 == 0 ? .leading : .trailing)
            }
            Spacer()
        }
        .padding(12)
        .loadingPlaceholder(true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading messages")
    }

    private func loadError(_ message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Label(message, systemImage: "exclamationmark.triangle")
                .font(HandzTypography.callout)
                .foregroundColor(HandzColor.dangerInk)
                .multilineTextAlignment(.center)
            Button("Try again") { Task { await viewModel.load() } }
                .buttonStyle(SecondaryButtonStyle())
                .frame(maxWidth: 220)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }

    private func initials(_ name: String) -> String {
        let letters = name.split(separator: " ").prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}

// MARK: - Bubble shape
// Round corners everywhere, except a tighter corner where bubbles stack,
// and a small "tail" corner on the last bubble of a group.

private struct BubbleShape: Shape {
    var isMine: Bool
    var isFirst: Bool
    var isLast: Bool

    func path(in rect: CGRect) -> Path {
        let big: CGFloat = 20
        let stacked: CGFloat = 8
        let tail: CGFloat = 4

        let topLeft: CGFloat
        let topRight: CGFloat
        let bottomRight: CGFloat
        let bottomLeft: CGFloat

        if isMine {
            topLeft = big
            bottomLeft = big
            topRight = isFirst ? big : stacked
            bottomRight = isLast ? tail : stacked
        } else {
            topRight = big
            bottomRight = big
            topLeft = isFirst ? big : stacked
            bottomLeft = isLast ? tail : stacked
        }

        let limit = min(rect.width, rect.height) / 2
        let tl = min(topLeft, limit)
        let tr = min(topRight, limit)
        let br = min(bottomRight, limit)
        let bl = min(bottomLeft, limit)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr), radius: tr,
                    startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br), radius: br,
                    startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl), radius: bl,
                    startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl), radius: tl,
                    startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        HandzNavigationStack {
            ChatView(otherUserId: "preview-id", otherUserName: "Preview User")
                .environmentObject(AuthSession.shared)
        }
    }
}
