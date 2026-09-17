# Platform feasibility spike

## Evidence recorded 2026-09-17

- User explicitly authorized the feasibility spike in the Codex conversation; the initial planning-only gate is satisfied.
- Local checkout: `/Users/scottgray/Documents/Codex/FocusUp`.
- Remote: `https://github.com/Scotty-08/FocusUp.git`; branch `main`, starting commit `f562e04b49b00565b57f0e39226170649b8570fe`. GitHub Desktop reported a fresh completed fetch and no local changes before work started.
- Read `REVIEW.md` before the specification and implementation instructions.
- Verified locally: macOS 27.0 (26A428), Xcode 27.0 (27A266a).
- Created `FocusUpSpike/FocusUpSpike.xcodeproj` using Xcode's App creation and Save Project flow, not a hand-authored project file.
- Selected the Scott Gray signing team in Xcode. Bundle identifier: `com.scottgray.FocusUpSpike`.
- **Verified in Signing & Capabilities:** `Family Controls (Development)` appears in the capability library and was successfully added to the target.
- **Initial provisioning blocker (resolved below):** Xcode reports that the team has no devices from which to generate a provisioning profile, and no matching iOS development profile exists yet. Connect the physical iPhone and retry provisioning.

## Current limits

The project still contains Xcode's initial app template. No authorization, selection, blocking, or unblocking code has been implemented or device-tested. Signing and template launch are now verified below; capability availability does not prove system enforcement. Xcode's new App template includes additional platforms; narrow this to iPhone/iOS and select an appropriate deployment target after checking the demo phone's OS.

## Next gate

1. Completed: connect/trust the physical iPhone and inspect its OS.
2. Completed: development signing and template launch on the physical iPhone.
3. Implement individual authorization, system app selection, a fixed named ManagedSettingsStore, and explicit apply/clear operations.
4. Verify blocking and both normal and emergency removal on the phone before expanding the UI.

## Review risks to carry forward

- Use system token labels; do not derive or log app names or bundle identifiers from picker selections.
- Treat deletion/reinstallation persistence as an unresolved platform risk, not an established guarantee. The review's fact ledger labels this research-needed despite stronger language elsewhere.
- Before implementing shield operations, document a permanent store identity and transition table, including competing end actions and interrupted operations.
- Provide recovery for missing/corrupt local session state and retain retry controls when removal cannot be confirmed. Verify actual access on device; store assignments alone are not proof of enforcement.
- User confirmed Tuesday morning, September 22, as the deadline. Friday platform proof is the proposed next gate; a fallback decision date is not yet agreed.

## Device setup update

- Xcode detected the connected iPhone 17 Pro running iOS 27.0 (24A5424a).
- Registered the phone through Xcode; iOS development provisioning now succeeds with the Family Controls development capability. Distribution-only warning is expected for this device-only spike.
- Initial template build completed; first launch was blocked by Developer Mode being disabled.
- User enabled Developer Mode and restarted. On retry Xcode began copying OS library symbols from the phone as part of first-time device preparation. Installation/launch was pending at that point and was subsequently verified below.

- First device launch verified in Xcode: debugger attached to the app process and status reads “Running FocusUpSpike on Scott (2)”. This verifies the signed template runs on the physical phone; Screen Time authorization and enforcement are not yet implemented or verified.
