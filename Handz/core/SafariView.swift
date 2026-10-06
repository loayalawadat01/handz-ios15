import SwiftUI
import SafariServices

/// In-app browser for Stripe's hosted onboarding pages.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

/// Lets a URL drive a .sheet(item:).
struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
