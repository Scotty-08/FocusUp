# Claude handoff: FocusUp TestFlight

User authorized preparing and sharing via TestFlight, never public App Store publication. Preserve existing staged/unstaged work. Original documentation-only scope is historical; app implementation exists and TestFlight was explicitly requested.

## Exact stopping point
Apple Family Controls Distribution became available after the user submitted the account request. Main app and DeviceActivityMonitorExtension capability updates were saved and confirmed in Apple Developer. ShieldActionExtension distribution checkbox was checked and Save clicked, but the last observed UI was the Modify App Capabilities confirmation dialog: final Confirm was NOT clicked. ShieldConfigurationExtension has NOT yet been updated in this session. Browser state may have changed; inspect fresh before proceeding. Do not assume all four are enabled.

## Next steps
1. Verify and finish Family Controls Distribution on com.scottgray.FocusUpSpike, and its .DeviceActivityMonitorExtension, .ShieldActionExtension, .ShieldConfigurationExtension IDs. Main app portal record: UF79R2B97D. Live Activity extension does not require this entitlement.
2. Refresh automatic signing/provisioning and retry Xcode Organizer validation. Previous distribution validation failed solely at the observed stage due to missing Family Controls distribution profiles for those four IDs. Later validation/upload checks remain unverified.
3. Upload using App Store Connect distribution, NOT TestFlight Internal Only. Complete TestFlight metadata/export compliance, create internal then external test groups, submit for beta review and invite the chosen tester after approval. Tester email/review contact metadata still needed. Never submit a public App Store release.

## Completed
Project /Users/scottgray/Documents/Codex/FocusUp/FocusUpSpike/FocusUpSpike.xcodeproj. Xcode 27.0, scheme FocusUpSpike, Release archive. Team Scott Gray / 6KZ2Y5MG5M. All five targets version 1.0 build 1 and iOS minimum 27.0 at inspection. Verify these again if work has changed.
Created App Store Connect record FocusUp - Scott Gray Demo, ID 6813758046, bundle com.scottgray.FocusUpSpike. Name FocusUp was taken. Xcode showed a creation error but its server response confirmed success and subsequent validation advanced to signing. Do not create a duplicate app.
Added main app Assets.xcassets/AppIcon.appiconset/Contents.json and AppIcon.png (opaque 1024px cyan ring/sparkle adapted from existing FocusUpEmblem). Added ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon to app Debug/Release in project.pbxproj. These are the only app project changes made for this task; other dirty files preexisted. No commits/pushes performed.
Xcode GUI archive succeeded, including updated icon, September 18 at 11:29 PM. Organizer archive path under ~/Library/Developer/Xcode/Archives/2026-09-18/. Compiled Info.plist confirmed AppIcon. Shell preflight failed due to sandbox Swift preview macro restrictions, not an established app source error. GUI build succeeded.
No binary uploaded, no invites sent, no public release submitted by this session. Physical-device TestFlight behavior not verified. Current email/password UI is explicitly a local preview, not secure backend authentication.

See accompanying FocusUp-TestFlight-checklist.md for the detailed flow. Its earlier pending-approval section is superseded by the exact stopping point above.
