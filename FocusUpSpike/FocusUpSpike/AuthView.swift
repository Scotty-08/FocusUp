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
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("FocusUp")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                        Text("Sign in to set your focus goals and block distracting apps until they're done.")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                    }
                    .padding(.top, 40)

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
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    HStack(spacing: 12) {
                        Rectangle().fill(Color.gray.opacity(0.4)).frame(height: 1)
                        Text("or").foregroundStyle(.gray).font(.caption)
                        Rectangle().fill(Color.gray.opacity(0.4)).frame(height: 1)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sign up with email or phone")
                            .foregroundStyle(.white)
                            .bold()
                        Text("Preview only right now -- this doesn't create a real account yet, just lets you try the flow. Real accounts need a backend decision first.")
                            .font(.caption2)
                            .foregroundStyle(.orange)

                        TextField("Email or phone number", text: $email)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color(white: 0.15))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)

                        SecureField("Password", text: $password)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color(white: 0.15))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button {
                            let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty, !password.isEmpty else {
                                errorText = "Enter an email/phone and password."
                                return
                            }
                            errorText = nil
                            auth.signIn(method: "email-placeholder", displayName: trimmed)
                        } label: {
                            Text("Sign Up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AuthButtonStyle(color: .blue))
                    }

                    if let errorText {
                        Text(errorText)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
                .padding(24)
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct AuthButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(color.opacity(configuration.isPressed ? 0.6 : 1))
            .foregroundStyle(.white)
            .bold()
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    AuthView()
}
