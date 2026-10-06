import Foundation

enum PhotoURL {
    /// Combines a relative /uploads/... path from the backend with the
    /// current environment's server address (not the /api base, since
    /// uploads are served separately).
    static func full(from relativePath: String?) -> URL? {
        guard let relativePath else { return nil }
        let base: String
        switch AppEnvironment.current {
        case .development: base = "http://localhost:4000"
        case .staging: base = "https://staging-api.handz.app"
        case .production: base = "https://api.handz.app"
        }
        return URL(string: base + relativePath)
    }
}
