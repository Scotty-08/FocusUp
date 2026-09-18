import Foundation
import Combine

/// Local-only sign-in state. Sign in with Apple is real (Apple issues a
/// genuine identity). The email/phone + password path is a UI-only
/// placeholder for today -- it does not create a real account, verify
/// anything, or store a password securely; it just flips this same flag
/// so the flow can be tried end to end. Wiring up real email/phone
/// accounts needs a backend decision (see TEAM_CHAT.md) before it's
/// built for real.
@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isSignedIn: Bool
    @Published var displayName: String?
    @Published var signInMethod: String?

    /// Gates the guided first-run setup flow (OnboardingView): permission
    /// requests, then username + date of birth, then the Level 1 reveal.
    /// Separate from isSignedIn on purpose -- signing in with a
    /// different method later shouldn't re-trigger onboarding as long as
    /// it was already completed once on this device.
    @Published var hasCompletedOnboarding: Bool
    @Published var username: String?
    @Published var dateOfBirth: Date?

    private let defaults = UserDefaults.standard
    private let signedInKey = "focusUp.isSignedIn"
    private let nameKey = "focusUp.displayName"
    private let methodKey = "focusUp.signInMethod"
    private let onboardingKey = "focusUp.hasCompletedOnboarding"
    private let usernameKey = "focusUp.username"
    private let dobKey = "focusUp.dateOfBirth"

    private init() {
        isSignedIn = defaults.bool(forKey: signedInKey)
        displayName = defaults.string(forKey: nameKey)
        signInMethod = defaults.string(forKey: methodKey)
        hasCompletedOnboarding = defaults.bool(forKey: onboardingKey)
        username = defaults.string(forKey: usernameKey)
        if defaults.object(forKey: dobKey) != nil {
            dateOfBirth = Date(timeIntervalSince1970: defaults.double(forKey: dobKey))
        } else {
            dateOfBirth = nil
        }
    }

    func signIn(method: String, displayName: String?) {
        isSignedIn = true
        self.displayName = displayName
        self.signInMethod = method
        defaults.set(true, forKey: signedInKey)
        if let displayName, !displayName.isEmpty {
            defaults.set(displayName, forKey: nameKey)
        }
        defaults.set(method, forKey: methodKey)
    }

    /// Called from OnboardingView's final "Enter FocusUp" tap on the
    /// Level 1 reveal screen -- NOT from the profile step itself, even
    /// though that's where the fields are collected. hasCompletedOnboarding
    /// going true is what switches MyApp over to ContentView, so it can't
    /// flip until after the reveal has actually been shown.
    func completeOnboarding(username: String, dateOfBirth: Date) {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        self.username = trimmed
        self.dateOfBirth = dateOfBirth
        self.hasCompletedOnboarding = true
        defaults.set(trimmed, forKey: usernameKey)
        defaults.set(dateOfBirth.timeIntervalSince1970, forKey: dobKey)
        defaults.set(true, forKey: onboardingKey)
    }

    func signOut() {
        isSignedIn = false
        displayName = nil
        signInMethod = nil
        hasCompletedOnboarding = false
        username = nil
        dateOfBirth = nil
        defaults.removeObject(forKey: signedInKey)
        defaults.removeObject(forKey: nameKey)
        defaults.removeObject(forKey: methodKey)
        defaults.removeObject(forKey: onboardingKey)
        defaults.removeObject(forKey: usernameKey)
        defaults.removeObject(forKey: dobKey)
    }
}
