import SwiftUI

/// Shows the current Terms of Service, loaded from the server so the
/// text can be updated without releasing a new app version.
struct TermsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @State private var version: String = ""
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView().padding(.top, HandzSpacing.xl)
                } else if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(HandzColor.danger)
                        .padding()
                } else {
                    VStack(alignment: .leading, spacing: HandzSpacing.md) {
                        Text(text)
                            .font(HandzTypography.body)
                        Text("Version \(version)")
                            .font(HandzTypography.caption)
                            .foregroundColor(HandzColor.textSecondary)
                    }
                    .padding(HandzSpacing.lg)
                }
            }
            .navigationTitle("Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        struct Response: Decodable { let version: String; let text: String }
        do {
            let response: Response = try await APIClient.shared.request("/auth/terms", requiresAuth: false)
            text = response.text
            version = response.version
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
