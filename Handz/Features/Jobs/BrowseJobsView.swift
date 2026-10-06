import SwiftUI

struct BrowseJobsView: View {
    @StateObject private var viewModel = BrowseJobsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Jobs near you that match your skills.")
                    .font(HandzTypography.callout)
                    .foregroundColor(HandzColor.textSecondary)
                    .padding(.horizontal, 20)

                categoryFilterBar
                content
            }
            .padding(.top, HandzSpacing.sm)
            .padding(.bottom, HandzSpacing.lg)
        }
        .handzScreenBackground()
        .navigationTitle("Find Work")
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .sheet(isPresented: $viewModel.showingCategoryPicker) {
            CategoryPickerView(
                categories: viewModel.categories,
                singleSelection: Binding(
                    get: { viewModel.selectedCategory },
                    set: { viewModel.selectCategory($0) }
                )
            )
        }
    }

    // MARK: - Category chips

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                HandzSelectChip("All", isSelected: viewModel.selectedCategory == nil) {
                    viewModel.selectCategory(nil)
                }
                ForEach(viewModel.categories.prefix(8)) { category in
                    HandzSelectChip(category.displayName, isSelected: viewModel.selectedCategory == category.id) {
                        viewModel.selectCategory(category.id)
                    }
                }
                HandzSelectChip("See all", isSelected: false) {
                    viewModel.showingCategoryPicker = true
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 2)
        }
    }

    // MARK: - Jobs

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.jobs.isEmpty {
            HandzLoadingList(count: 4)
                .padding(.horizontal, 20)
        } else if let errorMessage = viewModel.errorMessage, viewModel.jobs.isEmpty {
            HandzErrorCard(message: errorMessage) {
                Task { await viewModel.load() }
            }
            .padding(.horizontal, 20)
        } else if viewModel.jobs.isEmpty {
            emptyState
                .padding(.horizontal, 20)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(viewModel.jobs.count) open job\(viewModel.jobs.count == 1 ? "" : "s")")
                    .font(HandzTypography.captionBold)
                    .foregroundColor(HandzColor.textSecondary)

                ForEach(viewModel.jobs) { job in
                    NavigationLink {
                        JobDetailView(jobId: job.id)
                    } label: {
                        JobCardView(job: job, onToggleSave: {
                            Task { await viewModel.toggleSave(job) }
                        }, forWorker: true)
                    }
                    .buttonStyle(HandzPressStyle())
                }
            }
            .padding(.horizontal, 20)
            .animation(HandzMotion.safe(HandzMotion.standard), value: viewModel.jobs.map(\.id))
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if viewModel.selectedCategory != nil {
            HandzEmptyState(
                icon: "line.3.horizontal.decrease.circle",
                title: "Nothing in this category right now",
                message: "Try all categories, or check back soon.",
                actionTitle: "Show all jobs",
                action: { viewModel.selectCategory(nil) }
            )
        } else {
            HandzEmptyState(
                icon: "magnifyingglass",
                title: "No open jobs right now",
                message: "New jobs near you pop up on your screen as soon as they're posted."
            )
        }
    }
}

struct BrowseJobsView_Previews: PreviewProvider {
    static var previews: some View {
        HandzNavigationStack { BrowseJobsView() }
    }
}
