import SwiftUI
import AuthenticationServices

/// The Friends tab: your handle, add-by-username, incoming requests,
/// cheers you've received, and a Friends / Leaderboard switch.
///
/// Everything here needs the FocusUp server. When it isn't configured or
/// you aren't connected, this screen says so and offers to connect --
/// nothing else in the app depends on it.
struct FriendsView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case friends = "Friends"
        case leaderboard = "Leaderboard"
        var id: String { rawValue }
    }

    @StateObject private var store = FriendsStore.shared
    @StateObject private var backend = BackendClient.shared

    @State private var mode: Mode = .friends
    @State private var metric: LeaderboardMetric = .level
    @State private var addUsername = ""
    @State private var confirmRemove: FriendRow?

    var body: some View {
        ZStack {
            PlayerBackground(topRight: false)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HUDLabel(text: "[ Party ]", size: 10)
                            Text("Friends")
                                .font(.system(size: 24, weight: .heavy))
                                .foregroundStyle(PlayerTheme.textPrimary)
                        }
                        Spacer()
                        if store.isLoading {
                            ProgressView().tint(PlayerTheme.cyan)
                        }
                    }

                    if !BackendConfig.isConfigured {
                        notice("Friends are offline: this build isn't connected to the FocusUp server yet.")
                    } else if !backend.isConnected {
                        ConnectCard()
                    } else {
                        connectedContent
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .refreshable {
                await store.syncProfile()
                await store.refresh()
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarHidden(true)
        .task {
            await store.syncProfile()
            await store.refresh()
        }
        .confirmationDialog(
            "Remove this friend?",
            isPresented: Binding(get: { confirmRemove != nil }, set: { if !$0 { confirmRemove = nil } }),
            presenting: confirmRemove
        ) { row in
            Button("Remove @\(row.username)", role: .destructive) {
                Task { await store.remove(row) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Connected

    @ViewBuilder
    private var connectedContent: some View {
        handleCard
        addFriendCard

        if let message = store.statusMessage {
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(PlayerTheme.gold)
        }

        if store.unseenCheerCount > 0 {
            cheersInbox
        }

        if !store.incoming.isEmpty {
            requestsSection
        }

        Picker("", selection: $mode) {
            ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)

        switch mode {
        case .friends: friendsList
        case .leaderboard: leaderboard
        }
    }

    private var handleCard: some View {
        HStack(spacing: 12) {
            AvatarSwatch(config: CharacterStore.shared.avatar)
            VStack(alignment: .leading, spacing: 3) {
                HUDLabel(text: "Your username", size: 9)
                Text(store.myUsername.map { "@\($0)" } ?? "Setting up...")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(PlayerTheme.textPrimary)
                Text("Friends add you with this.")
                    .font(.system(size: 10))
                    .foregroundStyle(PlayerTheme.textMuted)
            }
            Spacer()
        }
        .padding(14)
        .hudPanel()
    }

    private var addFriendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HUDLabel(text: "Add a friend", size: 10)
            HStack(spacing: 10) {
                TextField("", text: $addUsername, prompt: Text("@username").foregroundStyle(PlayerTheme.textMuted))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(PlayerTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .overlay(Rectangle().strokeBorder(PlayerTheme.cyanDim, lineWidth: 1))
                    .submitLabel(.send)
                    .onSubmit(sendRequest)

                let canSend = !addUsername.trimmingCharacters(in: .whitespaces).isEmpty
                Button(action: sendRequest) {
                    Text("ADD")
                        .font(.system(size: 12, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(PlayerTheme.bg)
                        .padding(.horizontal, 18)
                        .frame(height: 42)
                        .background(PlayerTheme.cyan)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .opacity(canSend ? 1 : 0.4)
            }
        }
        .padding(14)
        .hudPanel()
    }

    private func sendRequest() {
        let handle = addUsername
        addUsername = ""
        Task { await store.sendRequest(toUsername: handle) }
    }

    private var cheersInbox: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HUDLabel(text: "Cheers for you", size: 10, color: PlayerTheme.gold)
                Spacer()
                Button {
                    Task { await store.markCheersSeen() }
                } label: {
                    Text("MARK READ")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(PlayerTheme.gold)
                }
                .buttonStyle(.plain)
            }
            ForEach(store.cheers.filter { !$0.seen }.prefix(5)) { cheer in
                HStack(spacing: 8) {
                    Image(systemName: "hands.clap.fill")
                        .foregroundStyle(PlayerTheme.gold)
                    Text("@\(cheer.senderUsername): \(cheer.message)")
                        .font(.system(size: 13))
                        .foregroundStyle(PlayerTheme.textPrimary)
                    Spacer()
                }
            }
        }
        .padding(14)
        .hudPanel(borderColor: PlayerTheme.gold.opacity(0.5), cornerAccent: PlayerTheme.gold)
    }

    private var requestsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HUDLabel(text: "Friend requests", size: 10)
            ForEach(store.incoming) { row in
                HStack(spacing: 10) {
                    AvatarSwatch(config: row.avatarConfig)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(PlayerTheme.textPrimary)
                        Text("@\(row.username) \u{00B7} LV \(row.level)")
                            .font(.system(size: 10))
                            .foregroundStyle(PlayerTheme.textMuted)
                    }
                    Spacer()
                    smallButton("ACCEPT", filled: true) { Task { await store.accept(row) } }
                    smallButton("DECLINE", filled: false) { Task { await store.remove(row) } }
                }
                .padding(10)
                .hudPanel()
            }
        }
    }

    // MARK: - Friends list

    @ViewBuilder
    private var friendsList: some View {
        if store.friends.isEmpty {
            notice("No friends yet. Add someone by username above -- once they accept, they show up here and on the leaderboard.")
        } else {
            VStack(spacing: 8) {
                ForEach(store.friends) { row in
                    HStack(spacing: 10) {
                        AvatarSwatch(config: row.avatarConfig)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(row.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(PlayerTheme.textPrimary)
                            Text("@\(row.username)")
                                .font(.system(size: 10))
                                .foregroundStyle(PlayerTheme.textMuted)
                            HStack(spacing: 10) {
                                Text("LV \(row.level)")
                                    .foregroundStyle(PlayerTheme.cyan)
                                Label("\(row.streak)", systemImage: "flame.fill")
                                    .foregroundStyle(PlayerTheme.gold)
                                Text("\(row.completedCount) cleared")
                                    .foregroundStyle(PlayerTheme.textMuted)
                            }
                            .font(.system(size: 10, weight: .bold))
                        }
                        Spacer()
                        Menu {
                            ForEach(FriendsStore.cheerPresets, id: \.self) { message in
                                Button(message) { Task { await store.cheer(row, message: message) } }
                            }
                            Divider()
                            Button("Remove friend", role: .destructive) { confirmRemove = row }
                        } label: {
                            Text("CHEER")
                                .font(.system(size: 11, weight: .heavy))
                                .tracking(1)
                                .foregroundStyle(PlayerTheme.gold)
                                .padding(.horizontal, 12)
                                .frame(height: 34)
                                .overlay(Rectangle().strokeBorder(PlayerTheme.gold.opacity(0.6), lineWidth: 1))
                        }
                    }
                    .padding(10)
                    .hudPanel()
                }
            }
        }

        if !store.outgoing.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HUDLabel(text: "Waiting on", size: 10, color: PlayerTheme.textMuted)
                ForEach(store.outgoing) { row in
                    HStack {
                        Text("@\(row.username)")
                            .font(.system(size: 13))
                            .foregroundStyle(PlayerTheme.textMuted)
                        Spacer()
                        smallButton("CANCEL", filled: false) { Task { await store.remove(row) } }
                    }
                }
            }
        }
    }

    // MARK: - Leaderboard

    private var leaderboard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("", selection: $metric) {
                ForEach(LeaderboardMetric.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            let entries = store.leaderboard(by: metric)
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(index == 0 ? PlayerTheme.gold : PlayerTheme.textMuted)
                        .frame(width: 26)
                    AvatarSwatch(config: entry.avatar)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(entry.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(PlayerTheme.textPrimary)
                            if entry.isMe {
                                Text("YOU")
                                    .font(.system(size: 9, weight: .heavy))
                                    .foregroundStyle(PlayerTheme.bg)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(PlayerTheme.cyan)
                            }
                        }
                        Text("@\(entry.username)")
                            .font(.system(size: 10))
                            .foregroundStyle(PlayerTheme.textMuted)
                    }
                    Spacer()
                    Text(metric.display(for: entry))
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(PlayerTheme.cyan)
                }
                .padding(10)
                .hudPanel(
                    borderColor: entry.isMe ? PlayerTheme.cyan.opacity(0.8) : PlayerTheme.cyanDim,
                    cornerAccent: PlayerTheme.cyan
                )
            }

            if entries.count <= 1 {
                notice("Add a friend to start a leaderboard.")
            }
        }
    }

    // MARK: - Small pieces

    private func notice(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(PlayerTheme.textMuted)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .hudPanel()
    }

    private func smallButton(_ label: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(filled ? PlayerTheme.bg : PlayerTheme.textMuted)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(filled ? PlayerTheme.cyan : Color.white.opacity(0.06))
        }
        .buttonStyle(.plain)
    }
}

