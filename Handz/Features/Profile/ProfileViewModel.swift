import Foundation
import UIKit

@MainActor
final class ProfileViewModel: ObservableObject {
    let userId: String
    let userName: String

    @Published var reviews: [Review] = []
    @Published var averageRating: Double?
    @Published var reviewCount: Int = 0
    @Published var bio: String = ""
    @Published var isEditingBio: Bool = false
    @Published var photoUrl: String?
    @Published var skills: [UserSkill] = []
    @Published var yearsExperience: Int?
    @Published var certifications: String?
    @Published var reliability: Reliability?
    @Published var identityVerified = false
    @Published var isUploadingPhoto: Bool = false
    @Published var isLoading: Bool = false
    @Published var isSavingBio: Bool = false
    @Published var errorMessage: String?

    private let reviewsRepository: ReviewsRepository
    private let preferencesRepository: PreferencesRepository

    init(
        userId: String, userName: String,
        reviewsRepository: ReviewsRepository = .shared,
        preferencesRepository: PreferencesRepository = .shared
    ) {
        self.userId = userId
        self.userName = userName
        self.reviewsRepository = reviewsRepository
        self.preferencesRepository = preferencesRepository
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let reviewsResponse = reviewsRepository.reviewsForUser(userId: userId)
            async let profile = preferencesRepository.publicProfile(userId: userId)
            let (r, p) = try await (reviewsResponse, profile)
            reviews = r.reviews
            averageRating = r.averageRating
            reviewCount = r.reviewCount
            bio = p.bio ?? ""
            photoUrl = p.photoUrl
            skills = p.skills ?? []
            yearsExperience = p.yearsExperience
            certifications = p.certifications
            reliability = p.reliability
            identityVerified = p.identityVerified == true
            
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func saveBio() async {
        isSavingBio = true
        do {
            try await preferencesRepository.updateBio(bio)
            isEditingBio = false
        } catch {
            errorMessage = error.localizedDescription
        }
        isSavingBio = false
    }
    func uploadPhoto(_ image: UIImage) async {
        isUploadingPhoto = true
        do {
            let newPath = try await UploadsRepository.shared.uploadProfilePhoto(image)
            photoUrl = newPath
        } catch {
            errorMessage = error.localizedDescription
        }
        isUploadingPhoto = false
    }
}
