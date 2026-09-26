import Foundation
import Combine

/// Local sign-in state -- what gates the UI. The app is local-first: this
/// flips immediately and never waits on the network. The server account
/// (Supabase, see BackendClient) is established separately and
/// best-effort; friends features light up once it exists.
///
/// Sign in with Apple is real (Apple issues a genuine identity). The
/// email + password path is real too WHEN the backend is configured
/// (BackendConfig.isConfigured); otherwise it stays a UI-only placeholder
/// that just flips this flag so the flow can be tried end to end.
@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isSignedIn: Bool
    @Published var displayName: String?
    @Published var signInMethod: String?
    /// A message for the sign-in screen about an email link the app was
    /// opened with (e.g. an expired confirmation link). nil = nothing to say.
    @Published var authNotice: String?

    /// Gates the guided first-run setup flow (OnboardingView): permission
    /// requests, then the player name and look, then the Level 1 reveal.
    /// Separate from isSignedIn on purpose -- signing in with a
    /// different method later shouldn't re-trigger onboarding as long as
    /// it was already completed once on this device.
    @Published var hasCompletedOnboarding: Bool
    @Published var username: String?

    private let defaults = UserDefaults.standard
    private let signedInKey = "focusUp.isSignedIn"
    private let nameKey = "focusUp.displayName"
    private let methodKey = "focusUp.signInMethod"
    private let onboardingKey = "focusUp.hasCompletedOnboarding"
    private let usernameKey = "focusUp.username"
    /// Only used to erase a birthday saved by older builds, which asked
    /// for one during setup. The app no longer collects it.
    private let legacyDobKey = "focusUp.dateOfBirth"
    private let identityKey = "focusUp.identity"
    private let onboardedKey = "focusUp.onboardedIdentities"
    /// Stands in for "someone who finished onboarding before per-account
    /// tracking existed" -- consumed by their next sign-in, so a
    /// returning tester isn't put through the tutorial again.
    private static let legacyToken = "__legacy__"

    /// Stable id of whoever is signed in (Apple's user id, or the
    /// lowercased email). Used only to remember who has already seen the
    /// first-run tutorial.
    private var currentIdentity: String?

    private init() {
        isSignedIn = defaults.bool(forKey: signedInKey)
        displayName = defaults.string(forKey: nameKey)
        signInMethod = defaults.string(forKey: methodKey)
        hasCompletedOnboarding = defaults.bool(forKey: onboardingKey)
        username = defaults.string(forKey: usernameKey)
        currentIdentity = defaults.string(forKey: identityKey)
        defaults.removeObject(forKey: legacyDobKey)
    }

    private var onboardedIdentities: Set<String> {
        get { Set(defaults.stringArray(forKey: onboardedKey) ?? []) }
        set { defaults.set(Array(newValue), forKey: onboardedKey) }
    }

    /// Whether this identity has been through the tutorial before.
    private func hasOnboarded(_ identity: String?) -> Bool {
        var known = onboardedIdentities
        if let identity, known.contains(identity) { return true }
        if known.contains(Self.legacyToken) {
            known.remove(Self.legacyToken)
            if let identity { known.insert(identity) }
            onboardedIdentities = known
            return true
        }
        return false
    }

    /// `identity` is what tells a returning user from a brand-new one: the
    /// first-run tutorial only shows for an identity that has never
    /// completed it on this device (or, see markReturningUser, that
    /// already has an account on the server).
    func signIn(method: String, displayName: String?, identity: String? = nil) {
        currentIdentity = identity
        if let identity {
            defaults.set(identity, forKey: identityKey)
        } else {
            defaults.removeObject(forKey: identityKey)
        }
        hasCompletedOnboarding = hasOnboarded(identity)
        defaults.set(hasCompletedOnboarding, forKey: onboardingKey)
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
    func completeOnboarding(username: String) {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        self.username = trimmed
        self.hasCompletedOnboarding = true
        if let currentIdentity { onboardedIdentities.insert(currentIdentity) }
        defaults.set(trimmed, forKey: usernameKey)
        defaults.set(true, forKey: onboardingKey)
    }

    /// For someone who signed in on a NEW device but already has an
    /// account on the server -- they're not new, so skip the tutorial.
    func markReturningUser() {
        guard !hasCompletedOnboarding else { return }
        hasCompletedOnboarding = true
        defaults.set(true, forKey: onboardingKey)
        if let currentIdentity { onboardedIdentities.insert(currentIdentity) }
    }

    /// Handles focusup://auth/confirmed#access_token=... -- the link in the
    /// sign-up confirmation email. Tapping it on the phone opens the app
    /// already signed in to the new account.
    func handleIncomingURL(_ url: URL) {
        let account: BackendClient.EmailLinkAccount
        do {
            guard let parsed = try BackendClient.emailLinkAccount(from: url) else { return }
            account = parsed
        } catch {
            if !isSignedIn { authNotice = error.localizedDescription }
            return
        }
        let email = account.email?.lowercased()
        let identity = email.map { "email:\($0)" } ?? "user:\(account.session.userID.uuidString.lowercased())"
        // Someone else is already signed in on this phone: don't swap
        // accounts underneath them.
        if isSignedIn, currentIdentity != identity { return }

        BackendClient.shared.adopt(account.session)
        authNotice = nil
        if !isSignedIn {
            let shortName = email.map { String($0.split(separator: "@").first ?? Substring($0)) }
            signIn(method: "email", displayName: shortName, identity: identity)
        }
        Task { @MainActor in
            if await FriendsStore.shared.serverProfileExists() { self.markReturningUser() }
        }
    }

    func signOut() {
        // Remember that this person finished the tutorial, so signing
        // back in doesn't repeat it. A session from before per-account
        // tracking has no identity yet, so it's parked as "legacy".
        if hasCompletedOnboarding {
            onboardedIdentities.insert(currentIdentity ?? Self.legacyToken)
        }
        currentIdentity = nil
        defaults.removeObject(forKey: identityKey)
        // Drop the server session and cached friends so the next account
        // on this device doesn't inherit them.
        BackendClient.shared.signOut()
        FriendsStore.shared.reset()
        isSignedIn = false
        displayName = nil
        signInMethod = nil
        hasCompletedOnboarding = false
        username = nil
        defaults.removeObject(forKey: signedInKey)
        defaults.removeObject(forKey: nameKey)
        defaults.removeObject(forKey: methodKey)
        defaults.removeObject(forKey: onboardingKey)
        defaults.removeObject(forKey: usernameKey)
        defaults.removeObject(forKey: legacyDobKey)
    }
}
