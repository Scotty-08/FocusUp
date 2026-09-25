import SwiftUI

/// Root of the signed-in app. Home / Quests / Player / Friends tabs.
///
/// Also owns the "quest cleared" celebration overlay. It used to live
/// inside HomeView's own ZStack, which meant it silently never appeared
/// if the user happened to be on the Quests or Player tab when they
/// tapped back in from the shield notification -- SwiftUI only renders
/// the currently-selected tab's content. Hoisting it here, above the
/// TabView itself, means it shows no matter which tab was active.
struct ContentView: View {
    @StateObject private var manager = FamilyControlsManager.shared
    @StateObject private var friends = FriendsStore.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0

    private func refreshOnActive() {
        manager.refreshAuthorizationStatus()
        manager.refreshTasks()
        manager.refreshStats()
        // Best-effort and off the critical path: publishes this player's
        // card and pulls friends/requests/cheers. A no-op when the server
        // isn't configured or the user isn't connected.
        Task {
            await friends.syncProfile()
            await friends.refresh()
        }
        // Best-effort, same as the friends sync above -- a no-op
        // whenever Canvas isn't connected.
        Task {
            await CanvasClient.shared.sync(into: manager)
        }
        // Same idea, but for assignments that arrived via the
        // FocusUpCanvasExtension Safari extension instead of the PAT
        // sync above -- whatever it dropped in the shared App Group
        // container since the last check. A no-op when there's nothing
        // pending, so safe to call every time the app comes to the
        // foreground.
        let pendingFromExtension = CanvasExtensionStore.takePending()
        if !pendingFromExtension.isEmpty {
            manager.mergeCanvasAssignments(pendingFromExtension)
        }
        // Same idea again, but for assignments a laptop/desktop browser
        // pushed in via FocusUpCanvasWeb -- there's no shared App Group
        // with a different device, so those land in the
        // canvas_pending_assignments table on the server instead, and
        // this is what pulls them down. Best-effort and off the
        // critical path like the friends sync above; deletes each row
        // once it's merged so it's only ever delivered once.
        Task {
            guard BackendClient.shared.isConnected else { return }
            if let pendingFromWeb = try? await BackendClient.shared.fetchPendingCanvasAssignments(),
               !pendingFromWeb.isEmpty {
                manager.mergeCanvasAssignments(pendingFromWeb)
                try? await BackendClient.shared.clearPendingCanvasAssignments(ids: pendingFromWeb.map(\.id))
            }
        }
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
                Label("Player", systemImage: "person.fill")
            }
            .tag(2)

            NavigationStack {
                FriendsView()
            }
            .tabItem {
                Label("Friends", systemImage: "person.2.fill")
            }
            .badge(friends.badgeCount)
            .tag(3)
        }
        .onAppear { refreshOnActive() }
        // A quest reward just changed EXP/level/streak -- publish it.
        .onChange(of: manager.justEarned?.xp) { _, _ in
            Task { await friends.syncProfile() }
        }
        .tint(PlayerTheme.cyan)
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
                    reward: manager.justEarned,
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
                    // No iOS API lets an app hand focus back to whatever
                    // app the user was in before the shield -- that's a
                    // system-level privilege only the shield's OWN
                    // buttons have (ShieldActionResponse.close/.none),
                    // not something the host app can do once the user's
                    // already left the shield and landed here. Landing
                    // on Home (rather than staying on Quests, where
                    // QuestRoute routed them) is the closest FocusUp can
                    // get to "send them back out" -- the app they were
                    // blocked on IS unblocked now (releaseActiveShields
                    // already ran), so switching to it manually opens it
                    // immediately with no shield in the way.
                    onAbandoned: {
                        manager.abandonPressingQuestPrompt()
                        selectedTab = 0
                    },
                    onNotYet: { manager.resolvePressingQuestPrompt(completed: false) }
                )
            }
        }
    }
}

#Preview {
    ContentView()
}
