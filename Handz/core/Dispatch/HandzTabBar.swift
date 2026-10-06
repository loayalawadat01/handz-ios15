//
//  HandzTabBar.swift
//  Handz
//
//  The floating tab bar at the bottom of the app.
//  - White rounded bar (dark in dark mode); each tab shows its icon and name,
//    and the soft highlight slides to the tab you tap, with a light vibration.
//  - Screens scroll behind it, and stop their last row just above it.
//  - It hides itself while the keyboard is open.
//  - A screen can hide it with `.hidesHandzTabBar()` (the chat screen does).
//  - Any screen can switch tabs with `tabBar?.select(.post)`.
//

import SwiftUI
import UIKit

// MARK: - The tabs

enum HandzTab: Hashable {
    case home, findWork, myWork, myJobs, post, messages, account

    var title: String {
        switch self {
        case .home:     return "Home"
        case .findWork: return "Find Work"
        case .myWork:   return "My Work"
        case .myJobs:   return "My Jobs"
        case .post:     return "Post"
        case .messages: return "Messages"
        case .account:  return "Account"
        }
    }

    /// Outline icon when the tab is not selected
    var icon: String {
        switch self {
        case .home:     return "house"
        case .findWork: return "magnifyingglass"
        case .myWork:   return "calendar"
        case .myJobs:   return "briefcase"
        case .post:     return "plus.circle"
        case .messages: return "message"
        case .account:  return "person.crop.circle"
        }
    }

    /// Filled icon when the tab is selected
    var selectedIcon: String {
        switch self {
        case .findWork, .myWork: return icon      // these two have no filled version
        default:                 return icon + ".fill"
        }
    }
}

// MARK: - Shared state (which tab is open, is the bar hidden)

final class HandzTabBarController: ObservableObject {
    @Published var selection: HandzTab = .home
    @Published var isHidden = false {          // a screen asked to hide the bar
        didSet { applyRoomToAll() }
    }
    @Published var keyboardVisible = false {
        didSet { applyRoomToAll() }
    }

    /// Each tab's navigation controller, so the room for the bar can follow it
    /// (shrinks when the keyboard opens or a screen hides the bar).
    private let navigations = NSHashTable<UINavigationController>.weakObjects()

    private var bottomRoom: CGFloat { showsBar ? HandzTabBar.reservedHeight : 0 }

    func register(_ navigation: UINavigationController) {
        navigations.add(navigation)
        applyRoom(to: navigation)
    }

    private func applyRoomToAll() {
        navigations.allObjects.forEach(applyRoom(to:))
    }

    private func applyRoom(to navigation: UINavigationController) {
        if navigation.additionalSafeAreaInsets.bottom != bottomRoom {
            navigation.additionalSafeAreaInsets.bottom = bottomRoom
        }
    }

    private var observers: [NSObjectProtocol] = []

    var showsBar: Bool { !isHidden && !keyboardVisible }

    init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: UIResponder.keyboardWillShowNotification,
                                            object: nil, queue: .main) { [weak self] _ in
            self?.keyboardVisible = true
        })
        observers.append(center.addObserver(forName: UIResponder.keyboardWillHideNotification,
                                            object: nil, queue: .main) { [weak self] _ in
            self?.keyboardVisible = false
        })
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    /// Switch tabs from anywhere, e.g. the "Post a job" button on Home.
    func select(_ tab: HandzTab) {
        guard selection != tab else { return }
        HandzHaptics.tap()
        withHandzAnimation(HandzMotion.standard) { selection = tab }
    }
}

// Lets any screen reach the tab bar through the environment.
// If a screen is shown outside the tab bar (a sheet, say), it simply gets nil — no crash.
private struct HandzTabBarKey: EnvironmentKey {
    static let defaultValue: HandzTabBarController? = nil
}

extension EnvironmentValues {
    var handzTabBar: HandzTabBarController? {
        get { self[HandzTabBarKey.self] }
        set { self[HandzTabBarKey.self] = newValue }
    }
}

// MARK: - Room for the bar on every screen in a tab

/// Put on the first screen of each tab, inside its NavigationStack. It gives
/// that tab's navigation controller extra space at the bottom while the bar
/// shows, and every screen in the tab (including ones opened from it) follows
/// it: lists scroll behind the bar and their last row stops just above it.
struct HandzTabBarRoom: ViewModifier {
    @Environment(\.handzTabBar) var tabBar

