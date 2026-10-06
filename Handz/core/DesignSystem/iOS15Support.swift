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
            TextField(title, text: $text)
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
