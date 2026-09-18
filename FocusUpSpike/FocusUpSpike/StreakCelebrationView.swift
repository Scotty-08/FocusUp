import SwiftUI

/// A brief flame + streak-number celebration, shown in the FocusUp app
/// itself right after a completion is detected -- NOT on the block
/// screen. Apple's shield overlay is a fixed system template (title,
/// one subtitle line, two buttons) with no room for a custom animation,
/// so this fires the moment you're back in FocusUp after tapping
/// "I finished it", which is the closest equivalent achievable today.
struct StreakCelebrationView: View {
    let streak: Int
    var onDismiss: () -> Void

    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            RadialGradient(colors: [HunterTheme.gold.opacity(0.14), .clear], center: .center, startRadius: 10, endRadius: 260)
                .ignoresSafeArea()

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
                    Text("STREAK")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(HunterTheme.gold.opacity(0.85))
                }

                Text("Quest cleared. The seal lifts.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.7))

                Text("TAP TO CONTINUE")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(white: 0.35))
                    .padding(.top, 6)
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                scale = 1.0
                opacity = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation(.easeOut(duration: 0.4)) {
                    opacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    onDismiss()
                }
            }
        }
        .onTapGesture {
            onDismiss()
        }
    }
}

#Preview {
    StreakCelebrationView(streak: 3) {}
}
