import SwiftUI
import FamilyControls
import ManagedSettings
import ManagedSettingsUI

/// Create/edit in one screen, reusing HunterTheme's HUD panel language --
/// no new visual style. `existingGroup == nil` means create; otherwise
/// every field seeds from the group being edited and Save calls
/// `manager.updateGroup`, which re-activates enforcement from scratch
/// (old store cleared, new rule applied) so switching Block<->Limit or
/// changing apps never leaves stale enforcement behind.
struct GroupDetailView: View {
    @StateObject private var manager = FamilyControlsManager.shared
    @Environment(\.dismiss) private var dismiss

    let existingGroup: AppGroup?

    @State private var name: String
    @State private var selection: FamilyActivitySelection
    @State private var ruleKind: RuleKind
    @State private var dailyBudgetMinutes: Int
    @State private var hasWindow: Bool
    @State private var windowStart: Date
    @State private var windowEnd: Date
    @State private var reminderIntervalMinutes: Int
    @State private var taskID: UUID?
    @State private var isPickerPresented = false
    @State private var showDeleteConfirm = false

    init(existingGroup: AppGroup?) {
        self.existingGroup = existingGroup
        let rule = existingGroup?.rule
        let window = rule?.window
        _name = State(initialValue: existingGroup?.name ?? "")
        _selection = State(initialValue: existingGroup?.selection ?? FamilyActivitySelection())
        _ruleKind = State(initialValue: rule?.kind ?? .block)
        _dailyBudgetMinutes = State(initialValue: rule?.dailyBudgetMinutes ?? 30)
        _hasWindow = State(initialValue: window != nil)
        _windowStart = State(initialValue: Self.date(hour: window?.startHour ?? 10, minute: window?.startMinute ?? 0))
        _windowEnd = State(initialValue: Self.date(hour: window?.endHour ?? 12, minute: window?.endMinute ?? 0))
        _reminderIntervalMinutes = State(initialValue: rule?.reminderIntervalMinutes ?? 5)
        _taskID = State(initialValue: existingGroup?.taskID)
    }

    var body: some View {
        ZStack {
            HunterBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(existingGroup == nil ? "New Group" : "Edit Group")
                        .font(.system(size: 19, weight: .heavy))
                        .foregroundStyle(HunterTheme.textPrimary)

                    nameField
                    appsSection
                    ruleSection
                    taskSection

                    if let error = manager.lastError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(HunterTheme.danger)
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
            TextField("", text: $name, prompt: Text("e.g. Socials").foregroundStyle(HunterTheme.textMuted))
                .foregroundStyle(HunterTheme.textPrimary)
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
                    .foregroundStyle(HunterTheme.cyan)
                }
                .buttonStyle(.plain)
                .disabled(manager.authorizationStatus != .approved)
                .familyActivityPicker(isPresented: $isPickerPresented, selection: $selection)
            }

