import SwiftUI

/// Root of the signed-in app. Home / Quests / Hunter tabs.
///
/// Also owns the "quest cleared" celebration overlay. It used to live
/// inside HomeView's own ZStack, which meant it silently never appeared
/// if the user happened to be on the Quests or Hunter tab when they
/// tapped back in from the shield notification -- SwiftUI only renders
/// the currently-selected tab's content. Hoisting it here, above the
/// TabView itself, means it shows no matter which tab was active.
struct ContentView: View {
    @StateObject private var manager = FamilyControlsManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0

    private func refreshOnActive() {
        manager.refreshAuthorizationStatus()
        manager.refreshTasks()
        manager.refreshStats()
        // Consumes the breadcrumb ShieldActionExtension leaves when the
        // shield's "Open Quests" button is tapped (see QuestRoute in
        // GoalStore.swift and ShieldActionExtension.handleLimit) -- the
        // notification tap that actually launches/foregrounds the app is
        // a separate, real user action (extensions can't open the host
        // app directly), so this is what turns "the app happened to
        // launch" into "land on the Quests tab specifically." False by
        // default, so this is a no-op on every other launch/foreground.
        if QuestRoute.consume() {
            selectedTab = 1
            // Specifically the shield-return moment, not every ordinary
            // launch/foreground -- see presentPressingQuestCheckIn's doc
            // comment.
            manager.presentPressingQuestCheckIn()
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(0)

            NavigationStack {
                TasksView()
            }
            .tabItem {
                Label("Quests", systemImage: "checklist")
            }
            .tag(1)

            NavigationStack {
                CharacterView()
            }
            .tabItem {
                Label("Hunter", systemImage: "person.fill")
            }
            .tag(2)
        }
        .onAppear { refreshOnActive() }
        .tint(HunterTheme.cyan)
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                refreshOnActive()
            }
        }
        .overlay {
            // Streak celebration always wins if both are somehow pending
            // at once -- e.g. answering "Yes" on the check-in prompt can
            // itself trigger a streak completion, which should then take
            // over once the check-in prompt clears itself.
            if let streak = manager.justCompletedStreak {
                StreakCelebrationView(
                    streak: streak,
                    questTitle: manager.justClearedQuestTitle,
                    onDismiss: { manager.dismissStreakAnimation() },
                    onViewQuestLog: {
                        manager.dismissStreakAnimation()
                        selectedTab = 1
                    }
                )
            } else if let task = manager.pressingQuestPrompt {
                MostPressingQuestView(
                    task: task,
                    onCompleted: { manager.resolvePressingQuestPrompt(completed: true) },
                    onNotYet: { manager.resolvePressingQuestPrompt(completed: false) }
                )
            }
        }
    }
}

#Preview {
    ContentView()
}
