# FocusUp — Codex Instructions

## Role
Codex is the primary implementation engineer for FocusUp. Claude Code is the secondary engineer, reviewer, and debugger; its role is defined in CLAUDE.md. Read PROJECT_SPEC.md as the product specification before starting work.

## Current phase
Implementation is underway. `FocusUpSpike/` is a working Xcode project (main app plus `ShieldConfigurationExtension`, `ShieldActionExtension`, `DeviceActivityMonitorExtension`, and the `FocusUpActivity` Live Activity widget) with real Family Controls / ManagedSettings enforcement already implemented: goal/task creation, app-selection authorization, shield apply/clear, emergency override, periodic check-ins, streaks, and onboarding/auth. Continue building on this project directly. See `FEASIBILITY.md` for the platform-feasibility evidence recorded during the initial spike.

## Implementation priorities
1. Prove signing, installation, authorization, blocking, and unblocking on the actual iPhone with the selected Apple account.
2. Implement the smallest complete goal-to-blocking-to-unblocking workflow.
3. Make state recovery, emergency override, and errors reliable.
4. Test and polish the career-fair demonstration before adding features.

## Working rules
- Inspect the repository and local changes before editing. Preserve the user's work and coordinate file ownership when another agent is editing.
- Prefer small, reviewable changes and simple Swift/SwiftUI designs. Keep goal/session logic separate from UI and platform blocking operations.
- Explain substantial architecture choices and scope changes. Avoid unrelated refactoring and dependencies without a concrete need.
- Verify Apple APIs, capabilities, and provisioning requirements against current official documentation when implementing them; do not invent APIs or assume account eligibility.
- Do not describe simulated blocking as real device enforcement.
- Handle denied or revoked authorization, failed restriction changes, repeated actions, and app relaunch explicitly.
- Keep data local for the MVP. Do not commit credentials, signing assets, or private device data.
- Run checks appropriate to each change. Add meaningful tests for state transitions and regressions once application code exists.
- Report what changed, why, validation performed, and remaining limitations. Windows checks cannot establish that an iOS build or on-device blocking works.
- Prepare a concise reviewer handoff with intended behavior, affected files, tests, and unresolved risks when review is requested.

## Definition of done
Meet PROJECT_SPEC.md acceptance criteria, including a physical-device demonstration of both normal completion and emergency override. Reliability takes priority over stretch features. Do not silently lower acceptance criteria if a platform capability is unavailable.

## Instruction format reference
This repository uses AGENTS.md for Codex repository instructions: https://learn.chatgpt.com/docs/agent-configuration/agents-md
