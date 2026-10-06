//
//  iOS15Support.swift
//  Handz
//
//  This copy of Handz runs on iOS 15 (for example an iPhone 7).
//  Each piece below uses the iOS 16 feature when the phone has it, and a
//  simpler iOS 15 version when it doesn't. Screens use these instead of the
//  iOS 16 features directly.
//

import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Moving between screens

/// NavigationStack on iOS 16 and newer; NavigationView (one screen at a time) on iOS 15.
struct HandzNavigationStack<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack { content }
        } else {
            NavigationView { content }
                .navigationViewStyle(.stack)
        }
    }
}

private struct HandzNavigationDestination<Destination: View>: ViewModifier {
    @Binding var isPresented: Bool
    let destination: () -> Destination

    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.navigationDestination(isPresented: $isPresented, destination: destination)
        } else {
            content.background(
                NavigationLink(isActive: $isPresented, destination: destination) { EmptyView() }
                    .hidden()
            )
        }
    }
}

extension View {
    /// Opens `destination` as the next screen while `isPresented` is true.
    func handzNavigationDestination<Destination: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        modifier(HandzNavigationDestination(isPresented: isPresented, destination: destination))
    }

    /// Hides the top bar on this screen.
    @ViewBuilder
    func handzHideNavigationBar() -> some View {
        if #available(iOS 16.0, *) {
            toolbar(.hidden, for: .navigationBar)
        } else {
            navigationBarHidden(true)
        }
    }

    /// Lets a swipe down on the page put the keyboard away (iOS 16 and newer).
    @ViewBuilder
    func handzScrollDismissesKeyboard() -> some View {
        if #available(iOS 16.0, *) {
            scrollDismissesKeyboard(.interactively)
        } else {
            self
        }
    }

    /// Rolls the digits when a number changes (iOS 16 and newer).
    @ViewBuilder
    func handzNumericTextTransition() -> some View {
        if #available(iOS 16.0, *) {
            contentTransition(.numericText())
        } else {
            self
        }
    }

    /// Makes a sheet exactly `height` tall (iOS 16 and newer). On iOS 15 it's a full sheet.
    @ViewBuilder
    func handzSheetHeight(_ height: CGFloat) -> some View {
        if #available(iOS 16.0, *) {
            presentationDetents([.height(height)])
                .presentationDragIndicator(.hidden)
        } else {
            self
        }
    }

    /// Removes the built-in background behind a TextEditor (iOS 16 and newer).
    @ViewBuilder
    func handzHideScrollBackground() -> some View {
        if #available(iOS 16.0, *) {
            scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}

// MARK: - Text boxes

/// A text box that grows as you type, between `lines` lines.
/// iOS 15 has no growing text box, so there it is a one-line box.
struct HandzGrowingTextField: View {
    private let title: String
    @Binding private var text: String
    private let lines: ClosedRange<Int>

    init(_ title: String, text: Binding<String>, lines: ClosedRange<Int>) {
        self.title = title
        self._text = text
        self.lines = lines
    }

    var body: some View {
        if #available(iOS 16.0, *) {
            TextField(title, text: $text, axis: .vertical)
                .lineLimit(lines)
        } else {
            iOS15Field
        }
    }

    /// iOS 15: boxes meant for a few lines (descriptions, reviews, reasons) are a
    /// fixed-height box that scrolls inside, with the hint shown until you type.
    /// One-line boxes (chat, a short note) stay one line.
    @ViewBuilder
    private var iOS15Field: some View {
        if lines.lowerBound >= 2 {
            TextEditor(text: $text)
                .frame(height: CGFloat(lines.lowerBound + 1) * 22)
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(title)
                            .foregroundColor(Color(UIColor.placeholderText))
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
        } else {
            TextField(title, text: $text)
        }
    }
}

// MARK: - Set up once at launch

enum HandzIOS15 {
    /// iOS 15 only:
    /// - a swipe down on a page puts the keyboard away (number pads have no Return key);
    /// - text editors let the background drawn behind them show through.
    static func setUp() {
        if #available(iOS 16.0, *) { return }
        UIScrollView.appearance().keyboardDismissMode = .interactive
        UITextView.appearance().backgroundColor = .clear
    }
}

// MARK: - Pull down to refresh

extension View {
    /// Pull down to refresh. On iOS 15 `.refreshable` only works on lists, so for a
    /// ScrollView the same spinner is added through UIKit. Use it where
    /// `.refreshable` would go.
    @ViewBuilder
    func handzRefreshable(action: @escaping @Sendable () async -> Void) -> some View {
        if #available(iOS 16.0, *) {
            refreshable(action: action)
        } else {
            background(HandzRefreshControlInstaller(action: action))
        }
    }
}

/// Drawn behind a ScrollView. Finds that scroll view and gives it a UIRefreshControl.
private struct HandzRefreshControlInstaller: UIViewRepresentable {
    let action: @Sendable () async -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeUIView(context: Context) -> MarkerView {
        let view = MarkerView()
        view.isUserInteractionEnabled = false
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ uiView: MarkerView, context: Context) {
        context.coordinator.action = action
    }

