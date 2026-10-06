import SwiftUI

/// "Leave a Review" after a job is complete.
/// Big tappable stars, an optional comment, and a thank-you screen
/// (instead of a pop-up alert) that offers the next person to review.
struct ReviewSubmissionView: View {
    @StateObject private var viewModel: ReviewSubmissionViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var commentFocused: Bool

    @State private var hasLoaded = false
    @State private var showThanks = false
    @State private var reviewedName = ""
    @State private var shakes = 0

    init(jobId: String) {
        _viewModel = StateObject(wrappedValue: ReviewSubmissionViewModel(jobId: jobId))
    }

    /// The person being reviewed right now.
    private var current: ReviewPendingCounterpart? { viewModel.pendingReviews.first }

    /// Who is left after the person just reviewed.
    private var nextCounterpart: ReviewPendingCounterpart? {
        viewModel.pendingReviews.first { $0.name != reviewedName }
    }

    private var canSubmit: Bool {
        current != nil && viewModel.rating > 0 && !viewModel.isSubmitting
    }

    private var showsSubmitBar: Bool { current != nil && !showThanks }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, HandzSpacing.sm)
            .padding(.bottom, HandzSpacing.lg)
        }
        .handzScrollDismissesKeyboard()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsSubmitBar {
                submitBar
            }
        }
        .overlay {
            if showThanks {
                ReviewThanks(
                    name: reviewedName,
                    nextName: nextCounterpart?.name,
                    onNext: reviewNext,
                    onDone: { dismiss() }
                )
                .transition(.opacity)
            }
        }
        .handzScreenBackground()
        .navigationTitle("Leave a Review")
        .navigationBarTitleDisplayMode(.inline)
        .hidesHandzTabBar()
        .task { await initialLoad() }
    }

    // MARK: - Screen content

    @ViewBuilder
    private var content: some View {
        if !hasLoaded && viewModel.pendingReviews.isEmpty {
            HandzLoadingList(count: 2)
        } else if let counterpart = current {
            reviewForm(for: counterpart)
        } else if let errorMessage = viewModel.errorMessage {
            HandzErrorCard(message: errorMessage) {
                Task { await viewModel.load() }
            }
        } else {
            HandzEmptyState(
                icon: "star",
                title: "All reviewed",
                message: "You've reviewed everyone from this job. Thanks for helping keep Handz friendly.",
                actionTitle: "Done"
            ) {
                dismiss()
            }
        }
    }

    private func reviewForm(for counterpart: ReviewPendingCounterpart) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            ratingCard(for: counterpart)

            HandzFormField("Tell others more (optional)",
                           hint: "What went well? Anything they could do better?") {
                HandzGrowingTextField("Write a short review", text: $viewModel.comment, lines: 3...6)
                    .focused($commentFocused)
                    .padding(.vertical, 14)
                    .handzField(isFocused: commentFocused)
            }

            Label("Your review shows on their profile.", systemImage: "person.crop.circle")
                .font(HandzTypography.caption)
                .foregroundColor(HandzColor.textSecondary)
        }
        .id(counterpart.name)
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .opacity))
    }

    // MARK: - Who + stars

    private func ratingCard(for counterpart: ReviewPendingCounterpart) -> some View {
        VStack(spacing: 12) {
            Text(initials(of: counterpart.name))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(HandzColor.primaryInk)
                .frame(width: 72, height: 72)
                .background(Circle().fill(HandzColor.primaryTint))
                .accessibilityHidden(true)

            Text("How was it working with \(counterpart.name)?")
                .font(HandzTypography.sectionTitle)
                .foregroundColor(HandzColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if viewModel.pendingReviews.count > 1 {
                HandzChip(text: "\(viewModel.pendingReviews.count) people to review",
                          icon: "person.2", kind: .info)
            }

            StarRatingPicker(rating: $viewModel.rating)
                .padding(.top, 4)

            Text(ratingWord)
                .font(HandzTypography.callout.weight(.semibold))
                .foregroundColor(viewModel.rating == 0 ? HandzColor.textSecondary : HandzColor.warningInk)
                .animation(HandzMotion.safe(HandzMotion.quick), value: viewModel.rating)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: 20)
    }

    private var ratingWord: String {
        switch viewModel.rating {
        case 1: return "Poor"
        case 2: return "Not great"
        case 3: return "Okay"
        case 4: return "Good"
        case 5: return "Excellent!"
        default: return "Tap a star to rate"
        }
    }

    private func initials(of name: String) -> String {
        let letters = name.split(separator: " ").prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    // MARK: - Submit (stays at the bottom)

    private var inlineError: String? {
        current == nil ? nil : viewModel.errorMessage
    }

    private var submitBar: some View {
        VStack(spacing: 8) {
            if let message = inlineError {
                Label(message, systemImage: "exclamationmark.circle.fill")
                    .font(HandzTypography.caption.weight(.semibold))
                    .foregroundColor(HandzColor.dangerInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .handzShake(shakes)
            }

            Button(action: submit) {
                if viewModel.isSubmitting {
                    HStack(spacing: 8) {
                        ProgressView().tint(HandzColor.onFill)
                        Text("Sending…")
                    }
                } else {
                    Text(viewModel.rating == 0 ? "Tap a star to rate" : "Submit review")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canSubmit)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(
            HandzColor.background
                .overlay(alignment: .top) { Rectangle().fill(HandzColor.border).frame(height: 1) }
                .ignoresSafeArea()
        )
    }

    // MARK: - Actions

    @MainActor
    private func initialLoad() async {
        await viewModel.load()
        hasLoaded = true
    }

    private func submit() {
        guard let counterpart = current, canSubmit else { return }
        commentFocused = false
        HandzHaptics.press()
        reviewedName = counterpart.name
        viewModel.successMessage = nil
        viewModel.errorMessage = nil
        Task { await send(counterpart) }
    }

    @MainActor
    private func send(_ counterpart: ReviewPendingCounterpart) async {
        await viewModel.submitReview(for: counterpart)

        if viewModel.successMessage != nil {
            HandzHaptics.success()
            withHandzAnimation(HandzMotion.standard) { showThanks = true }
            // Refresh who is still left to review.
            await viewModel.load()
        } else {
            HandzHaptics.error()
            withHandzAnimation(HandzMotion.quick) { shakes += 1 }
        }
    }

    private func reviewNext() {
        HandzHaptics.tap()
        viewModel.rating = 0
        viewModel.comment = ""
        viewModel.successMessage = nil
        withHandzAnimation(HandzMotion.standard) { showThanks = false }
    }
}

// MARK: - Five big stars

/// Tap a star to rate. Each star is 52pt so it's easy to hit, pops a little
/// when tapped, and VoiceOver users can swipe up/down to change the rating.
private struct StarRatingPicker: View {
    @Binding var rating: Int
    @State private var popped: Int?

    init(rating: Binding<Int>) {
        self._rating = rating
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { star in
                starButton(star)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rating")
        .accessibilityValue(rating == 0 ? "Not rated" : "\(rating) of 5 stars")
        .accessibilityHint("Swipe up or down to change the rating.")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: choose(min(rating + 1, 5))
            case .decrement: choose(max(rating - 1, 1))
            @unknown default: break
            }
        }
    }

    private func starButton(_ star: Int) -> some View {
        let isOn = star <= rating
        return Button {
            choose(star)
        } label: {
            Image(systemName: isOn ? "star.fill" : "star")
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(isOn ? HandzColor.warning : HandzColor.textFaint)
                .scaleEffect(popped == star ? 1.3 : 1)
                .frame(width: 52, height: 52)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func choose(_ star: Int) {
        HandzHaptics.select()
        withHandzAnimation(HandzMotion.bouncy) {
            rating = star
            popped = star
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withHandzAnimation(HandzMotion.bouncy) {
                if popped == star { popped = nil }
            }
        }
    }
}

// MARK: - Thank-you screen (replaces the old alert)

private struct ReviewThanks: View {
    let name: String
    let nextName: String?
    let onNext: () -> Void
    let onDone: () -> Void
    @State private var shown = false

    init(name: String, nextName: String?, onNext: @escaping () -> Void, onDone: @escaping () -> Void) {
        self.name = name
        self.nextName = nextName
        self.onNext = onNext
        self.onDone = onDone
    }

    var body: some View {
        ZStack {
            HandzColor.background.ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "star.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(HandzColor.onFill)
                    .frame(width: 96, height: 96)
                    .background(Circle().fill(HandzColor.accent))
                    .scaleEffect(shown ? 1 : 0.4)
                    .opacity(shown ? 1 : 0)
                    .accessibilityHidden(true)

                Text("Thanks for your review!")
                    .font(HandzTypography.title)
                    .foregroundColor(HandzColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text("Your review of \(name) was sent. It helps everyone on Handz hire and work with confidence.")
                    .font(HandzTypography.callout)
                    .foregroundColor(HandzColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    if let nextName = nextName {
                        Button("Review \(nextName) next", action: onNext)
                            .buttonStyle(PrimaryButtonStyle())
                        Button("Done for now", action: onDone)
                            .buttonStyle(SecondaryButtonStyle())
                    } else {
                        Button("Done", action: onDone)
                            .buttonStyle(PrimaryButtonStyle())
                    }
                }
                .padding(.top, 8)
            }
            .padding(32)
        }
        .onAppear {
            withHandzAnimation(HandzMotion.bouncy) { shown = true }
        }
    }
}
