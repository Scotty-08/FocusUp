import SwiftUI

@main struct MyApp: App {
    @StateObject private var auth = AuthManager.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.isSignedIn {
                    if auth.hasCompletedOnboarding {
                        ContentView()
                    } else {
                        OnboardingView()
                    }
                } else {
                    AuthView()
                }
            }
            // The sign-up confirmation email links to focusup://auth/confirmed
            // (see BackendClient.emailConfirmRedirect).
            .onOpenURL { url in auth.handleIncomingURL(url) }
        }
    }
}
