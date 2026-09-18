import SwiftUI

/// Presented only inside FocusUp. The system shield remains in force on entry.
struct QuestFocusView: View {
    @ObservedObject private var manager = FamilyControlsManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var confirmCompletion = false
    @State private var confirmOverride = false
    @State private var questID: UUID?
    @State private var isEnding = false

    var body: some View {
        ZStack {
            HunterBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Image(uiImage: FocusUpEmblem.image)
                            .resizable().frame(width: 48, height: 48)
                            .accessibilityLabel("FocusUp")
                        Text("FOCUSUP").font(.headline).tracking(3)
                        Spacer()
                        Button("Close", systemImage: "xmark") { dismiss() }
                            .labelStyle(.iconOnly).frame(width: 44, height: 44)
                    }
                    HUDLabel(text: "Your focus / your choice")
                        .padding(.top, 24)
                    Text("You chose\nsomething bigger.")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("This app can wait. Take the next step on your quest.")
                        .foregroundStyle(Color(red: 0.67, green: 0.76, blue: 0.81))
                    VStack(alignment: .leading, spacing: 18) {
                        HUDLabel(text: "Your active quest")
                        Text(manager.activeTask?.title ?? "Choose your next quest")
                            .font(.title2.bold())
                        Divider()
                        HStack {
                            if let date = manager.activeTask?.dueDate {
                                Text("Due \(date.formatted(date: .abbreviated, time: .omitted))")
                            } else {
                                Text("No deadline")
                            }
                            Spacer()
                            Text("Streak: \(manager.currentStreak)")
                        }.font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(22).hudPanel()
                    if let error = manager.lastError {
                        Text(error).foregroundStyle(.red).accessibilityAddTraits(.updatesFrequently)
                    }
                    VStack(spacing: 14) {
                        Button { dismiss() } label: {
                            Text("Keep focusing ↗").font(.headline)
                                .frame(maxWidth: .infinity).padding(20)
                                .background(HunterTheme.cyan).foregroundStyle(HunterTheme.bg)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        Button {
                            questID = manager.activeTask?.id
                            confirmCompletion = true
                        } label: {
                            Text("I finished this quest").font(.headline)
                                .frame(maxWidth: .infinity).padding(20)
                                .background(Color(red: 0.04, green: 0.09, blue: 0.12))
                                .overlay(Rectangle().stroke(HunterTheme.cyanDim))
                        }.disabled(manager.activeTask == nil)
                        Button("End focus early…") { confirmOverride = true }
                            .padding(12).foregroundStyle(.secondary)
                    }.buttonStyle(.plain).padding(.top, 20)
                }.padding(24)
            }
        }
        .foregroundStyle(HunterTheme.textPrimary)
        .preferredColorScheme(.dark)
        .confirmationDialog("Complete this quest and restore access?", isPresented: $confirmCompletion, titleVisibility: .visible) {
            Button("Complete quest") {
                guard !isEnding else { return }
                isEnding = true
                if manager.finishQuest(expectedID: questID) { dismiss() } else { isEnding = false }
            }
            Button("Keep focusing", role: .cancel) {}
        } message: {
            Text("This ends focus for all selected apps and stops periodic check-ins.")
        }
        .confirmationDialog("End focus without completing the quest?", isPresented: $confirmOverride, titleVisibility: .visible) {
            Button("End focus", role: .destructive) {
                guard !isEnding else { return }
                isEnding = true
                if manager.endQuestEarly() { dismiss() } else { isEnding = false }
            }
            Button("Keep focusing", role: .cancel) {}
        } message: {
            Text("Selected apps will be available again. Your quest stays unfinished.")
        }
    }
}
