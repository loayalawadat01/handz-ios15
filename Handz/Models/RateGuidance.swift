import Foundation

struct RateGuidance: Decodable, Equatable {
    let groupName: String
    let lowHourly: Double
    let highHourly: Double
    let lowTotal: Double?
    let highTotal: Double?
    let source: String
    let sampleSize: Int

    enum CodingKeys: String, CodingKey {
        case source
        case groupName = "group_name"
        case lowHourly = "low_hourly"
        case highHourly = "high_hourly"
        case lowTotal = "low_total"
        case highTotal = "high_total"
        case sampleSize = "sample_size"
    }
}
