import Foundation
import UIKit

final class UploadsRepository {
    static let shared = UploadsRepository()
    private init() {}

    func uploadProfilePhoto(_ image: UIImage) async throws -> String {
        try await upload(image, to: "uploads/profile-photo")
    }

    func uploadJobPhoto(_ image: UIImage) async throws -> String {
        try await upload(image, to: "uploads/job-photo")
    }

    /// Shrinks large camera photos so uploads stay fast and under the
    /// server's 5MB limit.
    private func resized(_ image: UIImage, maxSide: CGFloat = 1600) -> UIImage {
        let largest = max(image.size.width, image.size.height)
        guard largest > maxSide else { return image }
        let scale = maxSide / largest
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// Multipart upload; bypasses APIClient's JSON-only request().
    private func upload(_ image: UIImage, to path: String) async throws -> String {
        guard let imageData = resized(image).jpegData(compressionQuality: 0.75) else {
            throw APIError.unknown(underlying: NSError(domain: "Handz", code: -1))
        }

        let boundary = UUID().uuidString
        let uploadURL = AppEnvironment.current.apiBaseURL.appendingPathComponent(path)
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = await AuthSession.shared.tokenForRequests {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.serverError(message: "Failed to upload photo.")
        }

        struct Response: Decodable { let photo_url: String }
        return try JSONDecoder().decode(Response.self, from: data).photo_url
    }
}
