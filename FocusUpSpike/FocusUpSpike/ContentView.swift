import SwiftUI

/// Root of the signed-in app. Home / Quests / Hunter tabs.
struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }

            NavigationStack {
                TasksView()
            }
            .tabItem {
                Label("Quests", systemImage: "checklist")
            }

            NavigationStack {
                CharacterView()
            }
            .tabItem {
                Label("Hunter", systemImage: "person.fill")
            }
        }
        .tint(HunterTheme.cyan)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
