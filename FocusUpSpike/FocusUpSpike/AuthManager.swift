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

    private let defaults = UserDefaults.standard
    private let signedInKey = "focusUp.isSignedIn"
    private let nameKey = "focusUp.displayName"
    private let methodKey = "focusUp.signInMethod"

    private init() {
        isSignedIn = defaults.bool(forKey: signedInKey)
        displayName = defaults.string(forKey: nameKey)
        signInMethod = defaults.string(forKey: methodKey)
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

    func signOut() {
        isSignedIn = false
        displayName = nil
        signInMethod = nil
        defaults.removeObject(forKey: signedInKey)
        defaults.removeObject(forKey: nameKey)
        defaults.removeObject(forKey: methodKey)
    }
}
