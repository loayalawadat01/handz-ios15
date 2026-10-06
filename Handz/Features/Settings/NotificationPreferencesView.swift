import SwiftUI

struct NotificationPreferencesView: View {
    @StateObject private var viewModel = NotificationPreferencesViewModel()

    var body: some View {
        Form {
            Section {
                Toggle("Notify me about all categories", isOn: $viewModel.notifyAllCategories)
            } footer: {
                Text("When off, pick specific categories below and you'll only be notified about jobs matching those.")
            }

            if !viewModel.notifyAllCategories {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    ForEach(viewModel.categories) { category in
                        Button {
                            viewModel.toggleCategory(category.id)
                        } label: {
                            HStack {
                                Text(category.name.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .foregroundColor(HandzColor.textPrimary)
                                Spacer()
                                if viewModel.selectedCategoryIds.contains(category.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(HandzColor.primary)
                                }
                            }
                        }
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage).foregroundColor(HandzColor.danger)
            }

            Section {
                Button {
                    Task { await viewModel.save() }
                } label: {
                    if viewModel.isSaving {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Save Preferences").frame(maxWidth: .infinity)
                    }
                }
                .disabled(viewModel.isSaving)
            }
        }
        .navigationTitle("Job Notifications")
        .task { await viewModel.load() }
        .alert(
            viewModel.successMessage ?? "",
            isPresented: Binding(
                get: { viewModel.successMessage != nil },
                set: { if !$0 { viewModel.successMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        }
    }
}

struct NotificationPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { NotificationPreferencesView() }
    }
}
