import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject private var authSession: AuthSession
    @StateObject private var viewModel: ProfileViewModel

    @State private var showingPhotoPicker = false
    @State private var isBlocked = false
    @State private var showingReport = false
    @FocusState private var bioFocused: Bool

    init(userId: String, userName: String) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(userId: userId, userName: userName))
    }

    private var isOwnProfile: Bool {
        authSession.currentUser?.id == viewModel.userId
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if viewModel.isLoading {
                    HandzLoadingList(count: 2)
                } else if let errorMessage = viewModel.errorMessage {
                    HandzErrorCard(message: errorMessage) {
                        Task { await viewModel.load() }
                    }
                } else {
                    bioSection
                    skillsSection
                    reviewsSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, HandzSpacing.sm)
            .padding(.bottom, HandzSpacing.lg)
        }
        .handzScreenBackground()
        .navigationTitle(viewModel.userName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
            if !isOwnProfile {
                isBlocked = (try? await SafetyRepository.shared.isBlocked(userId: viewModel.userId)) ?? false
            }
        }
        .toolbar {
            if !isOwnProfile {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            Task { await toggleBlock() }
                        } label: {
                            Label(isBlocked ? "Unblock" : "Block", systemImage: "hand.raised")
                        }
                        Button(role: .destructive) {
                            showingReport = true
                        } label: {
                            Label("Report", systemImage: "flag")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20, weight: .semibold))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("More options")
                }
            }
        }
        .sheet(isPresented: $showingReport) {
            ReportUserView(userId: viewModel.userId, userName: viewModel.userName)
        }
    }

    // MARK: - Header: photo, name, rating, reliability

    private var header: some View {
        VStack(spacing: 12) {
            avatarButton
                .handzPhotoPicker(isPresented: $showingPhotoPicker) { photos in
                    guard let data = photos.first, let uiImage = UIImage(data: data) else { return }
                    Task {
                        await viewModel.uploadPhoto(uiImage)
                        await authSession.refreshCurrentUser()
                        await MainActor.run { HandzHaptics.success() }
                    }
                }

            Text(viewModel.userName)
                .font(HandzTypography.title)
                .foregroundColor(HandzColor.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            if viewModel.identityVerified {
                VerifiedBadge()
            }

            ratingLine

            if let reliability = viewModel.reliability {
                VStack(spacing: 4) {
                    HandzChip(text: reliability.shortLabel, icon: "checkmark.shield.fill", kind: .success)
                    Text(reliability.detailLabel)
                        .font(HandzTypography.caption)
                        .foregroundColor(HandzColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            if isBlocked {
                HandzChip(text: "You blocked this person", icon: "hand.raised", kind: .danger)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .cardStyle()
    }

    @ViewBuilder
    private var ratingLine: some View {
        if let averageRating = viewModel.averageRating {
            HStack(spacing: 6) {
                starRow(Int(averageRating.rounded()), size: 14)
                Text(String(format: "%.1f", averageRating))
                    .font(HandzTypography.headline)
                    .foregroundColor(HandzColor.textPrimary)
                Text("· \(viewModel.reviewCount) review\(viewModel.reviewCount == 1 ? "" : "s")")
                    .font(HandzTypography.callout)
                    .foregroundColor(HandzColor.textSecondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Rated \(String(format: "%.1f", averageRating)) out of 5, \(viewModel.reviewCount) reviews")
        } else {
            HandzChip(text: "New on Handz", icon: "sparkles", kind: .info)
        }
    }

    @ViewBuilder
    private var avatarButton: some View {
        if isOwnProfile {
            Button {
                showingPhotoPicker = true
            } label: {
                avatarImage
            }
            .buttonStyle(HandzPressStyle())
            .accessibilityLabel("Change profile photo")
        } else {
            avatarImage
                .accessibilityLabel("\(viewModel.userName)'s photo")
        }
    }

    private var avatarImage: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                if let url = PhotoURL.full(from: viewModel.photoUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        HandzColor.primaryTint
                    }
                } else {
                    Text(initials)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(HandzColor.primaryInk)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(HandzColor.primaryTint)
                }

                if viewModel.isUploadingPhoto {
                    Color.black.opacity(0.45)
                    ProgressView().tint(.white)
                }
            }
            .frame(width: 104, height: 104)
            .clipShape(Circle())

            if isOwnProfile {
                Image(systemName: "camera.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(HandzColor.onFill)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(HandzColor.primary))
                    .overlay(Circle().stroke(HandzColor.surface, lineWidth: 3))
            }
        }
    }

    private var initials: String {
        let letters = viewModel.userName.split(separator: " ").prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    // MARK: - About

    private var bioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("About")
                Spacer()
                if isOwnProfile && !viewModel.isEditingBio {
                    Button("Edit") {
                        withHandzAnimation { viewModel.isEditingBio = true }
                        bioFocused = true
                    }
                    .font(HandzTypography.callout.weight(.semibold))
                    .foregroundColor(HandzColor.primary)
                    .frame(minHeight: 44)
                }
            }

            if viewModel.isEditingBio {
                HandzGrowingTextField("Tell people about yourself, your experience and what you enjoy doing", text: $viewModel.bio, lines: 3...6)
                    .focused($bioFocused)
                    .padding(.vertical, 14)
                    .handzField(isFocused: bioFocused)

                Button {
                    bioFocused = false
                    Task {
                        await viewModel.saveBio()
                        await MainActor.run { HandzHaptics.success() }
                    }
                } label: {
                    if viewModel.isSavingBio {
                        HStack(spacing: 8) {
                            ProgressView().tint(HandzColor.onFill)
                            Text("Saving…")
                        }
                    } else {
                        Text("Save")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.isSavingBio)
            } else if !viewModel.bio.isEmpty {
                Text(viewModel.bio)
                    .font(HandzTypography.body)
                    .foregroundColor(HandzColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if isOwnProfile {
                Text("Add a short bio so people know who they're working with.")
                    .font(HandzTypography.callout)
                    .foregroundColor(HandzColor.textSecondary)
            } else {
                Text("No bio yet.")
                    .font(HandzTypography.callout)
                    .foregroundColor(HandzColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Skills

    private var skillChips: some View {
        ForEach(viewModel.skills) { skill in
            HandzChip(text: skill.displayName, kind: .info)
        }
    }

    @ViewBuilder
    private var skillsSection: some View {
        if !viewModel.skills.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Skills")

                if #available(iOS 16.0, *) {
                    FlowLayout(spacing: 8) {
                        skillChips
                    }
                } else {
                    // iOS 15 can't wrap chips onto new lines, so they scroll sideways.
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            skillChips
                        }
                    }
                }

                if let years = viewModel.yearsExperience {
                    Label("\(years) year\(years == 1 ? "" : "s") of experience", systemImage: "clock")
                        .font(HandzTypography.callout)
                        .foregroundColor(HandzColor.textSecondary)
                }
                if let certs = viewModel.certifications, !certs.isEmpty {
                    Label(certs, systemImage: "checkmark.seal")
                        .font(HandzTypography.callout)
                        .foregroundColor(HandzColor.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
    }

    // MARK: - Reviews

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(viewModel.reviews.isEmpty ? "Reviews" : "Reviews (\(viewModel.reviews.count))")

            if viewModel.reviews.isEmpty {
                Text("No reviews yet. Reviews show up here after finished jobs.")
                    .font(HandzTypography.callout)
                    .foregroundColor(HandzColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
            } else {
                ForEach(viewModel.reviews) { review in
                    reviewRow(review)
                }
            }
        }
    }

    private func reviewRow(_ review: Review) -> some View {
        let name = review.reviewerName ?? "Anonymous"
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(initialsFor(name))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(HandzColor.primaryInk)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(HandzColor.primaryTint))
                    .accessibilityHidden(true)
                Text(name)
                    .font(HandzTypography.headline)
                    .foregroundColor(HandzColor.textPrimary)
                Spacer()
                starRow(review.rating, size: 12)
            }
            if let comment = review.comment, !comment.isEmpty {
                Text(comment)
                    .font(HandzTypography.callout)
                    .foregroundColor(HandzColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(review.rating) out of 5 stars. \(review.comment ?? "")")
    }

    // MARK: - Small pieces

    private func starRow(_ rating: Int, size: CGFloat) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: index < rating ? "star.fill" : "star")
                    .font(.system(size: size, weight: .semibold))
                    .foregroundColor(index < rating ? HandzColor.warning : HandzColor.textFaint)
            }
        }
        .accessibilityHidden(true)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(HandzTypography.sectionTitle)
            .foregroundColor(HandzColor.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    private func initialsFor(_ name: String) -> String {
        let letters = name.split(separator: " ").prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    private func toggleBlock() async {
        do {
            if isBlocked {
                try await SafetyRepository.shared.unblock(userId: viewModel.userId)
            } else {
                try await SafetyRepository.shared.block(userId: viewModel.userId)
            }
            await MainActor.run {
                withHandzAnimation { isBlocked.toggle() }
                HandzHaptics.success()
            }
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }
}

/// Lays chips out in rows, wrapping to the next line when a row is full.
@available(iOS 16.0, *)
private struct FlowLayout: Layout {
    var spacing: CGFloat

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        HandzNavigationStack {
            ProfileView(userId: "preview-id", userName: "Test User")
                .environmentObject(AuthSession.shared)
        }
    }
}
