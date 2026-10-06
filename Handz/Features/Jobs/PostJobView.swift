import SwiftUI
import PhotosUI

struct PostJobView: View {
    @StateObject private var viewModel: PostJobViewModel
    @State private var showingPhotoPicker = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.handzTabBar) private var tabBar
    private let isRebook: Bool

    private enum Field: Hashable {
        case title, description, city, area, duration, pay, instructions
    }

    @FocusState private var focused: Field?
    @State private var touched: Set<Field> = []
    @State private var showAllErrors = false

    /// Jobs can be booked up to 7 days ahead (card holds expire after about a week).
    private let bookingDaysAhead = 7

    init(prefill: Job? = nil, requestedWorkerId: String? = nil, requestedWorkerName: String? = nil) {
        _viewModel = StateObject(wrappedValue: PostJobViewModel(
            prefill: prefill, requestedWorkerId: requestedWorkerId, requestedWorkerName: requestedWorkerName
        ))
        isRebook = requestedWorkerId != nil
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    titleHeader
                    if let name = viewModel.requestedWorkerName {
                        requestBanner(name)
                    }
                    detailsCard.id("details")
                    locationCard.id("location")
                    scheduleCard.id("schedule")
                    workersAndPayCard.id("pay")
                    Group {
                        toolsCard
                        photosCard
                        instructionsCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, HandzSpacing.sm)
                .padding(.bottom, HandzSpacing.lg)
            }
            .handzScrollDismissesKeyboard()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                postBar(proxy: proxy)
            }
        }
        .handzScreenBackground()
        .navigationTitle(isRebook ? "Hire Again" : "Post a Job")
        .navigationBarTitleDisplayMode(.inline)
        .overlay { postedOverlay }
        .sheet(isPresented: $viewModel.showingCategoryPicker) {
            CategoryPickerView(categories: viewModel.categories, singleSelection: $viewModel.category)
        }
        .task { await viewModel.loadRateGuidance() }
        .onChange(of: viewModel.category) { _ in
            Task { await viewModel.loadRateGuidance() }
        }
        .onChange(of: viewModel.durationHours) { _ in
            Task { await viewModel.loadRateGuidance() }
        }
        .onChange(of: focused) { [focused] _ in
            // When you leave a field, start checking it
            if let left = focused { touched.insert(left) }
        }
        .handzPhotoPicker(isPresented: $showingPhotoPicker, maxCount: 5) { photos in
            let loaded = photos.compactMap { UIImage(data: $0) }
            guard !loaded.isEmpty else { return }
            withHandzAnimation { viewModel.photos = loaded }
        }
    }

    // MARK: - Header

    private var titleHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(isRebook ? "Book them again" : "What do you need help with?")
                .font(HandzTypography.title)
                .foregroundColor(HandzColor.textPrimary)
            Text("Matching workers nearby get notified as soon as you post.")
                .font(HandzTypography.callout)
                .foregroundColor(HandzColor.textSecondary)
        }
    }

    private func requestBanner(_ name: String) -> some View {
        Label("Requesting \(name). They'll be notified first, and others can still apply. Just pick a new date and time.",
              systemImage: "star.fill")
            .font(HandzTypography.callout.weight(.semibold))
            .foregroundColor(HandzColor.accentInk)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: HandzRadius.md, style: .continuous)
                    .fill(HandzColor.accentTint)
            )
    }

    // MARK: - Job details

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            cardTitle("Job details", icon: "doc.text")

            HandzFormField("Title", hint: "Short and clear, like \"Help moving a couch\"", error: error(.title)) {
                TextField("What's the job?", text: $viewModel.title)
                    .focused($focused, equals: .title)
                    .submitLabel(.next)
                    .onSubmit { focused = .description }
                    .handzField(isFocused: focused == .title, hasError: error(.title) != nil)
            }

            HandzFormField("Description", hint: "What needs doing, how big it is, anything heavy or tricky") {
                HandzGrowingTextField("Describe the work", text: $viewModel.description, lines: 3...6)
                    .focused($focused, equals: .description)
                    .padding(.vertical, 14)
                    .handzField(isFocused: focused == .description)
            }

            HandzFormField("Category", error: categoryError) {
                categoryButton
            }
        }
        .cardStyle()
    }

    @ViewBuilder
    private var categoryButton: some View {
        if viewModel.categories.isEmpty && viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 52)
        } else {
            Button {
                focused = nil
                viewModel.showingCategoryPicker = true
            } label: {
                HStack {
                    Text(selectedCategoryName ?? "Pick a category")
                        .foregroundColor(selectedCategoryName == nil ? HandzColor.textSecondary : HandzColor.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(HandzColor.textSecondary)
                        .accessibilityHidden(true)
                }
                .handzField(hasError: categoryError != nil)
            }
            .buttonStyle(HandzPressStyle())
        }
    }

    private var selectedCategoryName: String? {
        viewModel.categories.first(where: { $0.id == viewModel.category })?.displayName
    }

    // MARK: - Location

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            cardTitle("Where", icon: "mappin.and.ellipse")

            HandzFormField("Address", hint: "Only shared with workers you hire", error: addressError) {
                AddressAutocompleteField(placeholder: "Start typing the address", text: $viewModel.address) { resolved in
                    viewModel.latitude = resolved.latitude
                    viewModel.longitude = resolved.longitude
                    if viewModel.city.isEmpty { viewModel.city = resolved.city }
                    viewModel.state = resolved.state
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: HandzRadius.md, style: .continuous)
                        .fill(HandzColor.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: HandzRadius.md, style: .continuous)
                        .stroke(addressError != nil ? HandzColor.danger : HandzColor.textFaint,
                                lineWidth: addressError != nil ? 2 : 1)
                )
            }

            HStack(alignment: .top, spacing: 12) {
                HandzFormField("City", error: error(.city)) {
                    TextField("City", text: $viewModel.city)
                        .textContentType(.addressCity)
                        .focused($focused, equals: .city)
                        .submitLabel(.next)
                        .onSubmit { focused = .area }
                        .handzField(isFocused: focused == .city, hasError: error(.city) != nil)
                }
                HandzFormField("Area (optional)") {
                    TextField("Neighborhood", text: $viewModel.area)
                        .focused($focused, equals: .area)
                        .submitLabel(.next)
                        .onSubmit { focused = .duration }
                        .handzField(isFocused: focused == .area)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - When

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            cardTitle("When", icon: "calendar")

            HStack(spacing: 8) {
                HandzSelectChip("Pick a day & time", isSelected: !viewModel.isFlexibleSchedule) {
                    withHandzAnimation { viewModel.isFlexibleSchedule = false }
                }
                HandzSelectChip("Flexible / ASAP", isSelected: viewModel.isFlexibleSchedule) {
                    withHandzAnimation { viewModel.isFlexibleSchedule = true }
                }
            }

            if !viewModel.isFlexibleSchedule {
                VStack(alignment: .leading, spacing: 12) {
                    HandzDayPicker(selection: $viewModel.scheduledAt, daysAhead: bookingDaysAhead)

                    HStack {
                        Text("Start time")
                            .font(HandzTypography.callout.weight(.semibold))
                            .foregroundColor(HandzColor.textPrimary)
                        Spacer()
                        DatePicker("Start time", selection: $viewModel.scheduledAt, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }
                    .handzField(hasError: timeError != nil)

                    if let timeError = timeError {
                        Label(timeError, systemImage: "exclamationmark.circle.fill")
                            .font(HandzTypography.caption.weight(.semibold))
                            .foregroundColor(HandzColor.dangerInk)
                    } else {
                        Text("You can book up to \(bookingDaysAhead) days ahead.")
                            .font(HandzTypography.caption)
                            .foregroundColor(HandzColor.textSecondary)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Text("Workers will reach out to agree on a time within the next few days.")
                    .font(HandzTypography.caption)
                    .foregroundColor(HandzColor.textSecondary)
                    .transition(.opacity)
            }

            HandzFormField("How long will it take?", hint: "In hours, like 3 or 2.5", error: error(.duration)) {
                HStack {
                    TextField("Hours", text: $viewModel.durationHours)
                        .keyboardType(.decimalPad)
                        .focused($focused, equals: .duration)
                    Text("hours")
                        .foregroundColor(HandzColor.textSecondary)
                }
                .handzField(isFocused: focused == .duration, hasError: error(.duration) != nil)
            }
        }
        .cardStyle()
    }

    // MARK: - Workers & pay

    private var workersAndPayCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            cardTitle("Workers & pay", icon: "person.2")

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Workers needed")
                        .font(HandzTypography.callout.weight(.semibold))
                        .foregroundColor(HandzColor.textPrimary)
                    Text("Up to 20")
                        .font(HandzTypography.caption)
                        .foregroundColor(HandzColor.textSecondary)
                }
                Spacer()
                workerCounter
            }

            HandzFormField("Pay per worker, for the whole job", error: error(.pay)) {
                HStack(spacing: 4) {
                    Text("$")
                        .font(HandzTypography.headline)
                        .foregroundColor(HandzColor.textSecondary)
                    TextField("0", text: $viewModel.targetRate)
                        .keyboardType(.decimalPad)
                        .focused($focused, equals: .pay)
                }
                .handzField(isFocused: focused == .pay, hasError: error(.pay) != nil)
            }

            if viewModel.isRateBelowTypical {
                Label("Below the typical range. Fewer workers may be interested.", systemImage: "exclamationmark.triangle.fill")
                    .font(HandzTypography.caption.weight(.semibold))
                    .foregroundColor(HandzColor.warningInk)
            }

            rateGuidanceBox

            if let total = workersTotal {
                HStack {
                    Text("Workers' total")
                        .foregroundColor(HandzColor.textSecondary)
                    Spacer()
                    Text("\(money(total)) + 7.5% service fee")
                        .fontWeight(.semibold)
                        .foregroundColor(HandzColor.textPrimary)
                }
                .font(HandzTypography.callout)
                .padding(.top, 2)
            }
        }
        .cardStyle()
    }

    private var workerCounter: some View {
        HStack(spacing: 12) {
            counterButton("minus", label: "One less worker", enabled: viewModel.workersNeeded > 1) {
                viewModel.workersNeeded -= 1
            }
            Text("\(viewModel.workersNeeded)")
                .font(.system(.title3, design: .rounded).weight(.bold).monospacedDigit())
                .foregroundColor(HandzColor.textPrimary)
                .frame(minWidth: 28)
                .handzNumericTextTransition()
                .accessibilityLabel("\(viewModel.workersNeeded) workers")
            counterButton("plus", label: "One more worker", enabled: viewModel.workersNeeded < 20) {
                viewModel.workersNeeded += 1
            }
        }
    }

    private func counterButton(_ icon: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            HandzHaptics.select()
            withHandzAnimation(HandzMotion.quick) { action() }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(enabled ? HandzColor.primaryInk : HandzColor.textFaint)
                .frame(width: 44, height: 44)
                .background(Circle().fill(enabled ? HandzColor.primaryTint : HandzColor.background))
        }
        .buttonStyle(HandzPressStyle())
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var rateGuidanceBox: some View {
        if let guidance = viewModel.rateGuidance {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(HandzColor.primaryInk)
                    .accessibilityHidden(true)
                rateGuidanceText(guidance)
                    .font(HandzTypography.caption)
                    .foregroundColor(HandzColor.primaryInk)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: HandzRadius.md, style: .continuous)
                    .fill(HandzColor.primaryTint)
            )
        }
    }

    private func rateGuidanceText(_ guidance: RateGuidance) -> Text {
        let hourly = "$\(Int(guidance.lowHourly))–$\(Int(guidance.highHourly))/hour"
        if let low = guidance.lowTotal, let high = guidance.highTotal, let hours = Double(viewModel.durationHours) {
            return Text("Typical for \(guidance.groupName): \(hourly), about $\(Int(low))–$\(Int(high)) per worker for \(String(format: "%g", hours)) hours.")
        }
        return Text("Typical for \(guidance.groupName): \(hourly). Enter how long it takes to see a total.")
    }

    private var workersTotal: Double? {
        guard let pay = Double(viewModel.targetRate), pay > 0 else { return nil }
        return pay * Double(viewModel.workersNeeded)
    }

    // MARK: - Tools, photos, instructions

    private var toolsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardTitle("What should workers bring?", icon: "wrench.and.screwdriver")
            ForEach(ToolsOption.all, id: \.value) { option in
                HandzRadioRow(option.label, isSelected: viewModel.tools == option.value) {
                    viewModel.tools = option.value
                }
            }
        }
        .cardStyle()
    }

    private var photosCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardTitle("Photos (optional, up to 5)", icon: "photo.on.rectangle")
            Text("Photos help workers understand the job before they apply.")
                .font(HandzTypography.caption)
                .foregroundColor(HandzColor.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Button {
                        showingPhotoPicker = true
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: viewModel.photos.isEmpty ? "plus" : "arrow.triangle.2.circlepath")
                                .font(.system(size: 20, weight: .semibold))
                            Text(viewModel.photos.isEmpty ? "Add" : "Change")
                                .font(HandzTypography.captionBold)
                        }
                        .foregroundColor(HandzColor.primaryInk)
                        .frame(width: 80, height: 80)
                        .background(
                            RoundedRectangle(cornerRadius: HandzRadius.sm, style: .continuous)
                                .fill(HandzColor.primaryTint)
                        )
                    }
                    .accessibilityLabel(viewModel.photos.isEmpty ? "Add photos" : "Change photos")

                    ForEach(viewModel.photos.indices, id: \.self) { index in
                        Image(uiImage: viewModel.photos[index])
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: HandzRadius.sm, style: .continuous))
                            .transition(.scale.combined(with: .opacity))
                            .accessibilityLabel("Photo \(index + 1)")
                    }
                }
            }

            if viewModel.photos.isEmpty && !viewModel.existingPhotoUrls.isEmpty {
                Text("Using \(viewModel.existingPhotoUrls.count) photo(s) from the last job.")
                    .font(HandzTypography.caption)
                    .foregroundColor(HandzColor.textSecondary)
            }
        }
        .cardStyle()
    }

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardTitle("Arrival instructions (optional)", icon: "key")
            HandzFormField("How to get in", hint: "Only shared with workers you hire.") {
                HandzGrowingTextField("Gate code, parking, which door…", text: $viewModel.arrivalInstructions, lines: 2...4)
                    .focused($focused, equals: .instructions)
                    .padding(.vertical, 14)
                    .handzField(isFocused: focused == .instructions)
            }
        }
        .cardStyle()
    }

    // MARK: - Post button (stays at the bottom)

    private func postBar(proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 8) {
            if let message = bottomMessage {
                Label(message, systemImage: "exclamationmark.circle.fill")
                    .font(HandzTypography.caption.weight(.semibold))
                    .foregroundColor(HandzColor.dangerInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }

            Button {
                postTapped(proxy: proxy)
            } label: {
                if viewModel.isSubmitting {
                    HStack(spacing: 8) {
                        ProgressView().tint(HandzColor.onFill)
                        Text("Posting…")
                    }
                } else {
                    Label(isRebook ? "Post & Request" : "Post Job", systemImage: "paperplane.fill")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(viewModel.isSubmitting)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(
            HandzColor.background
                .overlay(alignment: .top) { Rectangle().fill(HandzColor.border).frame(height: 1) }
                .ignoresSafeArea()
        )
        .animation(HandzMotion.safe(HandzMotion.standard), value: bottomMessage)
    }

    private var bottomMessage: String? {
        if let serverError = viewModel.errorMessage { return serverError }
        if showAllErrors && !viewModel.canSubmit { return "A few details are missing. Check the fields marked in red." }
        return nil
    }

    private func postTapped(proxy: ScrollViewProxy) {
        focused = nil
        if viewModel.canSubmit {
            HandzHaptics.press()
            Task { await viewModel.submit() }
        } else {
            HandzHaptics.error()
            withHandzAnimation { showAllErrors = true }
            if let section = firstSectionWithError {
                withHandzAnimation { proxy.scrollTo(section, anchor: .top) }
            }
        }
    }

    private var firstSectionWithError: String? {
        if error(.title) != nil || categoryError != nil { return "details" }
        if addressError != nil || error(.city) != nil { return "location" }
        if timeError != nil || error(.duration) != nil { return "schedule" }
        if error(.pay) != nil { return "pay" }
        return nil
    }

    // MARK: - Checking the fields

    /// Errors show once you've left a field, or after you tap Post.
    private func error(_ field: Field) -> String? {
        guard showAllErrors || touched.contains(field) else { return nil }
        switch field {
        case .title:
            return viewModel.title.handzTrimmed.isEmpty ? "Give your job a short title" : nil
        case .city:
            return viewModel.city.handzTrimmed.isEmpty ? "Enter the city" : nil
        case .duration:
            guard let hours = Double(viewModel.durationHours), hours > 0 else {
                return "Enter how many hours, like 3 or 2.5"
            }
            return nil
        case .pay:
            guard let pay = Double(viewModel.targetRate), pay > 0 else {
                return "Enter the pay for each worker"
            }
            return nil
        default:
            return nil
        }
    }

    private var categoryError: String? {
        guard showAllErrors else { return nil }
        return selectedCategoryName == nil ? "Pick a category so the right workers see it" : nil
    }

    private var addressError: String? {
        guard showAllErrors else { return nil }
        return viewModel.address.handzTrimmed.isEmpty ? "Enter the job address" : nil
    }

    private var timeError: String? {
        guard !viewModel.isFlexibleSchedule else { return nil }
        return viewModel.scheduledAt < Date() ? "That time has passed. Pick a later time." : nil
    }

    // MARK: - Job posted

    @ViewBuilder
    private var postedOverlay: some View {
        if viewModel.showingPostedAlert {
            PostedCelebration(
                onSeeJobs: { finishPosting(goToMyJobs: true) },
                onPostAnother: { finishPosting(goToMyJobs: false) }
            )
            .transition(.opacity)
        }
    }

    private func finishPosting(goToMyJobs: Bool) {
        touched = []
        showAllErrors = false
        withHandzAnimation {
            viewModel.showingPostedAlert = false
            viewModel.reset()
        }
        if isRebook { dismiss() }
        if goToMyJobs { tabBar?.select(.myJobs) }
    }

    // MARK: - Small pieces

    private func cardTitle(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(HandzTypography.sectionTitle)
            .foregroundColor(HandzColor.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    private func money(_ value: Double) -> String {
        value.formatted(.currency(code: "USD"))
    }
}

/// Full-screen "Job posted!" moment: a check pops in with a success vibration.
private struct PostedCelebration: View {
    let onSeeJobs: () -> Void
    let onPostAnother: () -> Void
    @State private var shown = false

    init(onSeeJobs: @escaping () -> Void, onPostAnother: @escaping () -> Void) {
        self.onSeeJobs = onSeeJobs
        self.onPostAnother = onPostAnother
    }

    var body: some View {
        ZStack {
            HandzColor.background.ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(HandzColor.onFill)
                    .frame(width: 96, height: 96)
                    .background(Circle().fill(HandzColor.accent))
                    .scaleEffect(shown ? 1 : 0.4)
                    .opacity(shown ? 1 : 0)
                    .accessibilityHidden(true)

                Text("Job posted!")
                    .font(HandzTypography.title)
                    .foregroundColor(HandzColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Text("Matching workers nearby are being notified. We'll let you know as soon as someone's interested.")
                    .font(HandzTypography.callout)
                    .foregroundColor(HandzColor.textSecondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 10) {
                    Button("See my jobs", action: onSeeJobs)
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Post another job", action: onPostAnother)
                        .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.top, 8)
            }
            .padding(32)
        }
        .onAppear {
            HandzHaptics.success()
            withHandzAnimation(HandzMotion.bouncy) { shown = true }
        }
    }
}

struct PostJobView_Previews: PreviewProvider {
    static var previews: some View {
        HandzNavigationStack { PostJobView() }
    }
}
