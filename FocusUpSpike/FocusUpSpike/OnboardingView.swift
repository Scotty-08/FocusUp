import SwiftUI
import FamilyControls

/// Guided first-run setup shown once, right after sign-in, gated by
/// AuthManager.hasCompletedOnboarding -- see MyApp.
///
/// The player first builds their character (name + avatar), then grants
/// the permissions the app runs on, then is walked through the two
/// things FocusUp actually needs to do anything: locking their first
/// group of distracting apps, and adding the quests that unlock it. It
/// ends on a Level 1 reveal using the same fire-aura "LEVEL UP"
/// treatment as StreakCelebrationView -- a brand new player's very
/// first level should feel like the same kind of payoff, not just the
/// end of a settings form.
///
/// hasCompletedOnboarding is only flipped true on the FINAL reveal
/// screen's "Enter FocusUp" tap, not earlier -- MyApp switches straight
/// to ContentView the instant that flag goes true, so setting it any
/// sooner would skip the reveal itself before the user ever saw it.
struct OnboardingView: View {
    private enum Step: Int, CaseIterable {
        case avatar, screenTime, notifications, firstGroup, firstQuests, reveal
    }

    private static let stepCount = 5

    @StateObject private var manager = FamilyControlsManager.shared
    @StateObject private var auth = AuthManager.shared
    @StateObject private var character = CharacterStore.shared
    @State private var step: Step = .avatar

    // Avatar / profile step.
    @State private var usernameInput = ""
    @State private var dateOfBirth = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @State private var avatarDraft = AvatarConfig.starter
    @State private var profileError: String?

    @State private var notificationsRequested = false

    // First-group step.
    @State private var showGroupSheet = false

    // First-quests step.
    @State private var newQuestTitle = ""
    @State private var newQuestPriority: TaskPriority = .medium
    @State private var newQuestHasDeadline = false
    @State private var newQuestDeadline = Date()

    var body: some View {
        ZStack {
            PlayerBackground(topRight: false)
            VStack(spacing: 0) {
                if step != .reveal {
                    progressDots
                        .padding(.top, 22)
                        .padding(.bottom, 8)
                }

                Group {
                    switch step {
                    case .avatar: avatarStep
                    case .screenTime: screenTimeStep
                    case .notifications: notificationsStep
                    case .firstGroup: firstGroupStep
                    case .firstQuests: firstQuestsStep
                    case .reveal: revealStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .id(step)
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeOut(duration: 0.25), value: step)
        .onAppear {
            // Pick up an avatar/name saved by an earlier, interrupted run.
            avatarDraft = character.avatar
        }
        .sheet(isPresented: $showGroupSheet) {
            GroupDetailView(
                existingGroup: nil,
                guidedHint: "Choose the apps that pull you off track, name the group, and keep it on Block -- they'll stay locked until you clear a quest. You can tune rules later."
            )
        }
    }

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(Step.allCases.dropLast(), id: \.self) { s in
                Capsule()
                    .fill(s.rawValue <= step.rawValue ? PlayerTheme.cyan : PlayerTheme.cyanDim)
                    .frame(width: s == step ? 22 : 8, height: 6)
            }
        }
    }

    private func stepTag(_ number: Int) -> String {
        "STEP \(number) OF \(Self.stepCount)"
    }

    // MARK: - Step 1: Create your player

    private var avatarStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 10) {
                        HUDLabel(text: stepTag(1), size: 10)
                        Text("Create Your Player")
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundStyle(PlayerTheme.textPrimary)
                        Text("This is who levels up as you clear quests.")
                            .font(.system(size: 14))
                            .foregroundStyle(PlayerTheme.textMuted)
                            .multilineTextAlignment(.center)
                    }

                    ZStack {
                        FireAura(diameter: 170)
                        PixelAvatarView(config: avatarDraft)
                            .frame(width: 96, height: 108)
                            .padding(20)
                            .background(Color(red: 0x0B / 255, green: 0x16 / 255, blue: 0x20 / 255))
                            .clipShape(PixelFrameShape(cut: 12))
                            .overlay(PixelFrameShape(cut: 12).stroke(PlayerTheme.cyan, lineWidth: 3))
                            .shadow(color: PlayerTheme.cyan.opacity(0.25), radius: 14)
                    }
                    .frame(height: 170)

