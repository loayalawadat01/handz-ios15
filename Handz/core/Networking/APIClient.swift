import Foundation

/// Errors the API client can produce. Kept simple and typed so
/// ViewModels can show meaningful messages instead of raw errors.
enum APIError: Error, LocalizedError {
    case invalidURL
    case noConnection
    case unauthorized
    case serverError(message: String)
    case decodingFailed
    case unknown(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Something went wrong. Please try again."
        case .noConnection:
            return "No internet connection. Please check your network and try again."
        case .unauthorized:
            return "Your session has expired. Please log in again."
        case .serverError(let message):
            return message
        case .decodingFailed:
            return "Something went wrong. Please try again."
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }
}

/// Thin, centralized wrapper around URLSession. Every network call in
/// the app goes through this, per spec section 38 -- no raw URLSession
/// calls scattered through Views/ViewModels.
final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let baseURL: URL

    /// Supplies the current auth token for requests that need it.
    /// Set by AuthSession once a user logs in / on app launch.
    var tokenProvider: (() -> String?)?

    private init() {
        self.session = URLSession(configuration: .default)
        self.baseURL = AppEnvironment.current.apiBaseURL
    }

    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case patch = "PATCH"
        case delete = "DELETE"
        case put = "PUT"
    }

    /// Performs a request and decodes the JSON response into `T`.
    /// Pass `requiresAuth: false` for endpoints like signup/login that
    /// don't need a token.
    func request<T: Decodable>(
        _ path: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        // Strip any leading "/" so paths resolve correctly against a base URL
        // that already ends in a trailing slash (URL(string:relativeTo:)
        // otherwise treats a leading "/" as replacing the whole base path).
        let cleanedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard let url = URL(string: cleanedPath, relativeTo: baseURL) else {
            throw APIError.invalidURL
        
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method.rawValue
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresAuth {
            if let token = tokenProvider?() {
                urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }

        if let body {
            do {
                let encoder = JSONEncoder()
                urlRequest.httpBody = try encoder.encode(AnyEncodable(body))
            } catch {
                throw APIError.unknown(underlying: error)
            }
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw APIError.noConnection
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown(underlying: URLError(.badServerResponse))
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let message = (try? JSONDecoder().decode(ServerErrorResponse.self, from: data))?.error
                ?? "Something went wrong. Please try again."
            throw APIError.serverError(message: message)
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)

                // Try strict ISO8601 first (used for client-sent dates like
                // scheduled_at), then fall back to SQLite's datetime('now')
                // format (used for created_at, completed_at, etc.).
                let iso8601Formatter = ISO8601DateFormatter()
                iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = iso8601Formatter.date(from: dateString) {
                    return date
                }

                // Fallback: some ISO8601 strings won't have fractional seconds.
                let iso8601FormatterNoFraction = ISO8601DateFormatter()
                if let date = iso8601FormatterNoFraction.date(from: dateString) {
                    return date
                }
                let sqliteFormatter = DateFormatter()
                sqliteFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                // Fixed locale, so phones set to 12-hour time still read these dates
                sqliteFormatter.locale = Locale(identifier: "en_US_POSIX")
                sqliteFormatter.timeZone = TimeZone(identifier: "UTC")
                if let date = sqliteFormatter.date(from: dateString) {
                    return date
                }

                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unrecognized date format: \(dateString)"
                )
            }
            
           
            
            return try decoder.decode(T.self, from: data)
        } catch {
            print("🔴 DECODE ERROR: \(error)")
            throw APIError.decodingFailed
        }
    }
}

/// Matches the { "error": "..." } shape the backend returns on failure.
private struct ServerErrorResponse: Decodable {
    let error: String
}

/// Type-erasing wrapper so `request(body:)` can accept any Encodable.
private struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void

    init(_ wrapped: Encodable) {
        encodeFunc = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeFunc(encoder)
    }
}
