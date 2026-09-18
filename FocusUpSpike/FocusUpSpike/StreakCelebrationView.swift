import SwiftUI

/// A full custom screen shown in the FocusUp app itself, right after a
/// completion is detected -- NOT on the block screen. Apple's shield
/// overlay is a fixed system template (background color, one icon, a
/// title, one subtitle line, two buttons) with no room for glow,
/// animation, or a close button, so this is where that design freedom
/// actually lives: the moment you're back in FocusUp after tapping
/// "Clear Quest — Unlock" on the shield.
///
/// questTitle is whichever quest was active at the moment it was
/// cleared, captured by ShieldActionExtension before it auto-advances
/// to the next one (see StatsStore.lastClearedQuestTitle) -- so this
/// screen always names the quest that was actually just finished, not
/// whatever's active by the time the user gets back here.
struct StreakCelebrationView: View {
    let streak: Int
    let questTitle: String?
    var onDismiss: () -> Void
    var onViewQuestLog: () -> Void

    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            RadialGradient(colors: [HunterTheme.gold.opacity(0.14), .clear], center: .center, startRadius: 10, endRadius: 260)
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
                    Text("LEVEL UP")
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
                        Text("\(streak)")
                            .font(.system(size: 62, weight: .heavy))
                            .foregroundStyle(HunterTheme.gold)
                            .shadow(color: HunterTheme.gold.opacity(0.7), radius: 22)
                        Text("DAY STREAK")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(HunterTheme.gold.opacity(0.85))
                    }

                    VStack(spacing: 4) {
                        Text("Quest Cleared")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(HunterTheme.textPrimary)
                        if let questTitle, !questTitle.isEmpty {
                            Text(questTitle)
                                .font(.system(size: 13))
                                .foregroundStyle(HunterTheme.textMuted)
                                .multilineTextAlignment(.center)
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
                        Text("Continue")
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
    StreakCelebrationView(streak: 3, questTitle: "Apply to 3 internships", onDismiss: {}, onViewQuestLog: {})
}