                    VStack(alignment: .leading, spacing: 6) {
                        HUDLabel(text: "Player Name", size: 10)
                        TextField("", text: $usernameInput, prompt: Text("PlayerName").foregroundStyle(PlayerTheme.textMuted))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .foregroundStyle(PlayerTheme.textPrimary)
                            .padding(.horizontal, 14)
                            .frame(height: 46)
                            .hudPanel()
                    }

                    // Only slots with a real choice among the free starter
                    // options are shown -- headwear starts as just "None",
                    // and the pricier colors are all bought later with
                    // coins on the Player tab.
                    ForEach(AvatarSlot.allCases.filter { AvatarCatalog.starterItems(in: $0).count > 1 }, id: \.self) { slot in
                        optionRow(slot)
                    }

                    Text("More colors and headwear unlock on the Player tab -- buy them with the coins you earn from quests.")
                        .font(.system(size: 11))
                        .foregroundStyle(PlayerTheme.textMuted)
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 6) {
                        HUDLabel(text: "Date of Birth", size: 10)
                        DatePicker("", selection: $dateOfBirth, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(PlayerTheme.cyan)
                            .padding(.horizontal, 14)
                            .frame(height: 46, alignment: .leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .hudPanel()
                    }

                    if let profileError {
                        Text(profileError)
                            .font(.system(size: 12))
                            .foregroundStyle(PlayerTheme.danger)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 8)
            }

            primaryButton(label: "Continue") {
                let trimmed = usernameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    profileError = "Enter a player name to continue."
                    return
                }
                profileError = nil
                usernameInput = trimmed
                // Saved now (not at the end) so an interrupted run keeps it.
                character.rename(trimmed)
                character.setAvatar(avatarDraft)
                step = .screenTime
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
        }
    }

    private func optionRow(_ slot: AvatarSlot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HUDLabel(text: slot.label, size: 10)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(AvatarCatalog.starterItems(in: slot)) { item in
                        let selected = avatarDraft.itemID(for: slot) == item.id
                        Button {
                            avatarDraft = avatarDraft.setting(item.id, for: slot)
                        } label: {
                            VStack(spacing: 4) {
                                AvatarSwatch(config: avatarDraft.setting(item.id, for: slot), selected: selected)
                                Text(item.name)
                                    .font(.system(size: 9, weight: selected ? .heavy : .regular))
                                    .foregroundStyle(selected ? PlayerTheme.cyan : PlayerTheme.textMuted)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(item.name) \(slot.label)\(selected ? ", selected" : "")")
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Step 2: Screen Time

    private var screenTimeStep: some View {
        stepScaffold(
            tag: stepTag(2),
            icon: "shield.lefthalf.filled",
            headline: "Screen Time Access",
            body: "FocusUp needs Screen Time permission to lock the apps you want to focus away from, and to check in on you while you work.",
            primaryLabel: manager.authorizationStatus == .approved ? "Continue" : "Grant Access",
            primaryAction: {
                if manager.authorizationStatus == .approved {
                    step = .notifications
                } else {
                    Task { await manager.requestAuthorization() }
                }
            },
            secondaryLabel: "Skip for now",
            secondaryAction: { step = .notifications }
        )
        .onChange(of: manager.authorizationStatus) { _, newStatus in
            if newStatus == .approved {
                step = .notifications
            }
        }
    }

    // MARK: - Step 3: Notifications

    private var notificationsStep: some View {
        stepScaffold(
            tag: stepTag(3),
            icon: "bell.badge.fill",
            headline: "Stay In The Loop",
            body: "Notifications are how FocusUp taps you back in after a Quest Clear or a check-in -- extensions can't reopen the app directly, so this is the bridge.",
            primaryLabel: notificationsRequested ? "Continue" : "Enable Notifications",
            primaryAction: {
                if notificationsRequested {
                    step = .firstGroup
                } else {
                    manager.requestNotificationPermission()
                    notificationsRequested = true
                }
            },
            secondaryLabel: "Skip for now",
            secondaryAction: { step = .firstGroup }
        )
    }

    // MARK: - Step 4: First group

    private var firstGroupStep: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 8)

            iconBadge(systemName: "square.grid.2x2.fill")

            VStack(spacing: 10) {
                HUDLabel(text: stepTag(4), size: 10)
                Text("Lock Your First Group")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(PlayerTheme.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Pick the apps that pull you off track. They stay locked until you clear a quest. You can add more groups any time from Home.")
                    .font(.system(size: 14))
                    .foregroundStyle(PlayerTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            if let group = manager.groups.first {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(PlayerTheme.cyan)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(group.name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(PlayerTheme.textPrimary)
                        Text(group.summaryText())
                            .font(.system(size: 11))
                            .foregroundStyle(PlayerTheme.textMuted)
                    }
                    Spacer()
                }
                .padding(14)
                .hudPanel()
                .padding(.horizontal, 28)
            } else if manager.authorizationStatus == .denied {
                Text("Screen Time access was denied, so FocusUp can't lock any apps yet. Turn it on in Settings > Screen Time > FocusUp, then create a group from the Home tab.")
                    .font(.system(size: 12))
                    .foregroundStyle(PlayerTheme.emberOrange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            Spacer()

            VStack(spacing: 12) {
                if !manager.groups.isEmpty {
                    primaryButton(label: "Continue") { step = .firstQuests }
                } else {
                    switch manager.authorizationStatus {
                    case .approved:
                        primaryButton(label: "Choose Apps to Lock") { showGroupSheet = true }
                    case .notDetermined:
                        primaryButton(label: "Grant Screen Time Access") {
                            Task { await manager.requestAuthorization() }
                        }
                    default:
                        // Denied: iOS only asks once, so there's no way to
                        // create a group from here -- let them move on
                        // rather than trap them on this screen.
                        primaryButton(label: "Continue Without a Group") { step = .firstQuests }
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Step 5: First quests

    private var firstQuestsStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    iconBadge(systemName: "checklist")

                    VStack(spacing: 10) {
                        HUDLabel(text: stepTag(5), size: 10)
                        Text("Add Your Quests")
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundStyle(PlayerTheme.textPrimary)
                        Text("Quests are what unlock your apps. Add at least one -- three is a great start. Priority and deadline decide which quest FocusUp asks about first, and higher priority pays more EXP and coins.")
                            .font(.system(size: 14))
                            .foregroundStyle(PlayerTheme.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }

                    questForm

                    if !manager.tasks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HUDLabel(text: "\(manager.tasks.count) quest\(manager.tasks.count == 1 ? "" : "s") added", size: 10)
                            ForEach(manager.tasks) { task in
                                HStack(spacing: 10) {
                                    Circle().fill(task.priority.color).frame(width: 8, height: 8)
                                    Text(task.title)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(PlayerTheme.textPrimary)
                                        .lineLimit(1)
                                    Spacer()
                                    if let due = task.dueDate {
                                        Text(due.formatted(date: .abbreviated, time: .omitted).uppercased())
                                            .font(.system(size: 9))
                                            .foregroundStyle(PlayerTheme.textMuted)
                                    }
                                }
                                .padding(10)
                                .hudPanel()
                            }
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 8)
            }

            VStack(spacing: 6) {
                if manager.tasks.isEmpty {
                    Text("Add at least one quest to continue.")
                        .font(.system(size: 11))
                        .foregroundStyle(PlayerTheme.textMuted)
                }
                primaryButton(label: "Continue", enabled: !manager.tasks.isEmpty) {
                    step = .reveal
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
        }
    }

    private var questForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("", text: $newQuestTitle, prompt: Text("e.g. Apply to 3 internships").foregroundStyle(PlayerTheme.textMuted))
                .foregroundStyle(PlayerTheme.textPrimary)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .hudPanel()

            HStack(spacing: 8) {
                ForEach(TaskPriority.allCases, id: \.self) { level in
                    let selected = newQuestPriority == level
                    Button {
                        newQuestPriority = level
                    } label: {
                        Text(level.label.uppercased())
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(selected ? PlayerTheme.bg : level.color)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(selected ? level.color : level.color.opacity(0.12))
                            .overlay(Rectangle().strokeBorder(level.color.opacity(0.6), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                Toggle("", isOn: $newQuestHasDeadline.animation())
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(PlayerTheme.cyan)
                if newQuestHasDeadline {
                    DatePicker("", selection: $newQuestDeadline, displayedComponents: .date)
                        .labelsHidden()
                        .colorScheme(.dark)
                } else {
                    Text("Deadline (optional)")
                        .font(.system(size: 11))
                        .foregroundStyle(PlayerTheme.textMuted)
                }
                Spacer()
            }

            let canAdd = !newQuestTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            Button {
                manager.addTask(
                    title: newQuestTitle,
                    dueDate: newQuestHasDeadline ? newQuestDeadline : nil,
                    priority: newQuestPriority
                )
                newQuestTitle = ""
                newQuestPriority = .medium
                newQuestHasDeadline = false
                newQuestDeadline = Date()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("ADD QUEST")
                }
                .font(.system(size: 12, weight: .heavy))
                .tracking(1)
                .foregroundStyle(PlayerTheme.cyan)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
            }
            .buttonStyle(.plain)
            .hudPanel()
            .disabled(!canAdd)
            .opacity(canAdd ? 1 : 0.4)
        }
        .padding(14)
        .hudPanel()
    }

    // MARK: - Reveal: Level 1

    private var revealStep: some View {
        VStack {
            Spacer()

            VStack(spacing: 16) {
                Text("WELCOME, PLAYER")
                    .font(.system(size: 12, weight: .heavy))
                    .tracking(4)
                    .foregroundStyle(PlayerTheme.gold)
                    .shadow(color: PlayerTheme.gold.opacity(0.8), radius: 10)

                ZStack {
                    FireAura(diameter: 150)
                    PixelAvatarView(config: character.avatar)
                        .frame(width: 84, height: 95)
                        .padding(18)
                        .background(Color(red: 0x0B / 255, green: 0x16 / 255, blue: 0x20 / 255))
                        .clipShape(PixelFrameShape(cut: 12))
                        .overlay(PixelFrameShape(cut: 12).stroke(PlayerTheme.gold, lineWidth: 3))
                        .shadow(color: PlayerTheme.gold.opacity(0.4), radius: 14)
                }
                .frame(height: 150)

                VStack(spacing: 4) {
                    Text("\(character.level)")
                        .font(.system(size: 72, weight: .heavy))
                        .foregroundStyle(PlayerTheme.gold)
                        .shadow(color: PlayerTheme.gold.opacity(0.7), radius: 22)
                    Text("PLAYER LEVEL")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(PlayerTheme.gold.opacity(0.85))
                }

                VStack(spacing: 4) {
                    Text(character.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(PlayerTheme.textPrimary)
                    Text("has entered the System.")
                        .font(.system(size: 13))
                        .foregroundStyle(PlayerTheme.textMuted)
                    if !manager.groups.isEmpty {
                        Text("Your apps are locked -- clear a quest to unlock them.")
                            .font(.system(size: 12))
                            .foregroundStyle(PlayerTheme.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 32)

            Spacer()

            primaryButton(label: "Enter FocusUp") {
                auth.completeOnboarding(username: character.name, dateOfBirth: dateOfBirth)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Shared step layout

    private func stepScaffold(
        tag: String,
        icon: String,
        headline: String,
        body: String,
        primaryLabel: String,
        primaryAction: @escaping () -> Void,
        secondaryLabel: String,
        secondaryAction: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 22) {
            Spacer(minLength: 8)

            iconBadge(systemName: icon)

            VStack(spacing: 10) {
                HUDLabel(text: tag, size: 10)
                Text(headline)
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(PlayerTheme.textPrimary)
                    .multilineTextAlignment(.center)
                Text(body)
                    .font(.system(size: 14))
                    .foregroundStyle(PlayerTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            Spacer()

            VStack(spacing: 12) {
                primaryButton(label: primaryLabel, action: primaryAction)
                Button(action: secondaryAction) {
                    Text(secondaryLabel)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(PlayerTheme.textMuted)
                        .frame(height: 34)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
    }

    private func iconBadge(systemName: String) -> some View {
        ZStack {
            Circle()
                .fill(PlayerTheme.panelFill)
                .frame(width: 84, height: 84)
            Circle()
                .strokeBorder(PlayerTheme.cyan.opacity(0.75), lineWidth: 1.5)
                .frame(width: 84, height: 84)
                .shadow(color: PlayerTheme.cyan.opacity(0.45), radius: 10)
            Image(systemName: systemName)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(PlayerTheme.cyan)
                .shadow(color: PlayerTheme.cyan.opacity(0.6), radius: 8)
        }
    }

    private func primaryButton(label: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(PlayerTheme.bg)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(PlayerTheme.cyan)
                .clipShape(Capsule())
                .shadow(color: PlayerTheme.cyan.opacity(0.35), radius: 14)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
}

#Preview {
    OnboardingView()
}
