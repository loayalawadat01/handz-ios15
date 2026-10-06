import Foundation

struct NextDispatchResponse: Decodable {
    let job: DispatchJob?
}

final class DispatchRepository {
    static let shared = DispatchRepository()
    private init() {}

    func nextJob() async throws -> DispatchJob? {
        let response: NextDispatchResponse = try await APIClient.shared.request("/dispatch/next")
        return response.job
    }
}
