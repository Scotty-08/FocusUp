import SwiftUI

@main struct MyApp: App {
    @StateObject private var auth = AuthManager.shared

    var body: some Scene {
        WindowGroup {
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
    }
}
