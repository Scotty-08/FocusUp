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
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("FocusUp — Platform Spike")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            if let name = auth.displayName, !name.isEmpty {
                                Text("Signed in as \(name)")
                                    .font(.caption2)
                                    .foregroundStyle(.gray)
                            }
                        }
                        Spacer()
                        Button("Sign Out") {
                            auth.signOut()
                        }
                        .font(.caption)
                        .foregroundStyle(.gray)
                    }

                    statusRow(label: "Screen Time authorization", value: authorizationLabel)

                    if manager.authorizationStatus != .approved {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("FocusUp needs Screen Time permission to block apps until your focus tasks are done. This must be approved for FocusUp to work.")
                                .font(.footnote)
                                .foregroundStyle(.gray)

                            if manager.authorizationStatus == .denied {
                                Text("Permission was denied. iOS only asks once — open Settings ▸ Screen Time ▸ FocusUpSpike to turn it on, then relaunch the app.")
                                    .font(.footnote)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }

                    Divider().background(Color.gray)

                    Button {
                        isPickerPresented = true
                    } label: {
                        Text("Select App to Restrict")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SpikeButtonStyle(color: .blue))
                    .disabled(manager.authorizationStatus != .approved)
                    .familyActivityPicker(isPresented: $isPickerPresented, selection: $manager.selection)
                    .onChange(of: manager.selection) { _, _ in manager.saveSelection() }

                    if !manager.selection.applicationTokens.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Selected:")
                                .foregroundStyle(.gray)
                            ForEach(Array(manager.selection.applicationTokens), id: \.self) { token in
                                Label(token)
                                    .labelStyle(.titleAndIcon)
                                    .foregroundStyle(.white)
                            }
                        }
                    }

                    // Note: the active task is picked from the Tasks tab now, not shown here.

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Periodic check-ins")
                            .foregroundStyle(.gray)

                        Text("Re-shows the block screen after this much actual use of the selected app(s) -- not wall-clock time. Starts automatically when you apply the shield below, and stops when you clear it.")
                            .font(.caption2)
                            .foregroundStyle(.gray)

                        HStack(alignment: .bottom, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Hours").font(.caption2).foregroundStyle(.gray)
                                TextField("0", text: $intervalHoursText)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 60)
                                    .disabled(manager.isPeriodicCheckInActive)
                                    .onChange(of: intervalHoursText) { _, _ in updateIntervalFromText() }
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Minutes").font(.caption2).foregroundStyle(.gray)
                                TextField("30", text: $intervalMinutesText)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 60)
                                    .disabled(manager.isPeriodicCheckInActive)
                                    .onChange(of: intervalMinutesText) { _, _ in updateIntervalFromText() }
                            }
                            Button {
                                intervalHoursText = "0"
                                intervalMinutesText = "0"
                                updateIntervalFromText()
                            } label: {
                                Text("Quick 30s (demo)")
                                    .font(.caption)
                            }
                            .disabled(manager.isPeriodicCheckInActive)
                            Spacer()
                        }

                        Text(manager.isPeriodicCheckInActive ? "Active — checking in every \(checkInIntervalLabel)." : "Will check in every \(checkInIntervalLabel) once the shield is applied.")
                            .font(.caption2)
                            .foregroundStyle(manager.isPeriodicCheckInActive ? .green : .gray)
                    }

                    HStack(spacing: 16) {
                        Button {
                            manager.applyShield()
                        } label: {
                            Text("Apply Shield")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SpikeButtonStyle(color: .red))
                        .disabled(manager.selection.applicationTokens.isEmpty)

                        Button {
                            manager.clearShield()
                        } label: {
                            Text("Clear Shield")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SpikeButtonStyle(color: .green))
                        .disabled(!manager.isShielded)
                    }

                    statusRow(label: "Shield requested", value: manager.isShielded ? "ON — verify on device" : "OFF")

                    Divider().background(Color.gray)

                    statusRow(label: "Finished it (unlocked)", value: "\(manager.completedCount)")
                    statusRow(label: "Ignored (gave in anyway)", value: "\(manager.ignoreCount)")
                    statusRow(label: "Current streak 🔥", value: "\(manager.currentStreak)")
                    Text("Updates when you come back to FocusUp after hitting a block screen.")
                        .font(.caption2)
                        .foregroundStyle(.gray)

                    if let error = manager.lastError {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }

                    Text("This is a feasibility spike, not the FocusUp app. It proves authorization, selection, and shield apply/clear on this device.")
                        .font(.footnote)
                        .foregroundStyle(.gray)
                }
                .padding(24)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            manager.refreshAuthorizationStatus()
            manager.refreshStats()
            manager.refreshTasks()
            syncIntervalTextFromManager()
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
        .overlay {
            if let streak = manager.justCompletedStreak {
                StreakCelebrationView(streak: streak) {
                    manager.dismissStreakAnimation()
                }
            }
        }
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
        case .approved: return "Approved"
        @unknown default: return "Unknown"
        }
    }

    private func statusRow(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.gray)
            Spacer()
            Text(value).foregroundStyle(.white).bold()
        }
    }
}

struct SpikeButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(color.opacity(configuration.isPressed ? 0.6 : 1))
            .foregroundStyle(.white)
            .bold()
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack { HomeView() }
}
