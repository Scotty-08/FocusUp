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
    @State private var confirmPassword = ""
    @State private var infoText: String?
    @State private var canResend = false
    @State private var errorText: String?
    @State private var appleNonce = ""
    @State private var isCreatingAccount = false
    @State private var isBusy = false

    private static let minPasswordLength = 8

    /// Sign-up only: the second password box has something in it that
    /// doesn't match the first.
    private var passwordsDiffer: Bool {
        isCreatingAccount && !confirmPassword.isEmpty && confirmPassword != password
    }

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
                                    auth.signIn(method: "apple", displayName: name.isEmpty ? nil : name, identity: "apple:\(credential.user)")
                                    connectBackend(with: credential)
                                } else {
                                    auth.signIn(method: "apple", displayName: nil, identity: nil)
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
                                Text("Preview only right now. This build isn't connected to the FocusUp server, so this doesn't create a real account, it just lets you try the flow.")
                                    .font(.system(size: 10))
                                    .foregroundStyle(PlayerTheme.emberOrange)
                            }

                            hudField(placeholder: "Email", text: $email, secure: false)
                            hudField(placeholder: "Password", text: $password, secure: true)

                            if isCreatingAccount {
                                hudField(placeholder: "Confirm password", text: $confirmPassword, secure: true)
                                if passwordsDiffer {
                                    Text("Passwords don't match.")
                                        .font(.system(size: 11))
                                        .foregroundStyle(PlayerTheme.danger)
                                } else if !password.isEmpty && password.count < Self.minPasswordLength {
                                    Text("Use at least \(Self.minPasswordLength) characters.")
                                        .font(.system(size: 11))
                                        .foregroundStyle(PlayerTheme.textMuted)
                                }
                            }

                            Button {
                                let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty, !password.isEmpty else {
                                    errorText = "Enter your email and password."
                                    return
                                }
                                if isCreatingAccount {
                                    guard password.count >= Self.minPasswordLength else {
                                        errorText = "Your password needs at least \(Self.minPasswordLength) characters."
                                        return
                                    }
                                    guard confirmPassword == password else {
                                        errorText = confirmPassword.isEmpty
                                            ? "Type your password a second time to confirm it."
                                            : "The two passwords don't match."
                                        return
                                    }
                                }
                                errorText = nil
                                infoText = nil
                                auth.authNotice = nil
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
                                confirmPassword = ""
                                errorText = nil
                                infoText = nil
                            } label: {
                                (Text(isCreatingAccount ? "Already have an account? " : "New here? ").foregroundStyle(PlayerTheme.textMuted)
                                    + Text(isCreatingAccount ? "Sign in" : "Create an account").foregroundStyle(PlayerTheme.cyan))
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                        }

                        if let infoText {
                            Text(infoText)
                                .foregroundStyle(PlayerTheme.cyan)
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                        }

                        if let message = errorText ?? auth.authNotice {
                            Text(message)
                                .foregroundStyle(PlayerTheme.danger)
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                        }

                        if canResend || auth.authNotice != nil {
                            Button("Send the confirmation email again") { resendConfirmation() }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(PlayerTheme.cyan)
                                .buttonStyle(.plain)
                                .disabled(isBusy)
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
            // Failure isn't fatal (the app is local-first) and is recorded
            // in BackendClient.lastConnectError for the Friends tab.
            _ = try? await BackendClient.shared.signInWithApple(idToken: token, rawNonce: nonce)
            await markReturningIfAccountExists()
        }
    }

    /// An account that already has a player card on the server isn't new,
    /// even on a phone that's never seen it -- skip the first-run tutorial.
    /// Best-effort: offline, the tutorial simply shows.
    private func markReturningIfAccountExists() async {
        guard BackendClient.shared.isConnected else { return }
        if await FriendsStore.shared.serverProfileExists() {
            auth.markReturningUser()
        }
    }

    private func submitEmail(_ email: String) {
        let shortName = String(email.split(separator: "@").first ?? Substring(email))
        guard BackendConfig.isConfigured else {
            auth.signIn(method: "email-placeholder", displayName: email, identity: "email:\(email.lowercased())")
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
                auth.signIn(method: "email", displayName: shortName, identity: "email:\(email.lowercased())")
                await markReturningIfAccountExists()
            } catch BackendError.confirmationRequired {
                // The account exists but Supabase wants the address
                // confirmed first; the email's link reopens the app signed in.
                infoText = "Almost there! We emailed a link to \(email). Open it on this iPhone and FocusUp will sign you in."
                canResend = true
            } catch {
                errorText = error.localizedDescription
                canResend = error.localizedDescription.lowercased().contains("not confirmed")
            }
        }
    }

    private func resendConfirmation() {
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty else {
            errorText = "Enter your email above, then tap resend."
            return
        }
        isBusy = true
        Task { @MainActor in
            defer { isBusy = false }
            do {
                try await BackendClient.shared.resendConfirmation(email: address)
                errorText = nil
                auth.authNotice = nil
                infoText = "Sent a fresh link to \(address). Open it on this iPhone."
                canResend = true
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

    private var brandMark: some View {
        VStack(spacing: 10) {
            // The Shutter logo (same artwork as the app icon and blockers).
            Image(uiImage: FocusUpEmblem.image)
                .resizable()
                .scaledToFit()
                .frame(width: 84, height: 84)
                .shadow(color: PlayerTheme.cyan.opacity(0.35), radius: 12)
                .accessibilityHidden(true)

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
                    // .newPassword lets iOS offer one strong password and
                    // fill both sign-up boxes with it.
                    .textContentType(isCreatingAccount ? .newPassword : .password)
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
