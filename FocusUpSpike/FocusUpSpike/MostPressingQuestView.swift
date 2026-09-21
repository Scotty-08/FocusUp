import SwiftUI

/// Shown once per cold launch (see ContentView.onAppear ->
/// FamilyControlsManager.checkInOnLaunch) -- not on every foreground,
/// so quickly switching away from and back to FocusUp doesn't re-ask.
/// Names the single most pressing quest (TaskStore.autoPickNextTask:
/// highest priority, then earliest deadline -- the same pick the Quest
/// Log's own "active" badge uses) and asks whether it got done since
/// the app was last open.
///
/// Uses the "routine, not a payoff" cyan System palette (SystemPulse),
/// not FireAura/gold -- see HunterTheme's color-system rule: gold is
/// reserved for the streak/level-up moment (StreakCelebrationView).
/// Answering "Yes" can still lead straight into that gold moment right
/// after this one dismisses, via the normal completion path.
struct MostPressingQuestView: View {
    let task: FocusTask
    var onCompleted: () -> Void
    var onNotYet: () -> Void

    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            RadialGradient(colors: [HunterTheme.cyan.opacity(0.12), .clear], center: .center, startRadius: 10, endRadius: 260)
                .ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: 16) {
                    Text("CHECK IN")
                        .font(.system(size: 12, weight: .heavy))
                        .tracking(4)
                        .foregroundStyle(HunterTheme.cyan)
                        .shadow(color: HunterTheme.cyan.opacity(0.8), radius: 10)

                    ZStack {
                        SystemPulse(diameter: 100)
                        Image(systemName: "flag.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(HunterTheme.cyan)
                            .shadow(color: HunterTheme.cyan.opacity(0.7), radius: 10)
                    }
                    .frame(width: 88, height: 88)

                    VStack(spacing: 6) {
                        Text("Your most pressing quest")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(HunterTheme.textMuted)
                        Text(task.title)
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundStyle(HunterTheme.textPrimary)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 10) {
                            priorityBadge
                            if let due = task.dueDate {
                                Text(due.formatted(date: .abbreviated, time: .omitted).uppercased())
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(HunterTheme.textMuted)
                            }
                        }
                        .padding(.top, 4)
                    }

                    Text("Did you finish it?")
                        .font(.system(size: 14))
                        .foregroundStyle(HunterTheme.textMuted)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 10) {
                    Button {
                        dismiss(completed: true)
                    } label: {
                        Text("Yes, completed it")
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
                        dismiss(completed: false)
                    } label: {
                        Text("Not yet")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(HunterTheme.textMuted)
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

    private var priorityBadge: some View {
        Text(task.priority.label.uppercased())
            .font(.system(size: 10, weight: .heavy))
            .foregroundStyle(priorityColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .overlay(Rectangle().strokeBorder(priorityColor.opacity(0.6), lineWidth: 1))
    }

    private var priorityColor: Color {
        switch task.priority {
        case .high: return HunterTheme.danger
        case .medium: return HunterTheme.gold
        case .low: return HunterTheme.cyan
        }
    }

    private func dismiss(completed: Bool) {
        withAnimation(.easeOut(duration: 0.25)) {
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if completed {
                onCompleted()
            } else {
                onNotYet()
            }
        }
    }
}

#Preview {
    MostPressingQuestView(
        task: FocusTask(title: "Apply to 3 internships", dueDate: Date(), priority: .high),
        onCompleted: {},
        onNotYet: {}
    )
}
