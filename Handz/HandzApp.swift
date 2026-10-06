import SwiftUI

@main
struct HandzApp: App {
    @StateObject private var authSession = AuthSession.shared
    @AppStorage(AppAppearance.storageKey) private var appearance: String = AppAppearance.system.rawValue

    init() {
        HandzIOS15.setUp()
    }

    var body: some Scene {
        WindowGroup {
            DispatchPopupContainer {
                AlertPopupContainer {
                    ContentView()
                        .environmentObject(authSession)
                }
            }
            // Light / dark / automatic, from Settings
            .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme)
            .task {
                await authSession.restoreSessionIfAvailable()
            }
            .onChange(of: authSession.isAuthenticated) { isAuthenticated in
                if isAuthenticated {
                    AlertPoller.shared.start()
                } else {
                    AlertPoller.shared.stop()
                }

                if isAuthenticated && authSession.currentUser?.role == "worker" {
                    DispatchPoller.shared.start()
                } else {
                    DispatchPoller.shared.stop()
                }
            }
        }
    }
}
