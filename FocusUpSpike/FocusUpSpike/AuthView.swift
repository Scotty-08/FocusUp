import SwiftUI
import AuthenticationServices

/// Shown before ContentView until the user signs in. Sign in with Apple
/// is native AuthenticationServices; when the backend is configured its
/// identity token is also exchanged for a server account so friends
/// work (best-effort, never blocks entering the app). The email section
/// creates/signs into a real server account when the backend is
/// configured, and is a UI-only placeholder otherwise.
struct AuthView: View {
    @StateObject private var auth = AuthManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var errorText: String?
    @State private var appleNonce = ""
    @State private var isCreatingAccount = false
    @State private var isBusy = false

    var body: some View {
        ZStack {
            PlayerBackground(topRight: false)
            ScrollView {
                VStack(spacing: 28) {
                    brandMark

                    VStack(spacing: 14) {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                            let raw = AppleNonce.random()
                            appleNonce = raw
                            request.nonce = AppleNonce.sha256(raw)
                        } onCompletion: { result in
                            switch result {
                            case .success(let authResults):
                                if let credential = authResults.credential as? ASAuthorizationAppleIDCredential {
                                    let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                                        .compactMap { $0 }
                                        .joined(separator: " ")
                                    auth.signIn(method: "apple", displayName: name.isEmpty ? nil : name)
                                    connectBackend(with: credential)
                                } else {
                                    auth.signIn(method: "apple", displayName: nil)
                                }
                            case .failure(let error):
                                errorText = "Sign in with Apple failed: \(error.localizedDescription)"
                            }
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                        HStack(spacing: 12) {
                            Rectangle().fill(PlayerTheme.cyanDim).frame(height: 1)
                            HUDLabel(text: "or", size: 10, color: PlayerTheme.textMuted)
                            Rectangle().fill(PlayerTheme.cyanDim).frame(height: 1)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            if !BackendConfig.isConfigured {
                                Text("Preview only right now -- this build isn't connected to the FocusUp server, so this doesn't create a real account, it just lets you try the flow.")
                                    .font(.system(size: 10))
                                    .foregroundStyle(PlayerTheme.emberOrange)
                            }

                            hudField(placeholder: "Email or phone number", text: $email, secure: false)
                            hudField(placeholder: "Password", text: $password, secure: true)

                            Button {
                                let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty, !password.isEmpty else {
                                    errorText = "Enter an email/phone and password."
                                    return
                                }
                                errorText = nil
                                submitEmail(trimmed)
                            } label: {
                                Text(isCreatingAccount ? "CREATE ACCOUNT" : "ENTER")
                                    .font(.system(size: 15, weight: .bold))
                                    .tracking(1.5)
                                    .foregroundStyle(PlayerTheme.cyan)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            }
                            .buttonStyle(.plain)
                            .hudPanel()
                            .disabled(isBusy)
                            .opacity(isBusy ? 0.5 : 1)

                            Button {
                                isCreatingAccount.toggle()
                                errorText = nil
                            } label: {
                                (Text(isCreatingAccount ? "Already have an account? " : "New here? ").foregroundStyle(PlayerTheme.textMuted)
                                    + Text(isCreatingAccount ? "Sign in" : "Create an account").foregroundStyle(PlayerTheme.cyan))
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                        }

                        if let errorText {
                            Text(errorText)
                                .foregroundStyle(PlayerTheme.danger)
                                .font(.footnote)
                        }
                    }
                }
                .padding(28)
                .padding(.top, 40)
            }
        }
        .preferredColorScheme(.dark)
    }

    /// Exchanges Apple's identity token for a server account. Runs after
    /// the local sign-in has already happened and never blocks it -- if
    /// this fails, the Friends tab offers to connect again.
    private func connectBackend(with credential: ASAuthorizationAppleIDCredential) {
        guard BackendConfig.isConfigured,
              let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else { return }
        let nonce = appleNonce
        Task { @MainActor in
            try? await BackendClient.shared.signInWithApple(idToken: token, rawNonce: nonce)
        }
    }

    private func submitEmail(_ email: String) {
        let shortName = String(email.split(separator: "@").first ?? Substring(email))
        guard BackendConfig.isConfigured else {
            auth.signIn(method: "email-placeholder", displayName: email)
            return
        }
        isBusy = true
        let create = isCreatingAccount
        let secret = password
        Task { @MainActor in
            defer { isBusy = false }
            do {
                if create {
                    try await BackendClient.shared.signUp(email: email, password: secret)
                } else {
                    try await BackendClient.shared.signIn(email: email, password: secret)
                }
                auth.signIn(method: "email", displayName: shortName)
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

    private var brandMark: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(PlayerTheme.panelFill)
                    .frame(width: 72, height: 72)
                Circle()
                    .strokeBorder(PlayerTheme.cyan.opacity(0.75), lineWidth: 1.5)
                    .frame(width: 72, height: 72)
                    .shadow(color: PlayerTheme.cyan.opacity(0.45), radius: 10)
                Image(systemName: "chevron.up")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(PlayerTheme.cyan)
                    .shadow(color: PlayerTheme.cyan.opacity(0.6), radius: 8)
            }

            HUDLabel(text: "[ System ]", size: 11)

            (Text("FOCUS").foregroundStyle(PlayerTheme.textPrimary) + Text("UP").foregroundStyle(PlayerTheme.cyan))
                .font(.system(size: 28, weight: .heavy))

            Text("A quest is only cleared\nwhen the work is done.")
                .font(.system(size: 13))
                .foregroundStyle(PlayerTheme.textMuted)
                .multilineTextAlignment(.center)
        }
    }

    private func hudField(placeholder: String, text: Binding<String>, secure: Bool) -> some View {
        Group {
            if secure {
                SecureField("", text: text, prompt: Text(placeholder).foregroundStyle(PlayerTheme.textMuted))
            } else {
                TextField("", text: text, prompt: Text(placeholder).foregroundStyle(PlayerTheme.textMuted))
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
            }
        }
        .foregroundStyle(PlayerTheme.textPrimary)
        .padding(.horizontal, 14)
        .frame(height: 46)
        .hudPanel()
    }
}

#Preview {
    AuthView()
}
