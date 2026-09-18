import SwiftUI
import AuthenticationServices

/// Shown before ContentView until the user signs in. Sign in with Apple
/// is fully real (native AuthenticationServices, no backend needed --
/// Apple is the identity provider). The email/phone section below it is
/// a UI-only placeholder: it looks and behaves like sign-up but doesn't
/// create a real secure account yet.
struct AuthView: View {
    @StateObject private var auth = AuthManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var errorText: String?

    var body: some View {
        ZStack {
            HunterBackground(topRight: false)
            ScrollView {
                VStack(spacing: 28) {
                    brandMark

                    VStack(spacing: 14) {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            switch result {
                            case .success(let authResults):
                                if let credential = authResults.credential as? ASAuthorizationAppleIDCredential {
                                    let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                                        .compactMap { $0 }
                                        .joined(separator: " ")
                                    auth.signIn(method: "apple", displayName: name.isEmpty ? nil : name)
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
                            Rectangle().fill(HunterTheme.cyanDim).frame(height: 1)
                            HUDLabel(text: "or", size: 10, color: HunterTheme.textMuted)
                            Rectangle().fill(HunterTheme.cyanDim).frame(height: 1)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Preview only right now -- this doesn't create a real account yet, just lets you try the flow. Real accounts need a backend decision first.")
                                .font(.system(size: 10))
                                .foregroundStyle(HunterTheme.emberOrange)

                            hudField(placeholder: "Email or phone number", text: $email, secure: false)
                            hudField(placeholder: "Password", text: $password, secure: true)

                            Button {
                                let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty, !password.isEmpty else {
                                    errorText = "Enter an email/phone and password."
                                    return
                                }
                                errorText = nil
                                auth.signIn(method: "email-placeholder", displayName: trimmed)
                            } label: {
                                Text("ENTER")
                                    .font(.system(size: 15, weight: .bold))
                                    .tracking(1.5)
                                    .foregroundStyle(HunterTheme.cyan)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            }
                            .buttonStyle(.plain)
                            .hudPanel()

                            Button {
                                // Decorative only for now -- matches the design
                                // mockup's non-functional "Create an account" link.
                            } label: {
                                (Text("New here? ").foregroundStyle(HunterTheme.textMuted)
                                    + Text("Create an account").foregroundStyle(HunterTheme.cyan))
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                        }

                        if let errorText {
                            Text(errorText)
                                .foregroundStyle(HunterTheme.danger)
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

    private var brandMark: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(HunterTheme.panelFill)
                    .frame(width: 72, height: 72)
                Circle()
                    .strokeBorder(HunterTheme.cyan.opacity(0.75), lineWidth: 1.5)
                    .frame(width: 72, height: 72)
                    .shadow(color: HunterTheme.cyan.opacity(0.45), radius: 10)
                Image(systemName: "chevron.up")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(HunterTheme.cyan)
                    .shadow(color: HunterTheme.cyan.opacity(0.6), radius: 8)
            }

            HUDLabel(text: "[ System ]", size: 11)

            (Text("FOCUS").foregroundStyle(HunterTheme.textPrimary) + Text("UP").foregroundStyle(HunterTheme.cyan))
                .font(.system(size: 28, weight: .heavy))

            Text("A quest is only cleared\nwhen the work is done.")
                .font(.system(size: 13))
                .foregroundStyle(HunterTheme.textMuted)
                .multilineTextAlignment(.center)
        }
    }

    private func hudField(placeholder: String, text: Binding<String>, secure: Bool) -> some View {
        Group {
            if secure {
                SecureField("", text: text, prompt: Text(placeholder).foregroundStyle(HunterTheme.textMuted))
            } else {
                TextField("", text: text, prompt: Text(placeholder).foregroundStyle(HunterTheme.textMuted))
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
            }
        }
        .foregroundStyle(HunterTheme.textPrimary)
        .padding(.horizontal, 14)
        .frame(height: 46)
        .hudPanel()
    }
}

#Preview {
    AuthView()
}
