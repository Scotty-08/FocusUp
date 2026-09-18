import SwiftUI
import FamilyControls

/// Guided first-run setup shown once, right after sign-in, gated by
/// AuthManager.hasCompletedOnboarding -- see MyApp. One screen per
/// permission request, then a profile screen (username + date of
/// birth), then a Level 1 reveal using the same fire-aura "LEVEL UP"
/// treatment as StreakCelebrationView -- a brand new Hunter's very
/// first level should feel like the same kind of payoff, not just the
/// end of a settings form.
///
/// hasCompletedOnboarding is only flipped true on the FINAL reveal
/// screen's "Enter FocusUp" tap, not earlier -- MyApp switches straight
/// to ContentView the instant that flag goes true, so setting it any
/// sooner would skip the reveal itself before the user ever saw it.
struct OnboardingView: View {
    private enum Step: Int, CaseIterable {
        case screenTime, notifications, profile, reveal
    }

    @StateObject private var manager = FamilyControlsManager.shared
    @StateObject private var auth = AuthManager.shared
    @State private var step: Step = .screenTime

    @State private var usernameInput = ""
    @State private var dateOfBirth = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @State private var notificationsRequested = false
    @State private var profileError: String?

    var body: some View {
        ZStack {
            HunterBackground(topRight: false)
            VStack(spacing: 0) {
                if step != .reveal {
                    progressDots
                        .padding(.top, 22)
                        .padding(.bottom, 8)
                }

                Group {
                    switch step {
                    case .screenTime: screenTimeStep
                    case .notifications: notificationsStep
                    case .profile: profileStep
                    case .reveal: revealStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .id(step)
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeOut(duration: 0.25), value: step)
    }

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(Step.allCases.dropLast(), id: \.self) { s in
                Capsule()
                    .fill(s.rawValue <= step.rawValue ? HunterTheme.cyan : HunterTheme.cyanDim)
                    .frame(width: s == step ? 22 : 8, height: 6)
            }
        }
    }

    // MARK: - Step 1: Screen Time

    private var screenTimeStep: some View {
        stepScaffold(
            tag: "STEP 1 OF 3",
            icon: "shield.lefthalf.filled",
            headline: "Screen Time Access",
            body: "FocusUp needs Screen Time permission to seal the apps you want to focus away from, and to check in on you while you work.",
            primaryLabel: manager.authorizationStatus == .approved ? "Continue" : "Grant Access",
            primaryAction: {
                if manager.authorizationStatus == .approved {
                    step = .notifications
                } else {
                    Task { await manager.requestAuthorization() }
                }
            },
            secondaryLabel: "Skip for now",
            secondaryAction: { step = .notifications }
        )
        .onChange(of: manager.authorizationStatus) { _, newStatus in
            if newStatus == .approved {
                step = .notifications
            }
        }
    }

    // MARK: - Step 2: Notifications

    private var notificationsStep: some View {
        stepScaffold(
            tag: "STEP 2 OF 3",
            icon: "bell.badge.fill",
            headline: "Stay In The Loop",
            body: "Notifications are how FocusUp taps you back in after a Quest Clear or a System Check-In -- extensions can't reopen the app directly, so this is the bridge.",
            primaryLabel: notificationsRequested ? "Continue" : "Enable Notifications",
            primaryAction: {
                if notificationsRequested {
                    step = .profile
                } else {
                    manager.requestNotificationPermission()
                    notificationsRequested = true
                }
            },
            secondaryLabel: "Skip for now",
            secondaryAction: { step = .profile }
        )
    }

    // MARK: - Step 3: Profile

    private var profileStep: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 8)

            iconBadge(systemName: "person.crop.circle.fill")

            VStack(spacing: 10) {
                HUDLabel(text: "Step 3 of 3", size: 10)
                Text("Who's Leveling Up?")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(HunterTheme.textPrimary)
                Text("Last thing before you're in.")
                    .font(.system(size: 14))
                    .foregroundStyle(HunterTheme.textMuted)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HUDLabel(text: "Username", size: 10)
                    TextField("", text: $usernameInput, prompt: Text("HunterName").foregroundStyle(HunterTheme.textMuted))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundStyle(HunterTheme.textPrimary)
                        .padding(.horizontal, 14)
                        .frame(height: 46)
                        .hudPanel()
                }