/// Shown when the server is configured but there's no account session --
/// e.g. the user signed in offline, or with the preview-only email path,
/// or their session was revoked. Connects with Apple or email/password.
private struct ConnectCard: View {
    @State private var email = ""
    @State private var password = ""
    @State private var errorText: String?
    @State private var isBusy = false
    @State private var appleNonce = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HUDLabel(text: "Connect your account", size: 10)
            Text("Sign in to your FocusUp account to add friends and appear on leaderboards. Your quests and app blocking keep working either way.")
                .font(.system(size: 12))
                .foregroundStyle(PlayerTheme.textMuted)

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
                let raw = AppleNonce.random()
                appleNonce = raw
                request.nonce = AppleNonce.sha256(raw)
            } onCompletion: { result in
                guard case .success(let results) = result,
                      let credential = results.credential as? ASAuthorizationAppleIDCredential,
                      let tokenData = credential.identityToken,
                      let token = String(data: tokenData, encoding: .utf8) else {
                    errorText = "Sign in with Apple didn't complete."
                    return
                }
                let nonce = appleNonce
                run { try await BackendClient.shared.signInWithApple(idToken: token, rawNonce: nonce) }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 46)

            field("Email", text: $email, secure: false)
            field("Password", text: $password, secure: true)

            HStack(spacing: 10) {
                action("SIGN IN") { try await BackendClient.shared.signIn(email: trimmedEmail, password: password) }
                action("CREATE ACCOUNT") { try await BackendClient.shared.signUp(email: trimmedEmail, password: password) }
            }

            if let errorText {
                Text(errorText)
                    .font(.system(size: 11))
                    .foregroundStyle(PlayerTheme.danger)
            }
        }
        .padding(14)
        .hudPanel()
    }

    private var trimmedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func field(_ placeholder: String, text: Binding<String>, secure: Bool) -> some View {
        Group {
            if secure {
                SecureField("", text: text, prompt: Text(placeholder).foregroundStyle(PlayerTheme.textMuted))
            } else {
                TextField("", text: text, prompt: Text(placeholder).foregroundStyle(PlayerTheme.textMuted))
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
            }
        }
        .foregroundStyle(PlayerTheme.textPrimary)
        .padding(.horizontal, 12)
        .frame(height: 42)
        .overlay(Rectangle().strokeBorder(PlayerTheme.cyanDim, lineWidth: 1))
    }

    private func action(_ label: String, _ work: @escaping () async throws -> Void) -> some View {
        Button {
            guard !trimmedEmail.isEmpty, !password.isEmpty else {
                errorText = "Enter an email and password."
                return
            }
            run(work)
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .heavy))
                .tracking(1)
                .foregroundStyle(PlayerTheme.cyan)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .overlay(Rectangle().strokeBorder(PlayerTheme.cyanDim, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .opacity(isBusy ? 0.5 : 1)
    }

    private func run(_ work: @escaping () async throws -> Void) {
        errorText = nil
        isBusy = true
        Task { @MainActor in
            defer { isBusy = false }
            do {
                try await work()
                await FriendsStore.shared.syncProfile()
                await FriendsStore.shared.refresh()
            } catch {
                errorText = error.localizedDescription
            }
        }
    }
}

#Preview {
    NavigationStack { FriendsView() }
}
