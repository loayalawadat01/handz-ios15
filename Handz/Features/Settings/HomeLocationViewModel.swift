import Foundation

@MainActor
final class HomeLocationViewModel: ObservableObject {
    @Published var address: String = ""
    @Published var latitude: Double?
    @Published var longitude: Double?
    @Published var isLoading: Bool = false
    @Published var isSaving: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let repository: PreferencesRepository

    init(repository: PreferencesRepository = .shared) {
        self.repository = repository
    }

    func load() async {
        isLoading = true
        do {
            let response = try await repository.homeLocation()
            address = response.homeAddress ?? ""
            latitude = response.homeLatitude
            longitude = response.homeLongitude
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func save() async {
        isSaving = true
        do {
            try await repository.updateHomeLocation(address: address.isEmpty ? nil : address, latitude: latitude, longitude: longitude)
            successMessage = "Location saved!"
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
