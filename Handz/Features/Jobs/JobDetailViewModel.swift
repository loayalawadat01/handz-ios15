import Foundation

@MainActor
final class JobDetailViewModel: ObservableObject {
    let jobId: String

    @Published var job: Job?
    @Published var offers: [Offer] = []
    @Published var workers: [JobWorker] = []
    @Published var disputes: [Dispute] = []
    /// Payments that need the customer to confirm them (card declined or bank approval).
    @Published var paymentsNeedingAction: [Payment] = []
    /// Opens the payment form right after hiring when the bank wants approval.
    @Published var paymentToConfirm: String?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var actionInProgress: Bool = false
    @Published var successMessage: String?

    @Published var offerAmount: String = ""
    @Published var offerMessage: String = ""

    private let jobsRepository: JobsRepository
    private let offersRepository: OffersRepository
    private let jobWorkersRepository: JobWorkersRepository

    init(
        jobId: String,
        jobsRepository: JobsRepository = .shared,
        offersRepository: OffersRepository = .shared,
        jobWorkersRepository: JobWorkersRepository = .shared
    ) {
        self.jobId = jobId
        self.jobsRepository = jobsRepository
        self.offersRepository = offersRepository
        self.jobWorkersRepository = jobWorkersRepository
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await jobsRepository.jobDetail(id: jobId)
            job = response.job
            offers = response.offers
            workers = response.workers
            disputes = (try? await DisputesRepository.shared.disputesForJob(jobId: jobId)) ?? []
            let payments = (try? await PaymentsRepository.shared.paymentsForJob(jobId: jobId))?.payments ?? []
            paymentsNeedingAction = payments.filter(\.needsCustomerAction)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func submitOffer(atRate rate: Double) async {
        actionInProgress = true
        do {
            _ = try await offersRepository.submitOffer(
                jobId: jobId, amount: rate, message: offerMessage.isEmpty ? nil : offerMessage
            )
            offerMessage = ""
            successMessage = "You're on the applicant list!"
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
        actionInProgress = false
    }

    func acceptOffer(_ offer: Offer) async {
        actionInProgress = true
        do {
            let needsConfirming = try await offersRepository.acceptOffer(id: offer.id)
            successMessage = "Worker accepted!"
            await load()
            paymentToConfirm = needsConfirming
        } catch {
            errorMessage = error.localizedDescription
        }
        actionInProgress = false
    }

    func rejectOffer(_ offer: Offer) async {
        actionInProgress = true
        do {
            try await offersRepository.rejectOffer(id: offer.id)
            successMessage = "Offer rejected."
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
        actionInProgress = false
    }
    @Published var showingDisputeSheet: Bool = false

    /// Returns true on success, so the Get Help screen knows to close.
    func raiseIssue(type: String, details: String, againstUserId: String?) async -> Bool {
        actionInProgress = true
        errorMessage = nil
        do {
            let reopened = try await DisputesRepository.shared.raiseDispute(
                jobId: jobId,
                issueType: type,
                details: details.isEmpty ? nil : details,
                againstUserId: againstUserId
            )
            showingDisputeSheet = false
            await load()
            if reopened {
                successMessage = "The worker was removed. Your job is open again, so you can accept another interested worker."
            } else if job?.status == .disputed {
                successMessage = "Reported. The pay is on hold until Handz decides."
            } else {
                successMessage = "Report submitted. Our team will review it."
            }
            actionInProgress = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            actionInProgress = false
            return false
        }
    }
    func withdrawOffer(_ offer: Offer) async {
        actionInProgress = true
        do {
            try await offersRepository.withdrawOffer(id: offer.id)
            successMessage = "Offer withdrawn."
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
        actionInProgress = false
    }
    func markJobComplete() async {
        actionInProgress = true
        do {
            try await jobsRepository.completeJob(id: jobId)
            successMessage = "Job marked complete!"
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
        actionInProgress = false
    }
    
    func closeToOffers() async {
        actionInProgress = true
        do {
            try await jobsRepository.closeJobToOffers(id: jobId)
            successMessage = "Job closed to new offers."
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
        actionInProgress = false
    }
    @Published var showingCancelReasonSheet: Bool = false
    @Published var cancelReason: String = ""

    func cancelJob() async {
        actionInProgress = true
        do {
            try await jobsRepository.cancelJob(id: jobId)
            successMessage = "Job cancelled."
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
        actionInProgress = false
    }

    func cancelJobWithReason() async {
        guard !cancelReason.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        actionInProgress = true
        do {
            try await jobsRepository.cancelJobWithReason(id: jobId, reason: cancelReason)
            successMessage = "Job cancelled."
            cancelReason = ""
            showingCancelReasonSheet = false
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
        actionInProgress = false
    }
    @Published var startFailedAttempts: Int = 0
    @Published var showingStartCodeEntry: Bool = false
    @Published var startCodeInput: String = ""
    @Published var generatedStartCode: String?
    @Published var showingLocationWarning: Bool = false

    private let locationFetcher = CurrentLocationFetcher()

    func startMyAssignment(_ jobWorker: JobWorker) async {
        actionInProgress = true
        errorMessage = nil

        let coordinate = await locationFetcher.fetchOnce()

        do {
            try await jobWorkersRepository.startJobWorker(
                id: jobWorker.id,
                latitude: coordinate?.latitude,
                longitude: coordinate?.longitude,
                startCode: nil
            )
            successMessage = "Job started!"
            startFailedAttempts = 0
            await load()
        } catch let apiError as APIError {
            if case .serverError(let message) = apiError, message.contains("NOT_AT_LOCATION") {
                startFailedAttempts += 1
                showingLocationWarning = true
                if startFailedAttempts >= 3 {
                    showingStartCodeEntry = true
                }
            } else {
                errorMessage = apiError.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        actionInProgress = false
    }
    
    @Published var showingWorkerCancelSheet = false
    @Published var workerCancelReason = ""

    func confirmAttendance(_ jobWorker: JobWorker) async {
        actionInProgress = true
        errorMessage = nil
        do {
            try await jobWorkersRepository.confirmAttendance(id: jobWorker.id)
            successMessage = "Thanks! The customer knows you're coming."
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
        actionInProgress = false
    }

    func cancelMyAssignment(_ jobWorker: JobWorker) async {
        let reason = workerCancelReason.trimmingCharacters(in: .whitespaces)
        guard !reason.isEmpty else { return }
        actionInProgress = true
        errorMessage = nil
        do {
            let late = try await jobWorkersRepository.cancelAssignment(id: jobWorker.id, reason: reason)
            showingWorkerCancelSheet = false
            workerCancelReason = ""
            await load()
            successMessage = late
                ? "You've cancelled. Because it was within 24 hours of the start, it counts against your reliability."
                : "You've cancelled. We're finding the customer a replacement."
        } catch {
            errorMessage = error.localizedDescription
        }
        actionInProgress = false
    }

    func removeWorker(_ jobWorker: JobWorker) async {
        actionInProgress = true
        errorMessage = nil
        do {
            try await jobWorkersRepository.removeWorker(id: jobWorker.id)
            await load()
            successMessage = "Worker removed. You can pick someone else from your applicants."
        } catch {
            errorMessage = error.localizedDescription
        }
        actionInProgress = false
    }

    func claimSpot(_ offer: Offer) async {
        actionInProgress = true
        errorMessage = nil
        do {
            try await offersRepository.claimSpot(offerId: offer.id)
            await load()
            successMessage = "The job is yours!"
        } catch {
            errorMessage = error.localizedDescription
            await load()
        }
        actionInProgress = false
    }
    
    func markOnTheWay(_ jobWorker: JobWorker, etaMinutes: Int) async {
        actionInProgress = true
        errorMessage = nil
        do {
            try await jobWorkersRepository.markOnTheWay(id: jobWorker.id, etaMinutes: etaMinutes)
            successMessage = "The customer knows you're on the way."
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
        actionInProgress = false
    }

    func startWithCode(_ jobWorker: JobWorker) async {
        guard !startCodeInput.isEmpty else { return }
        actionInProgress = true
        errorMessage = nil
        do {
            try await jobWorkersRepository.startJobWorker(
                id: jobWorker.id, latitude: nil, longitude: nil, startCode: startCodeInput
            )
            successMessage = "Job started!"
            showingStartCodeEntry = false
            startCodeInput = ""
            startFailedAttempts = 0
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
        actionInProgress = false
    }

    func generateStartCodeForCustomer(_ jobWorker: JobWorker) async {
        actionInProgress = true
        do {
            let code = try await jobWorkersRepository.generateStartCode(id: jobWorker.id)
            generatedStartCode = code
        } catch {
            errorMessage = error.localizedDescription
        }
        actionInProgress = false
    }

    @Published var showingCompletionCodeEntry: Bool = false
    @Published var completionCodeInput: String = ""
    @Published var generatedCompletionCode: String?

    func completeMyAssignment(_ jobWorker: JobWorker) async {
        actionInProgress = true
        errorMessage = nil
        do {
            let payment = try await jobWorkersRepository.completeJobWorker(id: jobWorker.id)
            successMessage = payment == nil
                ? "Work marked finished. Your pay is on hold until Handz decides."
                : "Work marked complete!"
            await load()
        } catch let apiError as APIError {
            if case .serverError(let message) = apiError, message.contains("TOO_EARLY") {
                errorMessage = "You can't mark this complete yet -- the estimated duration hasn't passed."
            } else {
                errorMessage = apiError.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        actionInProgress = false
    }

    func completeWithCode(_ jobWorker: JobWorker) async {
        guard !completionCodeInput.isEmpty else { return }
        actionInProgress = true
        errorMessage = nil
        do {
            let payment = try await jobWorkersRepository.completeJobWorker(id: jobWorker.id, completionCode: completionCodeInput)
            successMessage = payment == nil
                ? "Work marked finished. Your pay is on hold until Handz decides."
                : "Work marked complete!"
            showingCompletionCodeEntry = false
            completionCodeInput = ""
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
        actionInProgress = false
    }

    func generateCompletionCodeForCustomer(_ jobWorker: JobWorker) async {
        actionInProgress = true
        do {
            let code = try await jobWorkersRepository.generateCompletionCode(id: jobWorker.id)
            generatedCompletionCode = code
        } catch {
            errorMessage = error.localizedDescription
        }
        actionInProgress = false
    }   
}
