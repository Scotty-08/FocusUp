import SwiftUI

/// Presented as a sheet from TasksView's toolbar (the graduation-cap
/// button there). Two ways in, both landing on the same
/// FamilyControlsManager.mergeCanvasAssignments:
///
/// 1. The Safari extension (FocusUpCanvasExtension) -- works at any
///    school, since it rides on whatever Canvas session is already open
///    in Safari instead of asking Canvas for a token. Numbered
///    walkthrough right at the top: the one thing every FocusUp user on
///    iOS can actually use, regardless of whether their school allows
///    self-service access tokens (some, like Iowa State, don't).
/// 2. FocusUpCanvasWeb, the Edge/Chrome counterpart -- for a laptop
///    instead of the phone itself, same idea, delivered over the
///    network instead of on-device (see BackendClient.
///    fetchPendingCanvasAssignments). Collapsed by default below the
///    main walkthrough, since it's a bonus for a second device, not
///    something everyone needs.
///
/// No Personal Access Token option here -- can't assume a school allows
/// self-service tokens (Iowa State doesn't), so the two extensions
/// above are the only paths offered.
///
/// Same HUD panel language as QuestDetailView/GroupDetailView -- no new
/// visual style introduced for this screen.
struct CanvasSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var isLaptopSectionExpanded = false

    var body: some View {
        ZStack {
            PlayerBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Canvas")
                        .font(.system(size: 19, weight: .heavy))
                        .foregroundStyle(PlayerTheme.textPrimary)

                    extensionTutorial

                    laptopExtensionSection
                }
                .padding(20)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Safari extension tutorial (primary path, iPhone/iPad)

    private var extensionTutorial: some View {
        VStack(alignment: .leading, spacing: 14) {
            HUDLabel(text: "Import from Canvas")

            Text("FocusUp reads your upcoming assignments straight out of Safari while you're already signed into Canvas. No school setup or access token needed, and it works at any school.")
                .font(.system(size: 12))
                .foregroundStyle(PlayerTheme.textMuted)

            VStack(alignment: .leading, spacing: 12) {
                tutorialStep(
                    number: 1,
                    title: "Turn on the FocusUp extension",
                    body: "One-time only. Open Settings \u{2192} Safari \u{2192} Extensions, find \"FocusUp for Canvas,\" and switch it on."
                )
                tutorialStep(
                    number: 2,
                    title: "Open your Canvas dashboard",
                    body: "In Safari, go to your school's Canvas site and sign in like normal."
                )
                tutorialStep(
                    number: 3,
                    title: "Turn on Auto-Sync",
                    body: "Tap the extensions icon next to the search bar (looks like three lines), tap \"FocusUp for Canvas,\" then tap Enable Auto-Sync and allow access when Safari asks. One-time per school."
                )
            }
            .padding(14)
            .hudPanel()

            Text("After that, FocusUp updates automatically every time you visit Canvas in Safari, with no more taps needed. Read-only: it only pulls titles, due dates, and a link to each assignment's page, and never submits work or touches a grade. Nothing about your school is hardcoded, so this works the same everywhere.")
                .font(.system(size: 10))
                .foregroundStyle(PlayerTheme.textMuted)
        }
    }

    private func tutorialStep(number: Int, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(PlayerTheme.bg)
                .frame(width: 22, height: 22)
                .background(Circle().fill(PlayerTheme.cyan))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PlayerTheme.textPrimary)
                Text(body)
                    .font(.system(size: 11))
                    .foregroundStyle(PlayerTheme.textMuted)
            }
        }
    }

    // MARK: - Laptop extension (secondary path, Edge/Chrome)

    /// Collapsed by default -- same "tap to expand" pattern the old PAT
    /// section used, just pointed at FocusUpCanvasWeb instead. Kept
    /// deliberately short: this is a bonus for people who also want
    /// their laptop covered, not the main flow, and this screen has no
    /// room to spare.
    private var laptopExtensionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    isLaptopSectionExpanded.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HUDLabel(text: "Also on Your Laptop")
                        if !isLaptopSectionExpanded {
                            Text("Set up the same import for Edge or Chrome.")
                                .font(.system(size: 10))
                                .foregroundStyle(PlayerTheme.textMuted)
                        }
                    }
                    Spacer()
                    Image(systemName: isLaptopSectionExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(PlayerTheme.textMuted)
                }
            }
            .buttonStyle(.plain)

            if isLaptopSectionExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    tutorialStep(
                        number: 1,
                        title: "Install the extension",
                        body: "Search \"FocusUp for Canvas\" in the Edge or Chrome web store and add it."
                    )
                    tutorialStep(
                        number: 2,
                        title: "Sign in",
                        body: "Click the puzzle-piece icon in your toolbar, find \"FocusUp for Canvas,\" and sign in with your FocusUp email and password."
                    )
                    tutorialStep(
                        number: 3,
                        title: "Turn on Auto-Sync",
                        body: "Open Canvas, click the icon again, tap Enable Auto-Sync, and allow access. One-time per school."
                    )
                }
                .padding(14)
                .hudPanel()

                Text("Updates automatically after that, on its own, even with the tab closed. Read-only, same as the Safari extension.")
                    .font(.system(size: 10))
                    .foregroundStyle(PlayerTheme.textMuted)
            }
        }
    }
}

#Preview {
    CanvasSettingsView()
}