    func body(content: Content) -> some View {
        content.background {
            if let tabBar {
                NavigationFinder(controller: tabBar)
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

/// Finds the UINavigationController a screen lives in and hands it to the bar.
private struct NavigationFinder: UIViewControllerRepresentable {
    let controller: HandzTabBarController

    func makeUIViewController(context: Context) -> Finder {
        let finder = Finder()
        finder.controller = controller
        return finder
    }

    func updateUIViewController(_ finder: Finder, context: Context) {
        finder.controller = controller
        finder.registerNavigation()
    }

    final class Finder: UIViewController {
        weak var controller: HandzTabBarController?

        override func loadView() {
            view = UIView()
            view.isUserInteractionEnabled = false
            view.backgroundColor = .clear
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            registerNavigation()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            registerNavigation()
        }

        func registerNavigation() {
            guard let controller, let navigation = findNavigationController() else { return }
            controller.register(navigation)
        }

        private func findNavigationController() -> UINavigationController? {
            if let navigation = navigationController { return navigation }
            var responder: UIResponder? = view
            while let next = responder?.next {
                if let navigation = next as? UINavigationController { return navigation }
                responder = next
            }
            return nil
        }
    }
}

extension View {
    /// Room at the bottom of a tab for the floating bar (see HandzTabBarRoom).
    func handzTabBarRoom() -> some View {
        modifier(HandzTabBarRoom())
    }
}

// MARK: - Hiding the bar on a screen (chat)

struct HidesHandzTabBar: ViewModifier {
    @Environment(\.handzTabBar) var tabBar

    init() {}

    func body(content: Content) -> some View {
        content
            .onAppear { withHandzAnimation(HandzMotion.standard) { tabBar?.isHidden = true } }
            .onDisappear { withHandzAnimation(HandzMotion.standard) { tabBar?.isHidden = false } }
    }
}

extension View {
    func hidesHandzTabBar() -> some View {
        modifier(HidesHandzTabBar())
    }
}

// MARK: - The bar itself
// A white floating bar (dark in dark mode) with a soft shadow, like Uber's.
// Every tab shows its icon with its name under it; the open tab gets a
// soft highlight that slides over when you switch.

struct HandzTabBar: View {
    /// How tall the bar is, including the gap below it. Screens keep this much
    /// room at the bottom so their last row and buttons stop above the bar.
    static let reservedHeight: CGFloat = 62

    let tabs: [HandzTab]
    @Binding var selection: HandzTab
    var onSelect: (HandzTab) -> Void

    @Namespace private var highlight
    @Environment(\.colorScheme) private var colorScheme

    init(tabs: [HandzTab], selection: Binding<HandzTab>, onSelect: @escaping (HandzTab) -> Void) {
        self.tabs = tabs
        self._selection = selection
        self.onSelect = onSelect
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(TabBarColors.bar)
                .shadow(color: HandzColor.shadow.opacity(colorScheme == .dark ? 0 : 0.16),
                        radius: 16, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(TabBarColors.border, lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    private func tabButton(_ tab: HandzTab) -> some View {
        let isSelected = selection == tab
        return Button {
            onSelect(tab)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 16, weight: isSelected ? .bold : .medium))
                    .frame(height: 19)
                Text(tab.title)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundColor(isSelected ? TabBarColors.selectedInk : TabBarColors.icon)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(TabBarColors.selectedFill)
                        .matchedGeometryEffect(id: "highlight", in: highlight)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(HandzPressStyle())
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        // People who use large text can press and hold a tab to see it big.
        .accessibilityShowsLargeContentViewer()
    }
}

// MARK: - Bar colors (light mode / dark mode)

private enum TabBarColors {
    static let bar          = color(light: 0xFFFFFF, dark: 0x1B2925)   // white / raised dark
    static let border       = color(light: 0xE4ECE9, dark: 0x2E403A)   // hairline edge
    static let icon         = color(light: 0x5E726C, dark: 0x9DB3AC)   // tabs that aren't open
    static let selectedFill = color(light: 0xEEF3F1, dark: 0x2A3C37)   // soft grey highlight
    static let selectedInk  = color(light: 0x0B2A24, dark: 0xF2F7F5)   // open tab's icon and name

    private static func color(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255,
                           alpha: 1)
        })
    }
}
