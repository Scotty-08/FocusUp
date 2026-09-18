import SwiftUI
import FamilyControls
import ManagedSettingsUI

struct ContentView: View {
    @StateObject private var manager = FamilyControlsManager.shared
    @StateObject private var auth = AuthManager.shared
    @State private var isPickerPresented = false
    @Environment(\.scenePhase) private var scenePhase

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

                    if !manager.selection.applicationTokens.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Task to unlock these apps:")
                                .foregroundStyle(.gray)
                            TextField("e.g. Apply to 3 internships", text: $manager.goalText)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(Color(white: 0.15))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Text("Shown on the block screen. \"Override\" lets the user skip it without proof (self-reported, per spec default).")
                                .font(.caption2)
                                .foregroundStyle(.gray)
                        }
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
            if manager.authorizationStatus == .notDetermined {
                Task { await manager.requestAuthorization() }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                manager.refreshAuthorizationStatus()
                manager.refreshStats()
            }
        }
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

private struct SpikeButtonStyle: ButtonStyle {
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
    ContentView()
}
