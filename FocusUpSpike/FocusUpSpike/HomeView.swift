import SwiftUI
import FamilyControls
import ManagedSettingsUI

struct HomeView: View {
    @StateObject private var manager = FamilyControlsManager.shared
    @StateObject private var auth = AuthManager.shared
    @State private var isPickerPresented = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var intervalHoursText = "0"
    @State private var intervalMinutesText = "30"

    var body: some View {
        ZStack {
            HunterBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    hudStatusRow(label: "Access Authorization", value: authorizationLabel, granted: manager.authorizationStatus == .approved)

                    if manager.authorizationStatus != .approved {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("FocusUp needs Screen Time permission to block apps until your focus tasks are done. This must be approved for FocusUp to work.")
                                .font(.footnote)
                                .foregroundStyle(HunterTheme.textMuted)

                            if manager.authorizationStatus == .denied {
                                Text("Permission was denied. iOS only asks once — open Settings ▸ Screen Time ▸ FocusUpSpike to turn it on, then relaunch the app.")
                                    .font(.footnote)
                                    .foregroundStyle(HunterTheme.emberOrange)
                            }
                        }
                    }

                    sealedAppsSection

                    checkInSection

                    HStack(spacing: 12) {
                        Button {
                            manager.applyShield()
                        } label: {
                            Text("APPLY SEAL")
                                .font(.system(size: 13, weight: .heavy))
                                .tracking(1)
                                .foregroundStyle(HunterTheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                        }
                        .buttonStyle(.plain)
                        .hudPanel()
                        .shadow(color: HunterTheme.cyan.opacity(0.18), radius: 12)
                        .disabled(manager.selection.applicationTokens.isEmpty)
                        .opacity(manager.selection.applicationTokens.isEmpty ? 0.4 : 1)

                        Button {
                            manager.clearShield()
                        } label: {
                            Text("RELEASE")
                                .font(.system(size: 13, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(HunterTheme.textMuted)
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                        }
                        .buttonStyle(.plain)
                        .overlay(Rectangle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                        .disabled(!manager.isShielded)
                    }

                    hudStatusRow(label: "Shield requested", value: manager.isShielded ? "ON — verify on device" : "OFF", granted: manager.isShielded)

                    hunterLog

                    if let error = manager.lastError {
                        Text(error)
                            .foregroundStyle(HunterTheme.danger)
                            .font(.footnote)
                    }

                    Text("This is a feasibility spike, not the FocusUp app. It proves authorization, selection, and shield apply/clear on this device.")
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
            syncIntervalTextFromManager()
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
            }
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

    private var sealedAppsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HUDLabel(text: "Sealed Apps")
                Spacer()
                Button {
                    isPickerPresented = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("ADD")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(HunterTheme.cyan)
                }
                .buttonStyle(.plain)
                .disabled(manager.authorizationStatus != .approved)
                .familyActivityPicker(isPresented: $isPickerPresented, selection: $manager.selection)
                .onChange(of: manager.selection) { _, _ in manager.saveSelection() }
            }

            if manager.selection.applicationTokens.isEmpty {
                Text("None selected yet.")
                    .font(.system(size: 12))
                    .foregroundStyle(HunterTheme.textMuted)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(manager.selection.applicationTokens), id: \.self) { token in
                        Label(token)
                            .labelStyle(.titleAndIcon)
                            .font(.system(size: 12))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(HunterTheme.cyan.opacity(0.08))
                            .overlay(Rectangle().strokeBorder(HunterTheme.cyanDim, lineWidth: 1))
                            .foregroundStyle(HunterTheme.textPrimary)
                    }
                }
            }
        }
    }

    private var checkInSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HUDLabel(text: "Check-In Interval")
            Text("Re-shows the block screen after this much actual use of the selected app(s) -- not wall-clock time. Starts automatically when you apply the seal above, and stops when you release it.")
                .font(.system(size: 10))
                .foregroundStyle(HunterTheme.textMuted)

            HStack(alignment: .bottom, spacing: 12) {
                intervalField(label: "HRS", text: $intervalHoursText)
                intervalField(label: "MIN", text: $intervalMinutesText)
                Button {
                    intervalHoursText = "0"
                    intervalMinutesText = "0"
                    updateIntervalFromText()
                } label: {
                    Text("Quick 30s (demo)")
                        .font(.system(size: 11))
                        .foregroundStyle(HunterTheme.cyan)
                }
                .buttonStyle(.plain)
                .disabled(manager.isPeriodicCheckInActive)
                Spacer()
            }

            Text(manager.isPeriodicCheckInActive ? "Active — checking in every \(checkInIntervalLabel)." : "Will check in every \(checkInIntervalLabel) once the seal is applied.")
                .font(.system(size: 10))
                .foregroundStyle(manager.isPeriodicCheckInActive ? HunterTheme.cyan : HunterTheme.textMuted)
        }
        .padding(14)
        .hudPanel()
    }

    private func intervalField(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 10)).foregroundStyle(HunterTheme.textMuted)
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .foregroundStyle(HunterTheme.textPrimary)
                .frame(width: 60, height: 36)
                .overlay(Rectangle().strokeBorder(HunterTheme.cyanDim, lineWidth: 1))
                .disabled(manager.isPeriodicCheckInActive)
                .onChange(of: text.wrappedValue) { _, _ in updateIntervalFromText() }
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

    private func updateIntervalFromText() {
        let hours = Int(intervalHoursText) ?? 0
        let minutes = Int(intervalMinutesText) ?? 0
        let total = (hours * 3600) + (minutes * 60)
        manager.checkInIntervalSeconds = max(total, 30)
    }

    private func syncIntervalTextFromManager() {
        let seconds = manager.checkInIntervalSeconds
        if seconds == 30 {
            intervalHoursText = "0"
            intervalMinutesText = "0"
        } else {
            intervalHoursText = "\(seconds / 3600)"
            intervalMinutesText = "\((seconds % 3600) / 60)"
        }
    }

    private var checkInIntervalLabel: String {
        manager.checkInIntervalSeconds == 30 ? "30s (demo)" : "\(manager.checkInIntervalSeconds / 60) min"
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

#Preview {
    NavigationStack { HomeView() }
}
