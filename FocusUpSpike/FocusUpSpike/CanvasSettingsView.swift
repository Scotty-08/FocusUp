import SwiftUI

/// Connect/disconnect Canvas and trigger a manual sync. Presented as a
/// sheet from TasksView's toolbar (see the graduation-cap button there).
/// Same HUD panel language as QuestDetailView/GroupDetailView -- no new
/// visual style introduced for this screen.
struct CanvasSettingsView: View {
    @StateObject private var canvas = CanvasClient.shared
    @StateObject private var manager = FamilyControlsManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var domainField = ""
    @State private var tokenField = ""
    @State private var isConnecting = false
    @State private var connectError: String?

    var body: some View {
        ZStack {
            PlayerBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Canvas")
                        .font(.system(size: 19, weight: .heavy))
                        .foregroundStyle(PlayerTheme.textPrimary)

                    if canvas.isConnected {
                        connectedSection
                    } else {
                        connectForm
                    }
                }
                .padding(20)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Connected

    private var connectedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HUDLabel(text: "Connected")
                Text(canvas.domain ?? "")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PlayerTheme.textPrimary)
                Text(syncStatusLine)
                    .font(.system(size: 11))
                    .foregroundStyle(PlayerTheme.textMuted)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .hudPanel()

            Text("Upcoming assignments from every active course sync into your Quest Log automatically whenever the app opens. FocusUp only reads due dates and titles -- it never submits work or touches a grade.")
                .font(.system(size: 11))
                .foregroundStyle(PlayerTheme.textMuted)

            if let error = canvas.lastSyncError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(PlayerTheme.danger)
            }

            Button {
                Task { await canvas.sync(into: manager) }
            } label: {
                HStack(spacing: 6) {
                    if canvas.isSyncing {
                        ProgressView().tint(PlayerTheme.textPrimary)
                    }
                    Text(canvas.isSyncing ? "SYNCING…" : "SYNC NOW")
                }
                .font(.system(size: 13, weight: .heavy))
                .tracking(1)
                .foregroundStyle(PlayerTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
            }
            .buttonStyle(.plain)
            .hudPanel()
            .disabled(canvas.isSyncing)
            .opacity(canvas.isSyncing ? 0.6 : 1)

            Button {
                canvas.disconnect()
            } label: {
                Text("DISCONNECT")
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(PlayerTheme.danger)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
            }
            .buttonStyle(.plain)
            .overlay(Rectangle().strokeBorder(PlayerTheme.danger.opacity(0.5), lineWidth: 1))
        }
    }

    private var syncStatusLine: String {
        guard let last = canvas.lastSyncedAt else { return "Not synced yet" }
        return "Last synced \(last.formatted(.relative(presentation: .named)))"
    }

    // MARK: - Connect

    private var connectForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Connect your school's Canvas to automatically add a quest for every upcoming assignment. Works with any school on Canvas, not just one -- FocusUp only needs your Canvas domain and a personal access token.")
                .font(.system(size: 12))
                .foregroundStyle(PlayerTheme.textMuted)

            VStack(alignment: .leading, spacing: 6) {
                HUDLabel(text: "Canvas domain")
                TextField("", text: $domainField, prompt: Text("e.g. iowastate.instructure.com").foregroundStyle(PlayerTheme.textMuted))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .foregroundStyle(PlayerTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .hudPanel()
            }

            VStack(alignment: .leading, spacing: 6) {
                HUDLabel(text: "Access token")
                SecureField("", text: $tokenField, prompt: Text("Paste your token").foregroundStyle(PlayerTheme.textMuted))
                    .foregroundStyle(PlayerTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .hudPanel()
            }

            Text("Generate one in Canvas under Account -> Settings -> \"New Access Token\". It's stored on this device only, in the Keychain, never sent anywhere but Canvas itself.")
                .font(.system(size: 10))
                .foregroundStyle(PlayerTheme.textMuted)

            if let connectError {
                Text(connectError)
                    .font(.system(size: 11))
                    .foregroundStyle(PlayerTheme.danger)
            }

            Button {
                connect()
            } label: {
                HStack(spacing: 6) {
                    if isConnecting {
                        ProgressView().tint(PlayerTheme.bg)
                    }
                    Text(isConnecting ? "CONNECTING…" : "CONNECT")
                }
                .font(.system(size: 13, weight: .heavy))
                .tracking(1)
                .foregroundStyle(PlayerTheme.bg)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(PlayerTheme.cyan)
            }
            .buttonStyle(.plain)
            .shadow(color: PlayerTheme.cyan.opacity(0.18), radius: 12)
            .disabled(isConnecting || domainField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || tokenField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity((domainField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || tokenField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? 0.4 : 1)
        }
    }

    private func connect() {
        connectError = nil
        isConnecting = true
        Task {
            do {
                try await canvas.connect(domain: domainField, token: tokenField)
                tokenField = ""
                await canvas.sync(into: manager)
                isConnecting = false
            } catch {
                connectError = (error as? CanvasError)?.errorDescription ?? error.localizedDescription
                isConnecting = false
            }
        }
    }
}

#Preview {
    CanvasSettingsView()
}
