import SwiftUI
import UIKit

struct MainTabView: View {
    @EnvironmentObject private var authSession: AuthSession
    @StateObject private var tabBar = HandzTabBarController()

    private var isWorker: Bool { authSession.currentUser?.role == "worker" }

    init() {
        // Large screen titles in the rounded heading font, teal back buttons
        HandzAppearance.apply()
    }

    private var tabs: [HandzTab] {
        isWorker
            ? [.home, .findWork, .myWork, .messages, .account]
            : [.home, .myJobs, .post, .messages, .account]
    }

    /// Tabs opened so far. A tab's screen is built the first time you open it and
    /// then kept, so it stays where you left it (scroll position, opened job…).
    @State private var openedTabs: Set<HandzTab> = [.home]

    var body: some View {
        ZStack(alignment: .bottom) {
            ForEach(tabs, id: \.self) { tab in
                if openedTabs.contains(tab) {
                    let isOpen = tabBar.selection == tab
                    page(tab)
                        .opacity(isOpen ? 1 : 0)
                        .allowsHitTesting(isOpen)
                        .accessibilityHidden(!isOpen)
                }
            }

            // The bar floats on top. Each tab leaves room for it at the bottom
            // (.handzTabBarRoom()), so screens scroll behind it and their last
            // row and bottom buttons stop just above it.
            if tabBar.showsBar {
                HandzTabBar(tabs: tabs, selection: $tabBar.selection) { tab in
                    tabBar.select(tab)
                }
                // Phones without a home bar (iPhone SE) get a small gap from the bottom edge
                .padding(.bottom, hasHomeIndicator ? 0 : HandzSpacing.sm)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(HandzMotion.safe(HandzMotion.standard), value: tabBar.showsBar)
        .handzScreenBackground()
        .environment(\.handzTabBar, tabBar)
        .onChange(of: tabBar.selection) { tab in
            openedTabs.insert(tab)
        }
        .onChange(of: isWorker) { _ in
            openedTabs = [.home]
            tabBar.selection = .home
        }
    }

    private var hasHomeIndicator: Bool {
        let window = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first
        return (window?.safeAreaInsets.bottom ?? 0) > 0
    }

    @ViewBuilder
    private func page(_ tab: HandzTab) -> some View {
        switch tab {
        case .home:     HomeView() // has its own NavigationStack, with the room inside it
        case .findWork: NavigationStack { BrowseJobsView().handzTabBarRoom() }
        case .myWork:   NavigationStack { MyWorkView().handzTabBarRoom() }
        case .myJobs:   NavigationStack { MyPostedJobsView().handzTabBarRoom() }
        case .post:     NavigationStack { PostJobView().handzTabBarRoom() }
        case .messages: NavigationStack { ConversationListView().handzTabBarRoom() }
        case .account:  NavigationStack { AccountMenuView().handzTabBarRoom() }
        }
    }
}

/// Makes Apple's navigation bars match the Handz look across the app.
enum HandzAppearance {
    private static var applied = false

    static func apply() {
        guard !applied else { return }
        applied = true

        let titleColor = dynamicColor(light: 0x12302A, dark: 0xE6F0EC)
        let background = dynamicColor(light: 0xF2F6F4, dark: 0x0D1613)

        let largeFont = UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: headingFont(size: 32))
        let inlineFont = UIFontMetrics(forTextStyle: .headline).scaledFont(for: headingFont(size: 18))

        // At the top of a screen: no line, same color as the screen
        let atTop = UINavigationBarAppearance()
        atTop.configureWithTransparentBackground()
        atTop.backgroundColor = background
        atTop.largeTitleTextAttributes = [.font: largeFont, .foregroundColor: titleColor]
        atTop.titleTextAttributes = [.font: inlineFont, .foregroundColor: titleColor]

        // After scrolling: Apple's soft blurred bar
        let scrolled = UINavigationBarAppearance()
        scrolled.configureWithDefaultBackground()
        scrolled.largeTitleTextAttributes = [.font: largeFont, .foregroundColor: titleColor]
        scrolled.titleTextAttributes = [.font: inlineFont, .foregroundColor: titleColor]

        let bar = UINavigationBar.appearance()
        bar.scrollEdgeAppearance = atTop
        bar.standardAppearance = scrolled
        bar.compactAppearance = scrolled
        bar.tintColor = dynamicColor(light: 0x0F766E, dark: 0x2BA898)
    }

    /// Varela Round when it's in the app, Apple's rounded font otherwise.
    private static func headingFont(size: CGFloat) -> UIFont {
        if let font = UIFont(name: HandzTypography.headingFontName, size: size) {
            return font
        }
        let base = UIFont.systemFont(ofSize: size, weight: .semibold)
        if let rounded = base.fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: rounded, size: size)
        }
        return base
    }

    private static func dynamicColor(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255,
                           alpha: 1)
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(AuthSession.shared)
    }
}
