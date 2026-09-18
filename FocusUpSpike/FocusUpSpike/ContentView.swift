import SwiftUI

/// Root of the signed-in app. Now split into pages (Home / Tasks)
/// instead of one long scrolling screen, per Scott's request.
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
                Label("Tasks", systemImage: "checklist")
            }
        }
        .tint(.orange)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
