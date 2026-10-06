import SwiftUI
import PhotosUI

struct SignupView: View {
    @StateObject private var viewModel = SignupViewModel()
    @State private var showingTerms = false
    @State private var showingPhotoPicker = false

    private enum Field: Hashable {
        case name, email, password, phone, experience, certifications
    }

    @FocusState private var focused: Field?
    @State private var touched: Set<Field> = []
    @State private var showAllErrors = false
    @State private var showPassword = false
    @State private var goingForward = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                progressHeader

                stepContent
                    .id(viewModel.step)
                    .transition(stepTransition)
            }
            .padding(.horizontal, 20)
            .padding(.top, HandzSpacing.md)
            .padding(.bottom, HandzSpacing.lg)
        }
        .handzScrollDismissesKeyboard()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar
        }
        .handzScreenBackground()
        .task { await viewModel.loadCategories() }
        .sheet(isPresented: $showingTerms) { TermsView() }
        .sheet(isPresented: $viewModel.showingSkillPicker) {
            CategoryPickerView(
                categories: viewModel.categories,
                singleSelection: .constant(nil),
                multiSelection: $viewModel.skills
            )
        }
        .handzPhotoPicker(isPresented: $showingPhotoPicker) { photos in
            if let data = photos.first, let image = UIImage(data: data) {
                withHandzAnimation(HandzMotion.bouncy) { viewModel.photo = image }
            }
        }
        .onChange(of: focused) { [focused] _ in
            // When you leave a field, start checking it
            if let left = focused { touched.insert(left) }
        }
    }

    // MARK: - Header with step bar

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HandzStepBar(current: viewModel.step.rawValue, total: viewModel.totalSteps)
            Text("Step \(viewModel.step.rawValue) of \(viewModel.totalSteps)")
                .font(HandzTypography.captionBold)
                .foregroundColor(HandzColor.textSecondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(stepTitle)
                    .font(HandzTypography.largeTitle)
                    .foregroundColor(HandzColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(stepSubtitle)
                    .font(HandzTypography.callout)
                    .foregroundColor(HandzColor.textSecondary)
            }
            .id(viewModel.step)
            .transition(.opacity)
        }
        .padding(.top, HandzSpacing.sm)
    }

    private var stepTitle: String {
        switch viewModel.step {
        case .account: return "Create your account"
        case .profile: return "About you"
        case .work: return "Your work"
        }
    }

    private var stepSubtitle: String {
        switch viewModel.step {
        case .account: return "Let's start with the basics."
        case .profile: return "This helps people know who they're working with."
        case .work: return "Tell customers what you're good at and where you work."
        }
    }

    /// Next slides the new step in from the right; Back slides it in from the left.
    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: goingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: goingForward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.step {
        case .account: accountStep
        case .profile: profileStep
        case .work: workStep
        }
    }

    // MARK: - Step 1: account

    private var accountStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text("I want to")
                    .font(HandzTypography.captionBold)
                    .foregroundColor(HandzColor.textPrimary)
                HandzChoiceCard(
                    icon: "person.2",
                    title: "Hire workers",
                    subtitle: "Post jobs and pick who helps you",
                    isSelected: viewModel.role == "customer"
                ) {
                    viewModel.role = "customer"
                }
                HandzChoiceCard(
                    icon: "briefcase",
                    title: "Find work",
                    subtitle: "Get notified about jobs near you",
                    isSelected: viewModel.role == "worker"
                ) {
                    viewModel.role = "worker"
                }
            }

            HandzFormField("Full name", error: error(.name)) {
                TextField("Your name", text: $viewModel.name)
                    .textContentType(.name)
                    .focused($focused, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focused = .email }
                    .handzField(isFocused: focused == .name, hasError: error(.name) != nil)
            }

            HandzFormField("Email", error: error(.email)) {
                TextField("name@example.com", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focused = .password }
                    .handzField(isFocused: focused == .email, hasError: error(.email) != nil)
            }

            HandzFormField("Password", hint: "At least 8 characters", error: error(.password)) {
                passwordField
            }
        }
    }

    private var passwordField: some View {
        HStack(spacing: 8) {
            Group {
                if showPassword {
                    TextField("Password", text: $viewModel.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField("Password", text: $viewModel.password)
                }
            }
            .textContentType(.newPassword)
            .focused($focused, equals: .password)
            .submitLabel(.next)
            .onSubmit { nextTapped() }

            Button {
                showPassword.toggle()
            } label: {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .foregroundColor(HandzColor.textSecondary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(showPassword ? "Hide password" : "Show password")
        }
        .handzField(isFocused: focused == .password, hasError: error(.password) != nil)
    }

    // MARK: - Step 2: about you

    private var profileStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            photoPicker

            HandzFormField("Phone number",
                           hint: "Only shared with the person you're working with, once a worker is hired.",
                           error: error(.phone)) {
                TextField("(404) 555-0123", text: $viewModel.phone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .focused($focused, equals: .phone)
                    .handzField(isFocused: focused == .phone, hasError: error(.phone) != nil)
            }

            HandzFormField("State you live in",
                           hint: viewModel.isWorker ? "You'll see jobs in this state." : "So we can match you with workers near you.") {
                Menu {
                    Picker("State", selection: $viewModel.state) {
                        ForEach(USState.all) { state in
                            Text(state.name).tag(state.code)
                        }
                    }
                } label: {
                    HStack {
                        Text(USState.name(for: viewModel.state) ?? "Choose your state")
                            .foregroundColor(viewModel.state.isEmpty ? HandzColor.textFaint : HandzColor.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(HandzColor.textSecondary)
                    }
                    .contentShape(Rectangle())
                }
                .handzField()
                .accessibilityLabel("State you live in")
                .accessibilityValue(USState.name(for: viewModel.state) ?? "Not chosen")
            }

            HandzFormField("Gender (optional)") {
                HStack(spacing: 8) {
                    HandzSelectChip("Male", isSelected: viewModel.gender == "male") { viewModel.gender = "male" }
                    HandzSelectChip("Female", isSelected: viewModel.gender == "female") { viewModel.gender = "female" }
                    HandzSelectChip("Prefer not to say", isSelected: viewModel.gender == "prefer_not_to_say") {
                        viewModel.gender = "prefer_not_to_say"
                    }
                }
            }

            if viewModel.isWorker {
                HandzFormField("Date of birth", hint: "You must be 18 or older. Never shown on your profile.") {
                    HStack {
                        Text("Birthday")
                            .foregroundColor(HandzColor.textPrimary)
                        Spacer()
                        DatePicker(
                            "Date of birth",
                            selection: $viewModel.dateOfBirth,
                            in: ...SignupViewModel.latestAllowedBirthDate,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                    }
                    .handzField()
                }
            }

            if !viewModel.isWorker {
                termsRow
            }
        }
    }

    private var photoPicker: some View {
        VStack(spacing: 10) {
            Button {
                showingPhotoPicker = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let photo = viewModel.photo {
                            Image(uiImage: photo)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 40, weight: .semibold))
                                .foregroundColor(HandzColor.primaryInk)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(HandzColor.primaryTint)
                        }
                    }
                    .frame(width: 112, height: 112)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(photoError != nil ? HandzColor.danger : Color.clear, lineWidth: 2))

                    Image(systemName: "camera.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(HandzColor.onFill)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(HandzColor.primary))
                        .overlay(Circle().stroke(HandzColor.background, lineWidth: 3))
                }
            }
            .accessibilityLabel(viewModel.photo == nil ? "Add a profile photo" : "Change profile photo")

            Text(viewModel.photo == nil
                 ? (viewModel.isWorker ? "Add a photo (required)" : "Add a photo (optional)")
                 : "Looking good! Tap to change")
                .font(HandzTypography.captionBold)
                .foregroundColor(HandzColor.textPrimary)

            if let photoError = photoError {
                Label(photoError, systemImage: "exclamationmark.circle.fill")
                    .font(HandzTypography.caption.weight(.semibold))
                    .foregroundColor(HandzColor.dangerInk)
            } else if viewModel.isWorker {
                Text("Customers want to see who's coming. Use a clear photo of your face.")
                    .font(HandzTypography.caption)
                    .foregroundColor(HandzColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Step 3: your work (workers)

    private var workStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            HandzFormField("What are you good at?", error: skillsError) {
                Button {
                    focused = nil
                    viewModel.showingSkillPicker = true
                } label: {
                    HStack {
                        Text(viewModel.skills.isEmpty ? "Pick your skills" : viewModel.selectedSkillNames)
                            .foregroundColor(viewModel.skills.isEmpty ? HandzColor.textSecondary : HandzColor.textPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(HandzColor.textSecondary)
                            .accessibilityHidden(true)
                    }
                    .padding(.vertical, 6)
                    .handzField(hasError: skillsError != nil)
                }
                .buttonStyle(HandzPressStyle())
            }

            HandzFormField("Years of experience (optional)") {
                TextField("For example, 3", text: $viewModel.yearsExperience)
                    .keyboardType(.numberPad)
                    .focused($focused, equals: .experience)
                    .handzField(isFocused: focused == .experience)
            }

            HandzFormField("Certifications or licenses (optional)") {
                HandzGrowingTextField("For example, licensed electrician", text: $viewModel.certifications, lines: 2...4)
                    .focused($focused, equals: .certifications)
                    .padding(.vertical, 14)
                    .handzField(isFocused: focused == .certifications)
            }

            HandzFormField("Where are you based?",
                           hint: "We use this to send you jobs nearby.",
                           error: homeError) {
                AddressAutocompleteField(placeholder: "Your city or address", text: $viewModel.homeAddress) { resolved in
                    viewModel.homeLatitude = resolved.latitude
                    viewModel.homeLongitude = resolved.longitude
                    if viewModel.state.isEmpty, USState.name(for: resolved.state) != nil {
                        viewModel.state = resolved.state.uppercased()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: HandzRadius.md, style: .continuous)
                        .fill(HandzColor.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: HandzRadius.md, style: .continuous)
                        .stroke(homeError != nil ? HandzColor.danger : HandzColor.textFaint,
                                lineWidth: homeError != nil ? 2 : 1)
                )
            }

            termsRow
        }
    }

    // MARK: - Terms

    private var termsRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HandzCheckbox(isOn: $viewModel.acceptedTerms, hasError: termsError != nil) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("I agree to the Terms of Service")
                        .font(HandzTypography.callout)
                        .foregroundColor(HandzColor.textPrimary)
                    Button("Read the Terms") { showingTerms = true }
                        .font(HandzTypography.callout.weight(.semibold))
                        .foregroundColor(HandzColor.primary)
                        .frame(minHeight: 32)
                }
            }
            if let termsError = termsError {
                Label(termsError, systemImage: "exclamationmark.circle.fill")
                    .font(HandzTypography.caption.weight(.semibold))
                    .foregroundColor(HandzColor.dangerInk)
                    .padding(.leading, 56)
            }
        }
    }

    // MARK: - Bottom buttons

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if let message = bottomMessage {
                Label(message, systemImage: "exclamationmark.circle.fill")
                    .font(HandzTypography.caption.weight(.semibold))
                    .foregroundColor(HandzColor.dangerInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }

            HStack(spacing: 12) {
                if viewModel.step != .account {
                    Button("Back") { backTapped() }
                        .buttonStyle(SecondaryButtonStyle())
                        .frame(maxWidth: 130)
                        .transition(.opacity)
                }

                if viewModel.isLastStep {
                    Button {
                        signUpTapped()
                    } label: {
                        if viewModel.isLoading {
                            HStack(spacing: 8) {
                                ProgressView().tint(HandzColor.onFill)
                                Text("Creating account…")
                            }
                        } else {
                            Text("Create account")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(viewModel.isLoading)
                } else {
                    Button {
                        nextTapped()
                    } label: {
                        Label("Next", systemImage: "arrow.right")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
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
        .animation(HandzMotion.safe(HandzMotion.standard), value: viewModel.step)
    }

    private var bottomMessage: String? {
        if let serverError = viewModel.errorMessage { return serverError }
        if showAllErrors && !(viewModel.isLastStep ? viewModel.canSubmit : viewModel.canGoNext) {
            return "A few details are missing. Check the fields marked in red."
        }
        return nil
    }

    private func nextTapped() {
        focused = nil
        guard viewModel.canGoNext else {
            HandzHaptics.error()
            withHandzAnimation { showAllErrors = true }
            return
        }
        HandzHaptics.tap()
        goingForward = true
        showAllErrors = false
        withHandzAnimation { viewModel.next() }
    }

    private func backTapped() {
        focused = nil
        HandzHaptics.tap()
        goingForward = false
        showAllErrors = false
        withHandzAnimation { viewModel.back() }
    }

    private func signUpTapped() {
        focused = nil
        guard viewModel.canSubmit else {
            HandzHaptics.error()
            withHandzAnimation { showAllErrors = true }
            return
        }
        HandzHaptics.press()
        Task { await viewModel.signUp() }
    }

    // MARK: - Checking the fields

    /// Errors show once you've left a field, or after you tap Next.
    private func error(_ field: Field) -> String? {
        guard showAllErrors || touched.contains(field) else { return nil }
        switch field {
        case .name:
            return viewModel.name.handzTrimmed.isEmpty ? "Enter your name" : nil
        case .email:
            let email = viewModel.email.handzTrimmed
            return (email.contains("@") && email.contains(".")) ? nil : "Enter a valid email, like name@example.com"
        case .password:
            return viewModel.password.count >= 8 ? nil : "Use at least 8 characters"
        case .phone:
            let digits = viewModel.phone.filter(\.isNumber)
            return digits.count >= 10 ? nil : "Enter your 10-digit phone number"
        default:
            return nil
        }
    }

    private var photoError: String? {
        guard showAllErrors, viewModel.isWorker, viewModel.photo == nil else { return nil }
        return "Add a clear photo of your face"
    }

    private var skillsError: String? {
        guard showAllErrors, viewModel.skills.isEmpty else { return nil }
        return "Pick at least one skill"
    }

    private var homeError: String? {
        guard showAllErrors, viewModel.homeAddress.handzTrimmed.isEmpty else { return nil }
        return "Enter where you're based"
    }

    private var termsError: String? {
        guard showAllErrors, !viewModel.acceptedTerms else { return nil }
        return "Please accept the Terms to continue"
    }
}

struct SignupView_Previews: PreviewProvider {
    static var previews: some View {
        SignupView()
    }
}
