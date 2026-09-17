# FocusUp — Career-Fair MVP

## Purpose
FocusUp is an iPhone productivity app that restricts user-selected distracting apps during a goal-focused session and restores access when the user completes the goal. The career-fair deliverable is a small, reliable demonstration on the user's physical iPhone.

## Current phase and delivery plan
This change establishes documentation only. Create the initial iOS project with Xcode on the Mac when implementation is requested. Do not generate application code during repository setup.

The intended demo installation route is directly from Xcode to the user's iPhone. TestFlight and App Store release are outside this MVP. The earlier planning target was a Sunday-ready build for a Tuesday career fair; confirm actual dates before scheduling work.

## First milestone: prove platform feasibility
Before building the full UI, verify current Apple requirements and test the selected Apple account, signing team, device, OS, and Xcode combination. Do not assume free Personal Team provisioning supports the necessary blocking capabilities.

The feasibility experiment must install and launch on the physical iPhone, request the appropriate user authorization, select a distracting app, apply a real system restriction, and remove that restriction. Record the environment, entitlement/signing results, and observed behavior.

If this fails, report the specific blocker and available options before expanding implementation. A clearly labeled UI demonstration may be discussed as a fallback, but it does not satisfy real blocking acceptance criteria.

## Required workflow
1. Create a goal with a nonempty title; reject whitespace-only input.
2. Explain why app-selection authorization is needed and request it through the supported system flow.
3. Select distracting apps using the supported system picker.
4. Start Focus after a valid goal, authorization, and at least one selected app are available.
5. Apply restrictions to the selected apps and show the active goal/session state. Never report successful protection after a known failure.
6. Let the user explicitly mark the goal complete. Remove this session's restrictions and show completion after the operation succeeds.
7. Provide an emergency override during an active session. Explain that it ends focus without completing the goal and require explicit confirmation. Remove the session's restrictions and mark the session overridden.

## MVP defaults
These are intentionally small design defaults, open to later user revision:
- One active goal/session at a time.
- Completion is self-reported; no AI, photo, location, or third-party verification.
- Goal and app selection can be edited before starting; during a session, end through completion or emergency override before changing its configuration.
- No automatic timer-based completion or scheduled blocking is required.
- Store enough local state to recover the goal, selection, and session outcome after relaunch.
- No account, server, cloud sync, subscription, or analytics is required.

## Screens
- Setup/home: goal entry, permission status, app selection, and Start Focus.
- Active focus: current goal, understandable restriction status, Complete Goal, and Emergency Override.
- Result: distinguish completion from override and offer a new session.
- Permission/error guidance: explain the problem, offer an appropriate retry or recovery path, and avoid false success states.

## State and recovery requirements
Represent draft, starting, active, ending, completed, overridden, and recoverable error states explicitly enough to avoid contradictory UI and restrictions.

Prevent repeated taps from creating duplicate sessions or conflicting operations. A failed start must not leave an apparently active session or unexplained partial restrictions. A failed removal must retain a visible recovery/retry path; do not mark the session finished while known restrictions remain.

On foregrounding or relaunch, reconcile persisted session information with available platform authorization and restriction state. Surface revoked authorization honestly. Test backgrounding, force quit, and device restart; document any platform limitations instead of promising tamper-proof enforcement.

The emergency override must remain reachable from an active session. Clear only restrictions owned by FocusUp's session. Do not claim to override restrictions imposed by other apps or system policies.

## Implementation direction
Use native Swift and SwiftUI after Xcode project creation. Evaluate Apple's Family Controls and Managed Settings frameworks for app selection and enforcement; introduce Device Activity or extensions only where the verified design requires them. Exact deployment target, targets, entitlements, and APIs remain subject to the feasibility test and current Apple documentation.

Keep views, goal/session state, local persistence, and blocking operations separated with a small testable boundary. Avoid elaborate architecture for this MVP. Treat app-selection data as private and avoid logging it unnecessarily. Core operation should not depend on an external service.

## Acceptance checklist
- [ ] Install and launch the demo build on the physical iPhone with valid signing for the event.
- [ ] Create a valid goal; prevent empty input and starting without required selection/authorization.
- [ ] Start a session and demonstrate that a selected distracting app is actually restricted.
- [ ] Demonstrate that an unselected test app remains accessible.
- [ ] Complete the goal and demonstrate restored access to the selected app.
- [ ] Start another session, cancel the emergency confirmation, and verify focus continues.
- [ ] Confirm emergency override and demonstrate restored access without recording goal completion.
- [ ] Repeat sessions without stale restrictions, duplicate transitions, or crashes.
- [ ] Verify persistence/reconciliation after backgrounding, relaunch, and device restart; record observed limitations.
- [ ] Verify denied/revoked authorization and operation failures produce honest, recoverable UI.
- [ ] Check readable text, accessible control labels, and the essential flow with larger text.

Use automated tests for meaningful session-state and failure-handling behavior where feasible. Mocks support logic testing but do not prove system enforcement; physical-device evidence is required for blocking and unblocking.

## Demo sequence
Create a short sample goal, select a nonessential distracting app, start focus, open that app to show the restriction, return to FocusUp, complete the goal, and reopen the app to show restored access. Repeat with emergency override. Rehearse before the fair and verify the installed build still launches and enforces restrictions.

## Outside the MVP
Social features, leaderboards, streaks, rewards, advanced statistics, multiple simultaneous goals, recurring schedules, AI verification, cloud accounts, payments, TestFlight distribution, and App Store publication. Add these only after the core workflow is stable and the user requests expanded scope.
