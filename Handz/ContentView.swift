import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authSession: AuthSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var splashFinished = false

    /// The splash stays up for its animation, and longer if we're still
    /// checking whether you're logged in.
    private var showSplash: Bool {
        !splashFinished || authSession.isRestoringSession
    }

    var body: some View {
        ZStack {
            if !showSplash {
                if authSession.isAuthenticated {
                    MainTabView()
                } else {
                    HandzStartView()
                }
            }

            if showSplash {
                HandzSplashView()
                    .transition(splashExit)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: reduceMotion ? 0.3 : 0.55), value: showSplash)
        .onAppear(perform: finishSplashLater)
    }

    /// The splash grows a little and fades away, revealing the app.
    private var splashExit: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 1.15))
    }

    private func finishSplashLater() {
        guard !splashFinished else { return }
        let wait = reduceMotion ? 1.0 : 1.8
        DispatchQueue.main.asyncAfter(deadline: .now() + wait) {
            splashFinished = true
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthSession.shared)
    }
}
