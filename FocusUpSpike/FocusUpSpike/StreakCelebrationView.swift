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

    @State private var flameScale: CGFloat = 0.3
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.88).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("🔥")
                    .font(.system(size: 96))
                    .scaleEffect(flameScale)
                Text("Streak: \(streak)")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                Text("Keep it alive!")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                flameScale = 1.0
                opacity = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
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