                VStack(alignment: .leading, spacing: 6) {
                    HUDLabel(text: "Date of Birth", size: 10)
                    DatePicker("", selection: $dateOfBirth, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(HunterTheme.cyan)
                        .padding(.horizontal, 14)
                        .frame(height: 46, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .hudPanel()
                }

                if let profileError {
                    Text(profileError)
                        .font(.system(size: 12))
                        .foregroundStyle(HunterTheme.danger)
                }
            }
            .padding(.horizontal, 28)

            Spacer()

            primaryButton(label: "Continue") {
                let trimmed = usernameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    profileError = "Enter a username to continue."
                    return
                }
                profileError = nil
                usernameInput = trimmed
                step = .reveal
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Step 4: Level 1 reveal

    private var revealStep: some View {
        VStack {
            Spacer()

            VStack(spacing: 16) {
                Text("WELCOME, HUNTER")
                    .font(.system(size: 12, weight: .heavy))
                    .tracking(4)
                    .foregroundStyle(HunterTheme.gold)
                    .shadow(color: HunterTheme.gold.opacity(0.8), radius: 10)

                ZStack {
                    FireAura(diameter: 110)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 46))
                        .foregroundStyle(HunterTheme.gold)
                        .shadow(color: HunterTheme.gold.opacity(0.85), radius: 14)
                }
                .frame(width: 88, height: 88)

                VStack(spacing: 4) {
                    Text("1")
                        .font(.system(size: 72, weight: .heavy))
                        .foregroundStyle(HunterTheme.gold)
                        .shadow(color: HunterTheme.gold.opacity(0.7), radius: 22)
                    Text("HUNTER LEVEL")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(HunterTheme.gold.opacity(0.85))
                }

                VStack(spacing: 4) {
                    Text(usernameInput.isEmpty ? "Hunter" : usernameInput)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(HunterTheme.textPrimary)
                    Text("has entered the System.")
                        .font(.system(size: 13))
                        .foregroundStyle(HunterTheme.textMuted)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 32)

            Spacer()

            primaryButton(label: "Enter FocusUp") {
                let name = usernameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                auth.completeOnboarding(username: name, dateOfBirth: dateOfBirth)
                CharacterStore.shared.rename(name)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Shared step layout

    private func stepScaffold(
        tag: String,
        icon: String,
        headline: String,
        body: String,
        primaryLabel: String,
        primaryAction: @escaping () -> Void,
        secondaryLabel: String,
        secondaryAction: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 22) {
            Spacer(minLength: 8)

            iconBadge(systemName: icon)

            VStack(spacing: 10) {
                HUDLabel(text: tag, size: 10)
                Text(headline)
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(HunterTheme.textPrimary)
                    .multilineTextAlignment(.center)
                Text(body)
                    .font(.system(size: 14))
                    .foregroundStyle(HunterTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            Spacer()

            VStack(spacing: 12) {
                primaryButton(label: primaryLabel, action: primaryAction)
                Button(action: secondaryAction) {
                    Text(secondaryLabel)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(HunterTheme.textMuted)
                        .frame(height: 34)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
    }

    private func iconBadge(systemName: String) -> some View {
        ZStack {
            Circle()
                .fill(HunterTheme.panelFill)
                .frame(width: 84, height: 84)
            Circle()
                .strokeBorder(HunterTheme.cyan.opacity(0.75), lineWidth: 1.5)
                .frame(width: 84, height: 84)
                .shadow(color: HunterTheme.cyan.opacity(0.45), radius: 10)
            Image(systemName: systemName)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(HunterTheme.cyan)
                .shadow(color: HunterTheme.cyan.opacity(0.6), radius: 8)
        }
    }

    private func primaryButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(HunterTheme.bg)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(HunterTheme.cyan)
                .clipShape(Capsule())
                .shadow(color: HunterTheme.cyan.opacity(0.35), radius: 14)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingView()
}
