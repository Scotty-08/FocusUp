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
        .tint(HunterTheme.cyan)
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                manager.refreshStats()
            }
        }
        .overlay {
            // Quest-cleared celebration always wins if both are somehow
            // pending at once -- refreshStats() already avoids setting
            // justCheckedIn in that case, this is just the belt-and-
            // suspenders UI-level guard.
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
            } else if manager.justCheckedIn {
                CheckInView(
                    streak: manager.currentStreak,
                    activeQuestTitle: manager.activeTask?.title,
                    onDismiss: { manager.dismissCheckIn() },
                    onViewQuestLog: {
                        manager.dismissCheckIn()
                        selectedTab = 1
                    }
                )
            }
        }
    }
}

#Preview {
    ContentView()
}
