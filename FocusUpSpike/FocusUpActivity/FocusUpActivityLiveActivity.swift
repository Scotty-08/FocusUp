import ActivityKit
import WidgetKit
import SwiftUI

/// The Dynamic Island / Lock Screen presentation for a FocusUp focus
/// session. Started/updated/ended from FamilyControlsManager -- see
/// startFocusActivity/updateFocusActivity/endFocusActivity there.
struct FocusUpActivityLiveActivity: Widget {
    private let bg = Color(red: 5 / 255, green: 7 / 255, blue: 8 / 255)
    private let cyan = Color(red: 62 / 255, green: 230 / 255, blue: 255 / 255)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusUpActivityAttributes.self) { context in
            // Lock screen / banner presentation.
            HStack(spacing: 12) {
                Image(systemName: "shield.fill")
                    .font(.title2)
                    .foregroundStyle(cyan)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.questTitle ?? "Focus session active")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(context.attributes.startedAt, style: .timer)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                if context.state.streak > 0 {
                    VStack(spacing: 0) {
                        Text("\(context.state.streak)")
                            .font(.title3.bold())
                            .foregroundStyle(cyan)
                        Text("STREAK")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .padding(16)
            .activityBackgroundTint(bg)
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "shield.fill")
                        .foregroundStyle(cyan)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.startedAt, style: .timer)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.questTitle ?? "Focus session active")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: "shield.fill")
                    .foregroundStyle(cyan)
            } compactTrailing: {
                Text(context.attributes.startedAt, style: .timer)
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(cyan)
                    .frame(width: 42)
            } minimal: {
                Image(systemName: "shield.fill")
                    .foregroundStyle(cyan)
            }
            .keylineTint(cyan)
        }
    }
}

extension FocusUpActivityAttributes {
    fileprivate static var preview: FocusUpActivityAttributes {
        FocusUpActivityAttributes(startedAt: .now)
    }
}

extension FocusUpActivityAttributes.ContentState {
    fileprivate static var active: FocusUpActivityAttributes.ContentState {
        FocusUpActivityAttributes.ContentState(questTitle: "Finish the FocusUp report", streak: 3)
    }
}

#Preview("Notification", as: .content, using: FocusUpActivityAttributes.preview) {
    FocusUpActivityLiveActivity()
} contentStates: {
    FocusUpActivityAttributes.ContentState.active
}
