# FocusUp branded shield — September 18

## Scope

Uses public ShieldConfiguration fields and an original, statically rendered F↑ emblem. The same artwork is used inside FocusUp. The system still chooses shield layout, typography and button dimensions. No private APIs or image-layout hacks.

## Transitions

| Event | Result | Restrictions |
|---|---|---|
| Shield: Open Quest | Persist one presentation request in App Group; return openParentalControlsApp on iOS 26.5+ | Unchanged |
| Shield: Keep it blocked | Close blocked app | Unchanged |
| App foreground / cold start | Consume pending request; refresh current quest and show custom full-screen view | Unchanged |
| Custom screen: close / keep focusing / cancel confirmation | Dismiss or retain screen | Unchanged |
| Confirm completion | Revalidate captured quest ID; stop check-ins, clear named store, read back, complete quest, record stats | Clear FocusUp store only |
| Confirm early exit | Stop check-ins, clear named store, read back, record ignore; leave task unfinished | Clear FocusUp store only |
| Changed quest / failed read-back | Show error; retain retry path | No completion recorded |

Store identity remains `com.scottgray.FocusUpSpike.mainStore`. End actions run synchronously on MainActor; the screen guards repeated submissions. Completion and early exit now end the full focus session (all selected apps and periodic check-ins), rather than releasing only the app whose shield button was pressed. Other apps/system policies are unaffected.

For earlier iOS versions a local notification is a best-effort fallback; without notification permission the user must open FocusUp manually. App routing waits behind existing authentication/onboarding if needed. New monitor callbacks check the shared enabled flag before reapplying restrictions; already executing cross-process callbacks remain an on-device race to test. Store read-back is not proof of actual OS enforcement.

## Validation required on the phone

- Open a selected app: near-black shield, emblem, FocusUp title, actual active quest.
- Keep it blocked closes that app without completing/unlocking.
- Open Quest opens FocusUp directly, both while running and after force quit.
- Cancel completion / override and return to blocked app: still restricted.
- Confirm completion: selected apps accessible, task completed once, stats increment once.
- Confirm early exit: apps accessible, task remains incomplete, no completion increment.
- Repeat across usage threshold; no later re-shield after ending focus.
- Large text and long quest title; no clipped controls.

No application data, opaque tokens, or device identifiers are logged by this feature. Reinstall recovery remains outside this change and unverified.

## Build evidence

September 18, 2:04 PM: Xcode reported Build Succeeded for the updated app and embedded extensions targeting the connected iPhone. The shell build encountered a sandbox Swift macro-plugin error; the normal Xcode build succeeded. Launch was blocked by the iPhone being locked, so visual rendering and real Open Quest / unblock behavior are pending physical-device testing. No automated test suite was run for this change. `git diff --check` passed.
