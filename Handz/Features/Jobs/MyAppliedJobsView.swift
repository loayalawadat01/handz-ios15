import SwiftUI

struct MyAppliedJobsView: View {
    @State private var offers: [MyOffer] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: HandzSpacing.md) {
                if isLoading {
                    ProgressView().padding(.top, HandzSpacing.xl)
                } else if let errorMessage {
                    Text(errorMessage).foregroundColor(HandzColor.danger)
                } else if offers.isEmpty {
                    Text("You haven't applied to any jobs yet.")
                        .foregroundColor(HandzColor.textSecondary)
                        .padding(.top, HandzSpacing.xl)
                } else {
                    ForEach(offers) { offer in
                        NavigationLink(destination: JobDetailView(jobId: offer.jobId)) {
                            MyOfferCardView(offer: offer)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, HandzSpacing.lg)
                    }
                }
            }
            .padding(.top, HandzSpacing.md)
        }
        .navigationTitle("Jobs You Applied To")
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        do {
            offers = try await OffersRepository.shared.myOffers()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct MyAppliedJobsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { MyAppliedJobsView() }
    }
}
