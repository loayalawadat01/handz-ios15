import SwiftUI

/// Circular profile photo, falling back to a generic person icon.
/// Used anywhere a person's small photo appears.
struct AvatarView: View {
    let photoPath: String?
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let url = PhotoURL.full(from: photoPath) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color(uiColor: .secondarySystemBackground)
                }
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundColor(HandzColor.primary.opacity(0.6))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

/// Small "Verified" mark next to a worker's name once Stripe confirmed their ID.
struct VerifiedBadge: View {
    var showsText = true

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "checkmark.seal.fill")
                .font(.footnote.weight(.semibold))
            if showsText {
                Text("ID verified")
                    .font(HandzTypography.captionBold)
            }
        }
        .foregroundColor(HandzColor.primary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("ID verified")
    }
}
