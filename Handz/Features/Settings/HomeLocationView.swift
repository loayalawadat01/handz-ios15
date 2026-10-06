import SwiftUI

struct HomeLocationView: View {
    @StateObject private var viewModel = HomeLocationViewModel()
    @Environment(\.dismiss) private var dismiss
    var isOnboarding: Bool = false

    var body: some View {
        VStack(spacing: HandzSpacing.lg) {
            VStack(spacing: HandzSpacing.sm) {
                Text("Where are you based?")
                    .font(HandzTypography.title)
                Text("This helps us show you nearby jobs.")
                    .font(HandzTypography.body)
                    .foregroundColor(HandzColor.textSecondary)
            }
            .padding(.top, HandzSpacing.xl)

            AddressAutocompleteField(placeholder: "Your city or address", text: $viewModel.address) { resolved in
                viewModel.latitude = resolved.latitude
                viewModel.longitude = resolved.longitude
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage).foregroundColor(HandzColor.danger)
            }

            Button {
                Task {
                    await viewModel.save()
                    if viewModel.errorMessage == nil {
                        dismiss()
                    }
                }
            } label: {
                if viewModel.isSaving {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text("Save").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(viewModel.address.isEmpty || viewModel.isSaving)

            if isOnboarding {
                Button("Skip for now") {
                    dismiss()
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            Spacer()
        }
        .padding(HandzSpacing.lg)
        .task { await viewModel.load() }
    }
}

struct HomeLocationView_Previews: PreviewProvider {
    static var previews: some View {
        HomeLocationView()
    }
}