            if selection.applicationTokens.isEmpty {
                Text("None selected yet.")
                    .font(.system(size: 12))
                    .foregroundStyle(HunterTheme.textMuted)
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
                        .background(HunterTheme.cyan.opacity(0.08))
                        .overlay(Rectangle().strokeBorder(HunterTheme.cyanDim, lineWidth: 1))
                        .foregroundStyle(HunterTheme.textPrimary)
                    }
                }
            }
        }
    }

    private var ruleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HUDLabel(text: "Rule")
            HStack(spacing: 10) {
                ruleKindButton(.block, title: "Block", subtitle: "Fully inaccessible until the quest is done.")
                ruleKindButton(.limit, title: "Limit", subtitle: "Accessible with a daily cap.")
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
                    .foregroundStyle(selected ? HunterTheme.bg : HunterTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(selected ? HunterTheme.bg.opacity(0.7) : HunterTheme.textMuted)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? HunterTheme.cyan : Color.white.opacity(0.05))
        }
        .buttonStyle(.plain)
    }

    private var limitOptions: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("DAILY BUDGET: \(dailyBudgetMinutes) MIN")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(HunterTheme.textMuted)
                Stepper("", value: $dailyBudgetMinutes, in: 5...480, step: 5)
                    .labelsHidden()
                    .colorScheme(.dark)
            }

            VStack(alignment: .leading, spacing: 6) {
                Toggle(isOn: $hasWindow.animation()) {
                    Text("Free access window")
                        .font(.system(size: 11))
                        .foregroundStyle(HunterTheme.textMuted)
                }
                .toggleStyle(.switch)
                .tint(HunterTheme.cyan)

                if hasWindow {
                    HStack(spacing: 16) {
                        DatePicker("From", selection: $windowStart, displayedComponents: .hourAndMinute)
                        DatePicker("To", selection: $windowEnd, displayedComponents: .hourAndMinute)
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(HunterTheme.textPrimary)
                    .colorScheme(.dark)
                    Text("No limits apply during this window, regardless of the daily budget above. Outside it, the budget tracks separately before and after the window.")
                        .font(.system(size: 10))
                        .foregroundStyle(HunterTheme.textMuted)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("REMIND EVERY \(reminderIntervalMinutes) MIN (IF A QUEST IS LINKED)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(HunterTheme.textMuted)
                Stepper("", value: $reminderIntervalMinutes, in: 1...60, step: 1)
                    .labelsHidden()
                    .colorScheme(.dark)
            }
        }
    }

    private var taskSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HUDLabel(text: "Linked Quest")
            Text(ruleKind == .block
                 ? "This group unlocks when the chosen quest is marked done."
                 : "You'll be reminded of this quest while using this group's apps.")
                .font(.system(size: 10))
                .foregroundStyle(HunterTheme.textMuted)

            VStack(spacing: 8) {
                taskRow(title: "None", isSelected: taskID == nil) { taskID = nil }
                ForEach(manager.tasks.filter { !$0.isCompleted }) { task in
                    taskRow(title: task.title, isSelected: taskID == task.id) { taskID = task.id }
                }
            }
        }
    }

    private func taskRow(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? HunterTheme.textPrimary : HunterTheme.textMuted)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(HunterTheme.cyan)
                }
            }
            .padding(10)
            .hudPanel(
                borderColor: isSelected ? HunterTheme.cyanDim : Color.white.opacity(0.06),
                cornerAccent: isSelected ? HunterTheme.cyan : .clear
            )
        }
        .buttonStyle(.plain)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                save()
            } label: {
                Text("SAVE GROUP")
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(HunterTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
            }
            .buttonStyle(.plain)
            .hudPanel()
            .shadow(color: HunterTheme.cyan.opacity(0.18), radius: 12)

            if existingGroup != nil {
                Button {
                    showDeleteConfirm = true
                } label: {
                    Text("DELETE")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(HunterTheme.danger)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                }
                .buttonStyle(.plain)
                .overlay(Rectangle().strokeBorder(HunterTheme.danger.opacity(0.4), lineWidth: 1))
            }
        }
    }

    private func save() {
        let rule = GroupRule(
            kind: ruleKind,
            dailyBudgetMinutes: dailyBudgetMinutes,
            window: (ruleKind == .limit && hasWindow) ? windowFromPickers : nil,
            reminderIntervalMinutes: reminderIntervalMinutes
        )
        if let existingGroup {
            manager.updateGroup(AppGroup(
                id: existingGroup.id,
                name: name,
                selection: selection,
                rule: rule,
                taskID: taskID,
                createdAt: existingGroup.createdAt
            ))
        } else {
            manager.createGroup(name: name, selection: selection, rule: rule, taskID: taskID)
        }
        if manager.lastError == nil {
            dismiss()
        }
    }

    private var windowFromPickers: ScheduleWindow {
        let calendar = Calendar.current
        let startComps = calendar.dateComponents([.hour, .minute], from: windowStart)
        let endComps = calendar.dateComponents([.hour, .minute], from: windowEnd)
        return ScheduleWindow(
            startHour: startComps.hour ?? 10,
            startMinute: startComps.minute ?? 0,
            endHour: endComps.hour ?? 12,
            endMinute: endComps.minute ?? 0
        )
    }

    private static func date(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }
}

#Preview {
    GroupDetailView(existingGroup: nil)
}
