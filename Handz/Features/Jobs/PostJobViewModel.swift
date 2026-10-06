import Foundation
import UIKit

@MainActor
final class PostJobViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var description: String = ""
    @Published var category: String?
    @Published var city: String = ""
    @Published var state: String = ""   // from the address; the customer's own state if empty
    @Published var area: String = ""
    @Published var address: String = ""
    @Published var latitude: Double?
    @Published var longitude: Double?
    @Published var scheduledAt: Date = Date().addingTimeInterval(86400)
    @Published var isFlexibleSchedule: Bool = false
    @Published var durationHours: String = ""
    @Published var workersNeeded: Int = 1
    @Published var targetRate: String = ""
    @Published var tools: String = "none"
    @Published var arrivalInstructions: String = ""
    @Published var photos: [UIImage] = []

    @Published var categories: [JobCategory] = []
    @Published var showingCategoryPicker: Bool = false
    @Published var isLoading: Bool = false
    @Published var isSubmitting: Bool = false
    @Published var errorMessage: String?
    @Published var createdJob: Job?
    @Published var showingPostedAlert: Bool = false
    
    @Published var rateGuidance: RateGuidance?

    func loadRateGuidance() async {
        guard let category else { rateGuidance = nil; return }
        rateGuidance = try? await jobsRepository.rateGuidance(
            category: category, durationHours: Double(durationHours)
        )
    }

    var isRateBelowTypical: Bool {
        guard let rate = Double(targetRate), let low = rateGuidance?.lowTotal else { return false }
        return rate < low
    }

    // Rebooking
    @Published var requestedWorkerId: String?
    @Published var requestedWorkerName: String?
    @Published var existingPhotoUrls: [String] = []

    private let jobsRepository: JobsRepository

    init(
        jobsRepository: JobsRepository = .shared,
        prefill: Job? = nil,
        requestedWorkerId: String? = nil,
        requestedWorkerName: String? = nil
    ) {
        self.jobsRepository = jobsRepository
        if let job = prefill {
            title = job.title
            description = job.description
            category = job.category
            city = job.city
            state = job.state
            area = job.area ?? ""
            address = job.address ?? ""
            latitude = job.latitude
            longitude = job.longitude
            durationHours = String(format: "%g", job.durationHours)
            workersNeeded = requestedWorkerId == nil ? job.workersNeeded : 1
            targetRate = job.targetRate.map { String(format: "%g", $0) } ?? ""
            tools = job.tools ?? "none"
            arrivalInstructions = job.arrivalInstructions ?? ""
            existingPhotoUrls = job.photos ?? []
        }
        self.requestedWorkerId = requestedWorkerId
        self.requestedWorkerName = requestedWorkerName
        Task {
            await loadCategories()
        }
    }

    var canSubmit: Bool {
        !title.isEmpty && !description.isEmpty && category != nil &&
        !city.isEmpty && !address.isEmpty &&
        Double(durationHours) != nil &&
        Double(targetRate) != nil && (Double(targetRate) ?? 0) > 0 &&
        !isSubmitting
    }

    func loadCategories() async {
        isLoading = true
        do {
            let response = try await jobsRepository.listOpenJobs()
            categories = response.categories
            if category == nil, let first = categories.first {
                category = first.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil

        do {
            var photoUrls: [String] = []
            for photo in photos {
                photoUrls.append(try await UploadsRepository.shared.uploadJobPhoto(photo))
            }
            if photoUrls.isEmpty {
                photoUrls = existingPhotoUrls // reuse photos from the job being rebooked
            }

            let formatter = ISO8601DateFormatter()
            let request = PostJobRequest(
                title: title,
                description: description,
                category: category ?? "",
                city: city,
                area: area.isEmpty ? nil : area,
                address: address,
                state: state.isEmpty ? (AuthSession.shared.currentUser?.state ?? "") : state,
                latitude: latitude,
                longitude: longitude,
                scheduledAt: formatter.string(from: isFlexibleSchedule ? Date() : scheduledAt),
                isFlexibleSchedule: isFlexibleSchedule,
                durationHours: Double(durationHours) ?? 1,
                workersNeeded: workersNeeded,
                targetRate: Double(targetRate),
                arrivalInstructions: arrivalInstructions.isEmpty ? nil : arrivalInstructions,
                tools: tools,
                photoUrls: photoUrls,
                requestedWorkerId: requestedWorkerId
            )

            createdJob = try await jobsRepository.postJob(request)
            showingPostedAlert = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }

    /// Clears the form after a successful post (keeps the category list).
    func reset() {
        title = ""
        description = ""
        category = categories.first?.id
        city = ""
        state = ""
        area = ""
        address = ""
        latitude = nil
        longitude = nil
        scheduledAt = Date().addingTimeInterval(86400)
        isFlexibleSchedule = false
        durationHours = ""
        workersNeeded = 1
        targetRate = ""
        tools = "none"
        arrivalInstructions = ""
        photos = []
        existingPhotoUrls = []
        requestedWorkerId = nil
        requestedWorkerName = nil
        createdJob = nil
        errorMessage = nil
    }
}
