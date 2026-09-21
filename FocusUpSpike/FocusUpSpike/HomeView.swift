import SwiftUI
import FamilyControls
import ManagedSettings
import ManagedSettingsUI

struct HomeView: View {
    @StateObject private var manager = FamilyControlsManager.shared
    @StateObject private var auth = AuthManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var isCreatingGroup = false
    @State private var editingGroup: AppGroup?

    var body: some View {
        ZStack {
            HunterBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    hudStatusRow(label: "Access Authorization", value: authorizationLabel, granted: manager.authorizationStatus == .approved)

                    if manager.authorizationStatus != .approved {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("FocusUp needs Screen Time permission to block or limit apps in your groups. This must be approved for FocusUp to work.")
                                .font(.footnote)
                                .foregroundStyle(HunterTheme.textMuted)

                            if manager.authorizationStatus == .denied {
                                Text("Permission was denied. iOS only asks once — open Settings ▸ Screen Time ▸ FocusUpSpike to turn it on, then relaunch the app.")
                                    .font(.footnote)
                                    .foregroundStyle(HunterTheme.emberOrange)
                            }
                        }
                    }

                    groupsSection

                    hunterLog

                    if let error = manager.lastError {
                        Text(error)
                            .foregroundStyle(HunterTheme.danger)
                            .font(.footnote)
                    }

                    Text("This is a feasibility spike, not the FocusUp app. It proves authorization, group selection, and per-group enforcement apply/clear on this device.")
                        .font(.footnote)
                        .foregroundStyle(HunterTheme.textMuted)
                }
                .padding(20)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            manager.refreshAuthorizationStatus()
            manager.refreshStats()
            manager.refreshTasks()
            manager.refreshGroups()
            manager.requestNotificationPermission()
            if manager.authorizationStatus == .notDetermined {
                Task { await manager.requestAuthorization() }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                manager.refreshAuthorizationStatus()
                manager.refreshStats()
                manager.refreshTasks()
                manager.refreshGroups()
            }
        }
        .sheet(isPresented: $isCreatingGroup) {
            GroupDetailView(existingGroup: nil)
        }
        .sheet(item: $editingGroup) { group in
            GroupDetailView(existingGroup: group)
        }
        // The "quest cleared" celebration overlay now lives on ContentView,
        // above the TabView, so it still shows up if the user was on a
        // different tab when they tapped back in from the shield
        // notification -- see ContentView.swift.
    }

    private var hunterName: String {
        guard let name = auth.displayName, !name.isEmpty else { return "YOU" }
        return name.uppercased()
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                (Text("FOCUS").foregroundStyle(HunterTheme.textPrimary) + Text("UP").foregroundStyle(HunterTheme.cyan))
                    .font(.system(size: 19, weight: .heavy))
                Text("HUNTER: \(hunterName)")
                    .font(.system(size: 11))
                    .foregroundStyle(HunterTheme.textMuted)
                Button("Sign Out") {
                    auth.signOut()
                }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundStyle(HunterTheme.textMuted)
                .padding(.top, 2)
            }
            Spacer()
            ZStack {
                FireAura(diameter: 40, withEmbers: false)
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(HunterTheme.gold)
                        .font(.system(size: 12))
                    Text("\(manager.currentStreak)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(HunterTheme.gold)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .hudPanel(borderColor: HunterTheme.gold.opacity(0.5), cornerAccent: HunterTheme.gold)
            }
        }
    }

    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HUDLabel(text: "Groups")
                Spacer()
                Button {
                    isCreatingGroup = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("ADD APPS")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(HunterTheme.cyan)
                }
                .buttonStyle(.plain)
                .disabled(manager.authorizationStatus != .approved)
            }

            if manager.groups.isEmpty {
                Text("No groups yet. Tap Add Apps to block or limit your first set of apps.")
                    .font(.system(size: 12))
                    .foregroundStyle(HunterTheme.textMuted)
            } else {
                VStack(spacing: 10) {
                    ForEach(manager.groups) { group in
                        GroupCardView(group: group, status: status(for: group))
                            .onTapGesture { editingGroup = group }
                    }
                }
            }
        }
    }

    /// Plain-language status pill per group -- Block groups read as
    /// blocked/unlocked, Limit groups read by whichever runtime reason
    /// (if any) currently has their shield up, defaulting to
    /// "accessible" the rest of the time. `manager.isEnforced` mirrors
    /// this app's long-standing "requested, not confirmed" caveat: it
    /// reflects what we last asked the system to do, not verified
    /// on-device enforcement.
    private func status(for group: AppGroup) -> (text: String, color: Color) {
        switch group.rule.kind {
        case .block:
            return manager.isEnforced(group)
                ? ("BLOCKED", HunterTheme.danger)
                : ("UNLOCKED", HunterTheme.cyan)
        case .limit:
            switch GroupRuntimeState.shieldReason(for: group.id) {
            case .limitBudgetExceeded:
                return ("LIMIT REACHED", HunterTheme.danger)
            case .limitReminder:
                return ("CHECK-IN", HunterTheme.gold)
            default:
                return ("ACCESSIBLE", HunterTheme.cyan)
            }
        }
    }

    private var hunterLog: some View {
        VStack(alignment: .leading, spacing: 8) {
            HUDLabel(text: "Hunter Log")
            HStack(spacing: 8) {
                logTile(value: manager.completedCount, label: "CLEARED", color: HunterTheme.cyan)
                logTile(value: manager.ignoreCount, label: "ABANDONED", color: HunterTheme.danger)
                logTile(value: manager.currentStreak, label: "STREAK", color: HunterTheme.gold, aura: true)
            }
        }
    }

    private func logTile(value: Int, label: String, color: Color, aura: Bool = false) -> some View {
        ZStack {
            if aura {
                FireAura(diameter: 70, withEmbers: false)
            }
            VStack(spacing: 2) {
                Text("\(value)")
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(HunterTheme.textMuted)
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity)
        .hudPanel(borderColor: color.opacity(0.4), cornerAccent: color)
    }

    private func hudStatusRow(label: String, value: String, granted: Bool) -> some View {
        HStack {
            HUDLabel(text: label, size: 10)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(granted ? HunterTheme.bg : HunterTheme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(granted ? HunterTheme.cyan : Color.white.opacity(0.08))
        }
        .padding(12)
        .hudPanel()
    }

    private var authorizationLabel: String {
        switch manager.authorizationStatus {
        case .notDetermined: return "Not requested"
        case .denied: return "Denied"
        case .approved: return "Granted"
        @unknown default: return "Unknown"
        }
    }
}

/// One group's card: app icons, plain-language rule summary, and a
/// status pill. Tapping anywhere opens it for editing (see HomeView's
/// `.onTapGesture`).
private struct GroupCardView: View {
    let group: AppGroup
    let status: (text: String, color: Color)

    private let maxIcons = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                appIconsRow
                Spacer()
                Text(status.text)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(HunterTheme.bg)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(status.color)
            }

            Text(group.name)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(HunterTheme.textPrimary)

            Text(group.summaryText())
                .font(.system(size: 11))
                .foregroundStyle(HunterTheme.textMuted)
        }
        .padding(14)
        .hudPanel()
    }

    private var appIconsRow: some View {
        let tokens = Array(group.selection.applicationTokens)
        let shown = tokens.prefix(maxIcons)
        let overflow = tokens.count - shown.count
        return HStack(spacing: -6) {
            ForEach(Array(shown), id: \.self) { token in
                Label(token)
                    .labelStyle(.iconOnly)
                    .frame(width: 28, height: 28)
                    .background(HunterTheme.bg)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(HunterTheme.cyanDim, lineWidth: 1))
            }
            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(HunterTheme.textMuted)
                    .frame(width: 28, height: 28)
                    .background(HunterTheme.bg)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(HunterTheme.cyanDim, lineWidth: 1))
            }
        }
    }
}

#Preview {
    NavigationStack { HomeView() }
}