    final class MarkerView: UIView {
        weak var coordinator: Coordinator?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            attachSoon()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            attachSoon()
        }

        private func attachSoon() {
            guard window != nil, let coordinator = coordinator, !coordinator.isAttached else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.coordinator?.attach(near: self)
            }
        }
    }

    final class Coordinator: NSObject {
        var action: @Sendable () async -> Void
        private weak var scrollView: UIScrollView?

        var isAttached: Bool { scrollView != nil }

        init(action: @escaping @Sendable () async -> Void) {
            self.action = action
        }

        /// Looks only inside this screen, and picks the scroll view that covers
        /// most of the area this marker covers (the marker has the ScrollView's size).
        func attach(near marker: UIView) {
            guard scrollView == nil,
                  let window = marker.window,
                  let screen = Self.viewController(of: marker)?.view else { return }
            let area = marker.convert(marker.bounds, to: window)
            guard area.width > 0, area.height > 0 else { return }

            var best: UIScrollView?
            var bestOverlap: CGFloat = 0
            Self.forEachScrollView(in: screen) { candidate in
                guard let parent = candidate.superview else { return }
                let overlap = parent.convert(candidate.frame, to: window).intersection(area)
                let size = overlap.isNull ? 0 : overlap.width * overlap.height
                if size > bestOverlap {
                    best = candidate
                    bestOverlap = size
                }
            }
            guard let found = best, bestOverlap > area.width * area.height * 0.5 else { return }
            scrollView = found
            guard found.refreshControl == nil else { return }
            let control = UIRefreshControl()
            control.addTarget(self, action: #selector(refresh(_:)), for: .valueChanged)
            found.refreshControl = control
        }

        @objc private func refresh(_ control: UIRefreshControl) {
            let action = self.action
            Task { @MainActor in
                await action()
                control.endRefreshing()
            }
        }

        private static func viewController(of view: UIView) -> UIViewController? {
            var responder: UIResponder? = view
            while let current = responder {
                if let controller = current as? UIViewController { return controller }
                responder = current.next
            }
            return nil
        }

        private static func forEachScrollView(in view: UIView, _ body: (UIScrollView) -> Void) {
            for subview in view.subviews {
                if let scroll = subview as? UIScrollView, !(scroll is UITextView) {
                    body(scroll)
                }
                forEachScrollView(in: subview, body)
            }
        }
    }
}

// MARK: - The screen on top

extension UIApplication {
    /// The screen on top: the window's root, then whatever it has open on top of it.
    static func handzTopViewController() -> UIViewController? {
        let windows = shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        var top = (windows.first(where: { $0.isKeyWindow }) ?? windows.first)?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

// MARK: - Sharing a file

/// ShareLink on iOS 16 and newer; on iOS 15 a button that opens the same share sheet.
struct HandzShareLink<Label: View>: View {
    private let item: URL
    private let label: Label

    init(item: URL, @ViewBuilder label: () -> Label) {
        self.item = item
        self.label = label()
    }

    var body: some View {
        if #available(iOS 16.0, *) {
            ShareLink(item: item) { label }
        } else {
            Button {
                share()
            } label: {
                label
            }
        }
    }

    private func share() {
        guard let top = UIApplication.handzTopViewController() else { return }
        let sheet = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        // iPad shows it as a bubble, which needs a place to point at.
        sheet.popoverPresentationController?.sourceView = top.view
        sheet.popoverPresentationController?.sourceRect = CGRect(
            x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0
        )
        top.present(sheet, animated: true)
    }
}

// MARK: - Picking photos

extension View {
    /// Opens the system photo picker while `isPresented` is true, and hands back
    /// the picked photos (at most `maxCount`) as data, in the order they were picked.
    /// Works the same on iOS 15 and 16.
    func handzPhotoPicker(
        isPresented: Binding<Bool>,
        maxCount: Int = 1,
        onPicked: @escaping ([Data]) -> Void
    ) -> some View {
        sheet(isPresented: isPresented) {
            HandzPhotoPickerSheet(isPresented: isPresented, maxCount: maxCount, onPicked: onPicked)
                .ignoresSafeArea()
        }
    }
}

private struct HandzPhotoPickerSheet: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let maxCount: Int
    let onPicked: ([Data]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = maxCount
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: HandzPhotoPickerSheet

        init(parent: HandzPhotoPickerSheet) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.isPresented = false
            guard !results.isEmpty else { return }

            let onPicked = parent.onPicked
            var loaded = [Data?](repeating: nil, count: results.count)
            let group = DispatchGroup()
            for (index, result) in results.enumerated() {
                let provider = result.itemProvider
                guard provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else { continue }
                group.enter()
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    DispatchQueue.main.async {
                        loaded[index] = data
                        group.leave()
                    }
                }
            }
            group.notify(queue: .main) {
                onPicked(loaded.compactMap { $0 })
            }
        }
    }
}
