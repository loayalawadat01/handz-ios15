import Foundation

struct MyOffersResponse: Decodable {
    let offers: [MyOffer]
}

struct SubmitOfferRequest: Encodable {
    let amount: Double
    let message: String?
}

/// Talks to /api/offers.
final class OffersRepository {
    static let shared = OffersRepository()
    private init() {}

    func myOffers() async throws -> [MyOffer] {
        let response: MyOffersResponse = try await APIClient.shared.request("/offers/mine")
        return response.offers
    }

    func submitOffer(jobId: String, amount: Double, message: String?) async throws -> Offer {
        struct Response: Decodable { let offer: Offer }
        let body = SubmitOfferRequest(amount: amount, message: message)
        let response: Response = try await APIClient.shared.request(
            "/offers/jobs/\(jobId)", method: .post, body: body
        )
        return response.offer
    }

    func withdrawOffer(id: String) async throws {
        struct OkResponse: Decodable { let ok: Bool }
        let _: OkResponse = try await APIClient.shared.request(
            "/offers/\(id)/withdraw", method: .patch
        )
    }

    func rejectOffer(id: String) async throws {
        struct OkResponse: Decodable { let ok: Bool }
        let _: OkResponse = try await APIClient.shared.request(
            "/offers/\(id)/reject", method: .patch
        )
    }

    /// Returns the newly created job_worker assignment on success --
    /// this is what lets a customer accept multiple offers on the same
    /// multi-worker job.
    ///
    ///
    func claimSpot(offerId: String) async throws {
        struct OkResponse: Decodable { let ok: Bool }
        let _: OkResponse = try await APIClient.shared.request("/offers/\(offerId)/claim", method: .post)
    }
    
    /// Returns the id of the payment the customer has to confirm with their
    /// bank right away, or nil when nothing more is needed.
    @discardableResult
    func acceptOffer(id: String) async throws -> String? {
        struct AcceptResponse: Decodable {
            let ok: Bool
            let paymentId: String?
            let paymentNeedsConfirmation: Bool?

            enum CodingKeys: String, CodingKey {
                case ok
                case paymentId = "payment_id"
                case paymentNeedsConfirmation = "payment_needs_confirmation"
            }
        }
        let response: AcceptResponse = try await APIClient.shared.request(
            "/offers/\(id)/accept", method: .patch
        )
        return response.paymentNeedsConfirmation == true ? response.paymentId : nil
    }
}
