import SwiftUI
import FamilyControls
import ManagedSettings
import ManagedSettingsUI

/// Create/edit in one screen, reusing PlayerTheme's HUD panel language --
/// no new visual style. `existingGroup == nil` means create; otherwise
/// every field seeds from the group being edited and Save calls
/// `manager.updateGroup`, which re-activates enforcement from scratch
/// (old store cleared, new rule applied) so switching Block<->Limit or
/// changing apps never leaves stale enforcement behind.
struct GroupDetailView: View {
    @StateObject private var manager = FamilyControlsManager.shared
    @Environment(\.dismiss) private var dismiss

    let existingGroup: AppGroup?
    /// Optional coaching line shown above the form -- used by first-run
    /// onboarding to walk a brand-new player through their first group.
    let guidedHint: String?

    @State private var name: String
    @State private var selection: FamilyActivitySelection
    @State private var ruleKind: RuleKind
    @State private var hasDailyLimit: Bool
    @State private var dailyBudgetMinutes: Int
    @State private var windows: [ScheduleWindow]
    @State private var reminderIntervalMinutes: Int
    @State private var checkInOnOpen: Bool
    @State private var reshieldMinutes: Int
    @State private var isPickerPresented = false
    @State private var showDeleteConfirm = false

    init(existingGroup: AppGroup?, guidedHint: String? = nil) {
        self.existingGroup = existingGroup
        self.guidedHint = guidedHint
        let rule = existingGroup?.rule
        _name = State(initialValue: existingGroup?.name ?? "")
        _selection = State(initialValue: existingGroup?.selection ?? FamilyActivitySelection())
        _ruleKind = State(initialValue: rule?.kind ?? .block)
        _hasDailyLimit = State(initialValue: rule?.dailyBudgetMinutes != nil)
        _dailyBudgetMinutes = State(initialValue: rule?.dailyBudgetMinutes ?? 30)
        _windows = State(initialValue: rule?.windows ?? [])
        _reminderIntervalMinutes = State(initialValue: rule?.reminderIntervalMinutes ?? 5)
        _checkInOnOpen = State(initialValue: rule?.checkInOnOpen ?? false)
        _reshieldMinutes = State(initialValue: rule?.effectiveReshieldMinutes ?? GroupRule.minReshieldMinutes)
    }

