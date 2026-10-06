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

    /// The Handz server running on your Mac while testing (port 4000).
    /// The simulator reaches the Mac as "localhost". A real iPhone can't (to the
    /// phone, localhost is the phone itself), so it uses the Mac's network name,
    /// which a build step puts in the app as HandzMacHost. The iPhone and the Mac
    /// must be on the same Wi-Fi.
    static var developmentServer: String {
        #if targetEnvironment(simulator)
        return "http://localhost:4000"
        #else
        let host = Bundle.main.object(forInfoDictionaryKey: "HandzMacHost") as? String
        return "http://\(host ?? "localhost"):4000"
        #endif
    }

    var apiBaseURL: URL {
        switch self {
        case .development:
            return URL(string: AppEnvironment.developmentServer + "/api/")!
        case .staging:
            return URL(string: "https://staging-api.handz.app/api")!
        case .production:
            return URL(string: "https://api.handz.app/api")!
        }
    }
}
