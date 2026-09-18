import SwiftUI

/// A full custom screen shown in FocusUp itself, right after a periodic
/// Check-In Interval threshold fires and DeviceActivityMonitorExtension
/// re-seals the shield mid-session (see FocusUpActivity in
/// GoalStore.swift). This is the "more flare" answer to that moment --
/// previously it was silent (the shield just reappeared over the blocked
/// app with no acknowledgment in FocusUp itself). It's deliberately NOT
/// styled like StreakCelebrationView: a check-in is routine, not a
/// completion, so it stays in the everyday cyan "System" palette instead
/// of borrowing gold, which HunterTheme reserves for the streak payoff.
struct CheckInView: View {
    let streak: Int
    let activeQuestTitle: String?
    var onDismiss: () -> Void
    var onViewQuestLog: () -> Void

    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            RadialGradient(colors: [HunterTheme.cyan.opacity(0.16), .clear], center: .center, startRadius: 10, endRadius: 260)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(HunterTheme.textMuted)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                VStack(spacing: 16) {
                    HUDLabel(text: "System Check-In", size: 12, color: HunterTheme.cyan)
                        .shadow(color: HunterTheme.cyan.opacity(0.8), radius: 10)

                    ZStack {
                        SystemPulse(diameter: 110)
                        Image(systemName: "bolt.shield.fill")
                            .font(.system(size: 42))
                            .foregroundStyle(HunterTheme.cyan)
                            .shadow(color: HunterTheme.cyan.opacity(0.85), radius: 14)
                    }
                    .frame(width: 110, height: 110)

                    VStack(spacing: 4) {
                        Text("Seal Reapplied")
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(HunterTheme.textPrimary)
                        Text("The System checked in while you were away.")
                            .font(.system(size: 13))
                            .foregroundStyle(HunterTheme.textMuted)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 4) {
                        if let activeQuestTitle, !activeQuestTitle.isEmpty {
                            Text(activeQuestTitle)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(HunterTheme.cyan)
                                .multilineTextAlignment(.center)
                        }
                        if streak > 0 {
                            Text("Streak: \(streak) day\(streak == 1 ? "" : "s")")
                                .font(.system(size: 12, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(HunterTheme.textMuted)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 10) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Acknowledge")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(HunterTheme.bg)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(HunterTheme.cyan)
                            .clipShape(Capsule())
                            .shadow(color: HunterTheme.cyan.opacity(0.35), radius: 14)
                    }
                    .buttonStyle(.plain)

                    Button {
                        onViewQuestLog()
                    } label: {
                        Text("View Quest Log")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(HunterTheme.cyan)
                            .frame(height: 40)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 32)
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                scale = 1.0
                opacity = 1
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.25)) {
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDismiss()
        }
    }
}

#Preview {
    CheckInView(streak: 3, activeQuestTitle: "Apply to 3 internships", onDismiss: {}, onViewQuestLog: {})
}
