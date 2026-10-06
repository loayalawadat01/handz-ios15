import SwiftUI

struct SavedJobsView: View {
    @State private var jobs: [Job] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: HandzSpacing.md) {
                if isLoading {
                    ProgressView().padding(.top, HandzSpacing.xl)
                } else if let errorMessage {
                    Text(errorMessage).foregroundColor(HandzColor.danger)
                } else if jobs.isEmpty {
                    Text("No saved jobs yet. Tap the bookmark icon on any job to save it.")
                        .foregroundColor(HandzColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, HandzSpacing.xl)
                        .padding(.horizontal, HandzSpacing.lg)
                } else {
                    ForEach(jobs) { job in
                        NavigationLink(destination: JobDetailView(jobId: job.id)) {
                            JobCardView(job: job, onToggleSave: {
                                Task { await toggleSave(job) }
                            })
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, HandzSpacing.lg)
                    }
                }
            }
            .padding(.top, HandzSpacing.md)
        }
        .navigationTitle("Saved Jobs")
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        do {
            jobs = try await JobsRepository.shared.savedJobs()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func toggleSave(_ job: Job) async {
        do {
            try await JobsRepository.shared.unsaveJob(id: job.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct SavedJobsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { SavedJobsView() }
    }
}
