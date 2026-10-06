import Foundation

struct Reliability: Codable, Equatable {
    let score: Int?
    let completedJobs: Int
    let lateCancellations: Int

    enum CodingKeys: String, CodingKey {
        case score
        case completedJobs = "completed_jobs"
        case lateCancellations = "late_cancellations"
    }

    var shortLabel: String {
        if let score { return "\(score)% reliable" }
        return "New on Handz"
    }

    var detailLabel: String {
        "\(completedJobs) job\(completedJobs == 1 ? "" : "s") done · \(lateCancellations) late cancellation\(lateCancellations == 1 ? "" : "s")"
    }
}
