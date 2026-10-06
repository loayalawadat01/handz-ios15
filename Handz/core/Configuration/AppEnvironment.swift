import Foundation

/// Centralizes environment-specific configuration (API base URL, etc.)
/// so it's never hardcoded throughout the app. Per spec section 39.
enum AppEnvironment {
    case development
    case staging
    case production

    /// Change this single line to switch environments during
    /// development. Later this can be driven by build configurations
    /// (xcconfig / scheme) instead of a hardcoded case.
    static let current: AppEnvironment = .development

    var apiBaseURL: URL {
        switch self {
        case .development:
            // iOS Simulator can reach your Mac's localhost directly.
            return URL(string: "http://localhost:4000/api/")!
        case .staging:
            return URL(string: "https://staging-api.handz.app/api")!
        case .production:
            return URL(string: "https://api.handz.app/api")!
        }
    }
}