    var body: some View {
        ZStack {
            PlayerBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(existingGroup == nil ? "New Group" : "Edit Group")
                        .font(.system(size: 19, weight: .heavy))
                        .foregroundStyle(PlayerTheme.textPrimary)

                    if let guidedHint {
                        Text(guidedHint)
                            .font(.system(size: 12))
                            .foregroundStyle(PlayerTheme.cyan)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .hudPanel()
                    }

                    nameField
                    appsSection
                    ruleSection

                    if let error = manager.lastError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(PlayerTheme.danger)
                    }

                    actionButtons
                }
                .padding(20)
            }
        }
        .preferredColorScheme(.dark)
        .confirmationDialog(
            "Delete this group? Its apps become accessible immediately.",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Group", role: .destructive) {
                if let existingGroup {
                    manager.deleteGroup(existingGroup.id)
                }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HUDLabel(text: "Group Name")
            TextField("", text: $name, prompt: Text("e.g. Socials").foregroundStyle(PlayerTheme.textMuted))
                .foregroundStyle(PlayerTheme.textPrimary)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .hudPanel()
        }
    }

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HUDLabel(text: "Apps")
                Spacer()
                Button {
                    isPickerPresented = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("CHOOSE")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(PlayerTheme.cyan)
                }
                .buttonStyle(.plain)
                .disabled(manager.authorizationStatus != .approved)
                .familyActivityPicker(isPresented: $isPickerPresented, selection: $selection)
            }

            if selection.applicationTokens.isEmpty {
                Text("None selected yet.")
                    .font(.system(size: 12))
                    .foregroundStyle(PlayerTheme.textMuted)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(selection.applicationTokens), id: \.self) { token in
                        HStack {
                            Label(token)
                                .labelStyle(.titleAndIcon)
                                .font(.system(size: 12))
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(PlayerTheme.cyan.opacity(0.08))
                        .overlay(Rectangle().strokeBorder(PlayerTheme.cyanDim, lineWidth: 1))
                        .foregroundStyle(PlayerTheme.textPrimary)
                    }
                }
            }
        }
    }

    private var ruleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HUDLabel(text: "Rule")
            HStack(spacing: 10) {
                ruleKindButton(.block, title: "Block", subtitle: "Fully inaccessible until you complete a quest.")
                ruleKindButton(.limit, title: "Limit", subtitle: "Accessible, with reminders while you use it, an optional first-open check-in, and an optional daily cap.")
            }

            if ruleKind == .limit {
                limitOptions
            }
        }
        .padding(14)
        .hudPanel()
    }

    private func ruleKindButton(_ kind: RuleKind, title: String, subtitle: String) -> some View {
        let selected = ruleKind == kind
        return Button {
            ruleKind = kind
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(selected ? PlayerTheme.bg : PlayerTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(selected ? PlayerTheme.bg.opacity(0.7) : PlayerTheme.textMuted)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? PlayerTheme.cyan : Color.white.opacity(0.05))
        }
        .buttonStyle(.plain)
    }

    private var limitOptions: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Toggle(isOn: $hasDailyLimit.animation()) {
                    Text("Daily limit")
                        .font(.system(size: 11))
                        .foregroundStyle(PlayerTheme.textMuted)
                }
                .toggleStyle(.switch)
                .tint(PlayerTheme.cyan)

                if hasDailyLimit {
                    numberField(label: "Daily budget", value: $dailyBudgetMinutes, suffix: "min/day", range: 5...480)
                } else {
                    Text("Apps stay accessible with no automatic lockout -- just the reminders (and optional first-open check-in) below.")
                        .font(.system(size: 10))
                        .foregroundStyle(PlayerTheme.textMuted)
                }
            }

            windowsEditor

            reminderStyleSection
        }
    }

    /// Limit-mode check-ins. The while-you-use-it reminder is ALWAYS on
    /// (no toggle); the check-in when the user opens the app is an
    /// optional extra (rule.reshieldMinutes non-nil). iOS can't detect
    /// the user leaving another app, so "on open" is approximated by a
    /// cooldown: after tapping through, it re-arms after
    /// `reshieldMinutes` (platform minimum 15).
    private var reminderStyleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("WHILE YOU USE IT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PlayerTheme.textMuted)
                numberField(label: "Remind every", value: $reminderIntervalMinutes, suffix: "min of use", range: 1...60)
                Text("Always on. A dismissable reminder that pops up while you're using the app -- never a lock, unless the daily limit above runs out.")
                    .font(.system(size: 10))
                    .foregroundStyle(PlayerTheme.textMuted)
            }

            VStack(alignment: .leading, spacing: 6) {
                Toggle(isOn: $checkInOnOpen.animation()) {
                    Text("Check-in when I first open it")
                        .font(.system(size: 11))
                        .foregroundStyle(PlayerTheme.textMuted)
                }
                .toggleStyle(.switch)
                .tint(PlayerTheme.cyan)

                if checkInOnOpen {
                    numberField(label: "Check in again after", value: $reshieldMinutes, suffix: "min", range: GroupRule.minReshieldMinutes...480)
                    Text("Optional. The check-in shows only when you first open the app, never while you're using it -- tap through to get in. After you do, it waits this long before it can check in on your next open. iOS can't tell when you leave an app, so 15 minutes is the shortest wait.")
                        .font(.system(size: 10))
                        .foregroundStyle(PlayerTheme.textMuted)
                }
            }
        }
    }

    /// Typable numeric entry (as opposed to a tap-to-increment Stepper).
    /// Clamps to the top of `range` as soon as a keystroke parses above
    /// it -- an empty or partially-typed field doesn't push anything to
    /// the binding yet, so ordinary typing is unaffected; only a value
    /// that actually lands out of range snaps back.
    private func numberField(label: String, value: Binding<Int>, suffix: String, range: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(PlayerTheme.textMuted)
            HStack(spacing: 8) {
                TextField("", value: value, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(PlayerTheme.textPrimary)
                    .frame(width: 64, height: 36)
                    .overlay(Rectangle().strokeBorder(PlayerTheme.cyanDim, lineWidth: 1))
                    .onChange(of: value.wrappedValue) { _, newValue in
                        // Only the upper bound snaps while typing -- clamping
                        // to the lower bound here would fight the user
                        // (typing "30" into a 15-minimum field would jump
                        // to 15 after the "3"). Lower bounds are enforced
                        // in save().
                        if newValue > range.upperBound { value.wrappedValue = range.upperBound }
                    }
                Text(suffix)
                    .font(.system(size: 11))
                    .foregroundStyle(PlayerTheme.textMuted)
            }
        }
    }

    /// Available regardless of whether a daily limit is set -- a window
    /// always means fully free, no check-ins, no budget tracking. With a
    /// daily limit, they're exceptions carved out of the budget; without
    /// one, they're just extra-protected quiet time on top of the
    /// always-accessible-with-check-ins default.
    private var windowsEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FREE-ACCESS WINDOWS")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(PlayerTheme.textMuted)
            Text(hasDailyLimit
                 ? "No limits, reminders or check-ins during these windows, regardless of the budget above. Outside them, the budget tracks separately in each remaining gap -- more windows means more separately-resetting budgets, not one shared total."
                 : "No reminders or check-ins during these windows. Outside them, the normal reminders apply.")
                .font(.system(size: 10))
                .foregroundStyle(PlayerTheme.textMuted)

            ForEach($windows) { $window in
                HStack(spacing: 12) {
                    DatePicker("From", selection: $window.startDate, displayedComponents: .hourAndMinute)
                    DatePicker("To", selection: $window.endDate, displayedComponents: .hourAndMinute)
                    Button {
                        windows.removeAll { $0.id == window.id }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(PlayerTheme.danger)
                    }
                    .buttonStyle(.plain)
                }
                .font(.system(size: 12))
                .foregroundStyle(PlayerTheme.textPrimary)
                .colorScheme(.dark)
            }

            if windows.count < GroupRule.maxWindows {
                Button {
                    windows.append(ScheduleWindow(startHour: 10, startMinute: 0, endHour: 12, endMinute: 0))
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("ADD WINDOW")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(PlayerTheme.cyan)
                }
                .buttonStyle(.plain)
            } else {
                Text("Up to \(GroupRule.maxWindows) windows.")
                    .font(.system(size: 10))
                    .foregroundStyle(PlayerTheme.textMuted)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                save()
            } label: {
                Text("SAVE GROUP")
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(PlayerTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
            }
            .buttonStyle(.plain)
            .hudPanel()
            .shadow(color: PlayerTheme.cyan.opacity(0.18), radius: 12)

            if existingGroup != nil {
                Button {
                    showDeleteConfirm = true
                } label: {
                    Text("DELETE")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(PlayerTheme.danger)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                }
                .buttonStyle(.plain)
                .overlay(Rectangle().strokeBorder(PlayerTheme.danger.opacity(0.4), lineWidth: 1))
            }
        }
    }

    private func save() {
        let isLimit = ruleKind == .limit
        let rule = GroupRule(
            kind: ruleKind,
            dailyBudgetMinutes: (isLimit && hasDailyLimit) ? max(dailyBudgetMinutes, 5) : nil,
            windows: isLimit ? windows : [],
            reminderIntervalMinutes: max(reminderIntervalMinutes, 1),
            reshieldMinutes: (isLimit && checkInOnOpen) ? max(reshieldMinutes, GroupRule.minReshieldMinutes) : nil
        )
        if let existingGroup {
            manager.updateGroup(AppGroup(
                id: existingGroup.id,
                name: name,
                selection: selection,
                rule: rule,
                createdAt: existingGroup.createdAt
            ))
        } else {
            manager.createGroup(name: name, selection: selection, rule: rule)
        }
        if manager.lastError == nil {
            dismiss()
        }
    }

}

/// Bridges ScheduleWindow's stored hour/minute ints to Date, purely for
/// binding to DatePicker in the windows editor above -- the model itself
/// stays hour/minute-based (see GroupStore.swift) since that's all
/// DeviceActivitySchedule actually needs; this is a UI-only convenience,
/// not shared with the extensions.
private extension ScheduleWindow {
    var startDate: Date {
        get { Calendar.current.date(bySettingHour: startHour, minute: startMinute, second: 0, of: Date()) ?? Date() }
        set {
            let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            startHour = c.hour ?? startHour
            startMinute = c.minute ?? startMinute
        }
    }

    var endDate: Date {
        get { Calendar.current.date(bySettingHour: endHour, minute: endMinute, second: 0, of: Date()) ?? Date() }
        set {
            let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            endHour = c.hour ?? endHour
            endMinute = c.minute ?? endMinute
        }
    }
}

#Preview {
    GroupDetailView(existingGroup: nil)
}
