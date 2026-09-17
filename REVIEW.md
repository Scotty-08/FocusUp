# FocusUp — MVP Specification Review

**Role:** Secondary engineer / reviewer (per `CLAUDE.md`). Codex is primary implementation engineer.
**Reviewed:** `PROJECT_SPEC.md`, cross-checked against `CLAUDE.md` and `AGENTS.md`.
**Repository state at review time:** documentation only — `README.md`, `CLAUDE.md`, `AGENTS.md`, `PROJECT_SPEC.md`. No Xcode project or application code exists yet.
**Change scope of this review:** this file only. No other file was created, edited, or deleted.

## How to read this

Every finding below is tagged with a severity and a basis:

- **Basis: VERIFIED (repo)** — confirmed directly from the text of the three spec/instruction files.
- **Basis: VERIFIED (Apple docs, checked 2026-09-17)** — confirmed by fetching current Apple Developer Documentation during this review (URLs in Sources). Docs can change; re-check before relying on this for a hard deadline.
- **Basis: RESEARCH NEEDED** — reported consistently in developer forums/blogs but not from an Apple primary source, or the primary source didn't fully resolve it. Confirm against current docs/DTS before depending on it.
- **Basis: DEVICE TEST NEEDED** — can only be settled by running the real feasibility spike on the actual Apple ID, Mac, Xcode version, and iPhone that will be used for the demo. Nothing below substitutes for this.

---

## 1. Top risks, ranked

1. **No confirmed Mac.** (Critical — VERIFIED repo + platform fact) `PROJECT_SPEC.md` says "Let Xcode on the Mac create the initial iOS project," but nothing in the repo confirms Mac access exists. This repository currently lives on a Windows machine. Xcode is macOS-only — there is no Windows-native way to build, sign, or install an iOS app (cloud-Mac rental services exist but aren't mentioned as a fallback). This is a harder blocker than anything Apple-account-related and should be confirmed before any other planning proceeds.
2. **Ordering contradiction between the code freeze and the required feasibility spike.** (High — VERIFIED repo, contradiction) `PROJECT_SPEC.md`'s "First milestone" requires installing and running real code on the iPhone (request authorization, select an app, apply and remove a real restriction) before anything else is built. But both `CLAUDE.md` and `AGENTS.md` say, in near-identical language, not to create application code or an Xcode project "until the user asks to begin implementation." As written, the spec's own first required step is blocked by the repo's current-phase instructions. See §2.
3. **Free/Personal Team cannot use Family Controls at all — not a matter of degree, a hard wall.** (High — VERIFIED Apple docs) `PROJECT_SPEC.md` says "Do not assume free Personal Team provisioning supports the necessary blocking capabilities," which is correctly cautious, but understates it: it isn't a capability gap, it's a total block, confirmed by Apple DTS engineers on Apple's own forums. See §3.
4. **Shields are stickier than the spec assumes.** (High — VERIFIED Apple docs / RESEARCH NEEDED for the failure-mode reports) `ManagedSettingsStore` shields survive force-quit, device restart, *and app deletion* — Apple's own behavior, not a bug, per developer reports. Only the owning app's code can clear them. This has direct implications for "emergency override" and "state recovery" that the spec doesn't address. See §5.
5. **`FamilyActivityPicker` selections are opaque tokens with no name/bundle ID.** (Medium/High — VERIFIED Apple docs pattern, widely corroborated) The spec's UI language ("understandable restriction status") and the acceptance checklist's "demonstrate that a selected app is actually restricted" implicitly assume the app can show *which* app is blocked by name. It can't, without using the system-provided opaque `Label(token)` view. See §4.
6. **No reconciled timeline, no decision deadline for the fallback.** (Medium — VERIFIED repo) The spec flags its own dates as possibly stale ("confirm actual dates before scheduling work") but the acceptance checklist and demo sequence are written as if the real-blocking path will simply work. There's no stated date by which, if the feasibility spike or entitlement/account setup hasn't succeeded, the team commits to the fallback ("clearly labeled UI demonstration"). See §7.

---

## 2. Contradictions between the documents

### 2.1 Code freeze vs. required feasibility spike
- `CLAUDE.md`: "This repository is in documentation and planning setup. **Do not create or modify application code or an Xcode project** until the user asks to begin implementation."
- `AGENTS.md`: "**Do not create or modify application code, scaffold an iOS project, or hand-author Xcode project files** until the user asks to begin implementation."
- `PROJECT_SPEC.md`: "**First milestone: prove platform feasibility** ... The feasibility experiment must install and launch on the physical iPhone, request the appropriate user authorization, select a distracting app, apply a real system restriction, and remove that restriction."

These can't both be followed literally at the same time. Two readings are possible and the docs don't say which is intended:
- (a) the feasibility spike counts as "planning," not "implementation," and is exempt from the freeze, or
- (b) the freeze applies to everything including the spike, and the user must explicitly say "begin implementation" (or "begin the feasibility spike") before any code is written.

**Recommendation:** resolve this explicitly with the user before Codex starts anything device-related — it changes who's authorized to act next.

### 2.2 "Career-fair priority" vs. undated planning
`CLAUDE.md`'s "Career-fair priority" section treats the event as an imminent, fixed deadline driving prioritization ("Deliver a stable demonstration... treat signing, authorization, and real app blocking as early feasibility gates"). `PROJECT_SPEC.md` says the previously-planned dates (Sunday build / Tuesday fair) may be stale and must be reconfirmed. Nothing currently reconciles these — a plan can't be sequenced against an unconfirmed deadline. This isn't a document bug so much as an open input only the user can supply, but it blocks turning the spec's checklist into a schedule.

### 2.3 Minor: "AGENTS.md" self-reference vs. actual filename
`AGENTS.md` footnotes the AGENTS.md convention with a link but never states an iOS deployment-target minimum, Xcode version, or Swift version anywhere in the repo — not a contradiction, but paired with §2.1 it means Codex has no floor to check on device before writing code once unblocked. Listed here for completeness; substantive treatment is in §7.4.

---

## 3. Apple signing and entitlements

**Basis for this section:** Apple's current "Requesting the Family Controls entitlement" and "Configuring Family Controls" documentation (fetched live during this review, copyright-dated 2026), corroborated by Apple Developer Forums threads including a Apple DTS engineer's direct answer.

3.1. **VERIFIED (Apple docs).** There are two distinct things called "the Family Controls entitlement," and the spec doesn't distinguish them:
   - **Development entitlement/capability** — added directly in Xcode ("Family Controls (Development)" in the Capabilities library), available immediately to any **paid** Apple Developer Program member, with **no Apple review or waiting period**. This is what's needed to install and run on your own registered iPhone via Xcode — i.e., exactly the demo path `PROJECT_SPEC.md` describes.
   - **Distribution entitlement** — requires submitting a request via Apple's Family Controls distribution request form (or the Capability Requests tab) and waiting for Apple's approval. This is only required for TestFlight or App Store distribution, both of which `PROJECT_SPEC.md` explicitly places **outside the MVP**.

   **Practical effect:** if the demo truly stays "Xcode → physical iPhone" only (as planned), the team likely does **not** need to go through Apple's uncertain-turnaround approval process at all. The real gate is simpler and more controllable: enroll the relevant Apple ID in the **paid** Apple Developer Program ($99/year). The spec's "verify current Apple requirements" instruction should be sharpened to say this explicitly, so nobody spends the pre-fair window waiting on an approval that isn't actually required for a device-only demo.

3.2. **VERIFIED (Apple docs / Apple DTS engineer, Developer Forums).** A free "Personal Team" (no paid enrollment) cannot use Family Controls at all — the capability doesn't even appear in Xcode's capability list for such accounts. This is confirmed by an Apple DTS engineer's forum reply: *"That capability should show up if you're a member of a paid team... The Personal Team feature has significant limitations and this is one of them."* `PROJECT_SPEC.md`'s caution ("do not assume free Personal Team provisioning supports the necessary blocking capabilities") is correct but should be stated as a hard requirement, not a caveat: **paid enrollment is mandatory**, full stop, before the feasibility spike can even begin.

3.3. **RESEARCH NEEDED / worth noting for risk register, not blocking.** Separately from development vs. distribution, multiple 2026 forum threads report **long, opaque waits for the distribution-entitlement approval** (one developer reported no response weeks after a March 2026 submission, with no visibility into review status). This only matters if the project's scope grows to include TestFlight/App Store later — but if there's any chance of that after the career fair, it's worth submitting that request early anyway, since the wait is unpredictable and out of the team's control.

3.4. **DEVICE TEST NEEDED.** Confirm, before relying on any of the above: the specific Apple ID that will sign the build is (a) enrolled in the paid Apple Developer Program (not just a free Apple ID), (b) that enrollment is fully active (not pending payment/agreements), and (c) once a target is created in Xcode, "Family Controls (Development)" actually appears and can be added without errors. Do this as the very first step of the feasibility spike — it's fast to check and everything else depends on it.

3.5. **Gap in the spec.** No mention of which Apple ID/team is intended, whether it's already enrolled, or who owns that account. `AGENTS.md` says "do not assume account eligibility" but doesn't assign anyone to confirm it. Recommend adding an explicit owner and a "confirm paid enrollment" checkbox as step zero of the feasibility milestone.

---

## 4. App blocking (Family Controls / Managed Settings / Device Activity)

4.1. **VERIFIED (Apple docs pattern), widely corroborated by developer reports.** `FamilyActivityPicker` and the resulting `FamilyActivitySelection` expose only opaque `ApplicationToken`/`ActivityCategoryToken` values — by design, for privacy, the app never learns the app's name, bundle identifier, or icon. Practical consequences the spec doesn't address:
   - The "Active focus" screen's "understandable restriction status" and the acceptance checklist's "demonstrate that a selected distracting app is actually restricted" can only show *which* app is blocked using Apple's own token-rendering views (e.g., `Label(token)`), not custom text/branding built from the app's real name. Worth stating explicitly as a constraint so the UI design doesn't silently assume otherwise.
   - Tokens can't be meaningfully logged for debugging (consistent with `AGENTS.md`'s "avoid logging [selection data] unnecessarily" — good, that instruction is already compatible with this constraint, just note *why*).
   - Selections are scoped to the device/app group; there's no server-side or cross-device persistence path, which is fine since the MVP explicitly has no accounts/sync, but confirms local-only storage is the only option, not a choice.
   **Recommendation:** add a line to the spec's Screens section clarifying that restriction-status UI will name the blocked app using system-provided token views, not custom copy.

4.2. **VERIFIED (Apple docs), important for reliability claims.** Once `ManagedSettingsStore.shield.applications` (or `.applicationCategories`) is set, the restriction is enforced by the system, not the app — it is reported to persist through the app being force-quit, the device being restarted, and even through the app being **deleted**. Only code in the owning app can clear it (`store.shield.applications = nil` / `store.clearAllSettings()`), and there is no OS-level automatic cleanup on uninstall. Developer forum reports (unresolved as of the linked thread) describe cases where restrictions persisted even after uninstall and a restart, which the reporting developer's users mistook for malware — worth being aware of, not just for architecture but for how the team communicates the app's behavior if something goes wrong during rehearsal. This is genuinely good news for reliability (no relaunch is required to keep protection active — directly supports the spec's "no automatic timer-based completion or scheduled blocking is required" default) but it's a serious liability if the app ever needs to be deleted/reinstalled during development or right before the fair, since previously-applied shields could outlive the app that set them. See §5 for the recovery implications.

4.3. **DEVICE TEST NEEDED.** Whether `store.shield.applications = nil` reliably clears the shield in one call, or whether (per one forum report) `clearAllSettings()` "sometimes doesn't work," needs to be verified on the actual demo hardware/OS version — don't assume the happy path from documentation alone. The acceptance checklist's "Complete the goal and demonstrate restored access" and "Confirm emergency override and demonstrate restored access" items should be treated as the two most important things to rehearse repeatedly, including deliberately-interrupted cases (kill the app mid-clear, then relaunch and check).

4.4. **RESEARCH NEEDED.** Extensions (Device Activity Monitor, Shield Configuration/Action) reportedly run under tight memory limits and should do minimal work (read shared state from an App Group, decide, write, exit). The current MVP scope (no scheduled blocking, no custom shield UI mentioned) may not need any extension at all — worth confirming that plainly in the spec once implementation direction firms up, since it simplifies the entitlement surface (fewer targets needing the capability, per §3.1's note that extensions need their own entitlement request too).

4.5. **Gap in the spec.** No mention of what happens if Screen Time is already configured on the demo iPhone by something else (existing Screen Time limits, a Family Sharing "child" configuration, an MDM profile, or another Screen Time-consuming app). `AuthorizationCenter.requestAuthorization(for: .individual)` is the relevant self-restriction flow (not `.child`), but its behavior when the device is already under a conflicting Screen Time configuration should be checked on the actual demo device ahead of time, not discovered at the fair.

4.6. **Gap in the spec.** No mention of what the *shield screen itself* looks like to the user (Apple's default system-provided blocking screen vs. a custom one via a Shield Configuration extension). The MVP doesn't require custom shield branding, but it's worth an explicit one-line decision ("MVP uses the default system shield") so it isn't accidentally treated as a missing feature during rehearsal.

---

## 5. State and recovery

5.1. **Gap, made more important by §4.2.** The spec's recovery requirements ("reconcile persisted session information with available platform authorization and restriction state" on foreground/relaunch) cover authorization being revoked, but don't cover the scenario where the **app itself has been reinstalled** (fresh install, no persisted session) while a shield from a *previous* install is still active on the device. Since shields reportedly outlive deletion, a reinstalled FocusUp could start with no session state at all but the phone still shows a restricted app — and the fresh install has no record of what it shielded, so there's nothing to reconcile against. Recommend the spec explicitly decide the intended behavior here (e.g., "on first launch after install, if any FocusUp-owned shield exists with no matching local session, clear it"), or explicitly accept the risk and add "don't delete/reinstall the demo build once a session has been started" to the rehearsal checklist.

5.2. **VERIFIED (repo), flagged as a real edge case, not covered explicitly.** The spec requires that a failed start not leave "an apparently active session or unexplained partial restrictions," and that a failed removal "retain a visible recovery/retry path." Good. But it doesn't explicitly address cross-action races beyond same-button double-taps — e.g., the user taps **Complete Goal** and **Emergency Override** in quick succession, or backgrounds the app mid-transition and returns. The state machine (draft/starting/active/ending/completed/overridden/error) is named but its transition table isn't specified; recommend Codex write out the explicit transition table (allowed source states → target states, and what happens to an in-flight operation when a second one is requested) before implementing, since this is exactly the kind of thing that's cheap to specify and expensive to debug live.

5.3. **DEVICE TEST NEEDED.** The spec asks to "test backgrounding, force quit, and device restart; document any platform limitations instead of promising tamper-proof enforcement" — correctly scoped. Add to that list, based on §4.2/§5.1: test **app deletion and reinstallation** as its own scenario, since it's the one most likely to actually happen during development/rehearsal (e.g., installing a new build over an old one, or troubleshooting by deleting and reinstalling) and has the most surprising behavior.

5.4. **RESEARCH/DEVICE TEST NEEDED.** Persisted `ApplicationToken`s (for "recover the goal, selection, and session outcome after relaunch") are `Codable` and expected to remain valid locally across ordinary relaunches, but whether they stay valid across an app update, an OS update, or a token expiring for any Apple-side reason isn't confirmed here — worth a quick device check (persist a token, install an updated build, confirm the token still decodes and still maps to the same app) rather than assuming indefinite stability.

---

## 6. Emergency override

6.1. **VERIFIED (repo), good.** The spec correctly requires the override to (a) remain reachable during an active session, (b) require explicit confirmation, (c) clear only FocusUp-owned restrictions, and (d) mark the session as overridden rather than completed. The acceptance checklist even includes canceling the confirmation and verifying focus continues — good coverage of the "accidental tap" case.

6.2. **Gap.** The general "failed removal must retain a visible recovery/retry path" requirement lives in the State and Recovery section and isn't explicitly repeated for the override path. Given override is the "something's wrong, get me out" mechanism, its failure mode deserves to be called out by name rather than inherited implicitly — recommend adding a line to the Emergency Override requirement itself: "If clearing restrictions during override fails, the session must not be marked overridden, and the override action must remain retryable" (mirrors the completion-path language already used, applied explicitly here too).

6.3. **Gap, ties to §4.2.** "Clear only restrictions owned by FocusUp's session" is a correct scope statement, but its implementation depends on consistently using one identifiable `ManagedSettingsStore` (e.g., a single named store) across the app's lifetime. If the store's name or identity changes between builds during development (a plausible mistake, not a hypothetical), previously-set shields become effectively orphaned — nothing in the running app references them anymore, yet they remain active per §4.2. Recommend Codex treat the store name/identity as a fixed, documented constant from the first line of code that touches it.

6.4. **DEVICE TEST NEEDED.** Whether clearing a shield during override is any slower/less reliable than clearing it during normal completion isn't known — the spec treats them as symmetric ("Remove the session's restrictions" in both cases) which is a reasonable design, but should be verified to actually behave the same on device, especially under the "cancel then re-open" acceptance test.

---

## 7. Other gaps and risks (not in the four focus areas, still worth recording)

7.1. **Undated plan.** Already covered in §2.2 — recorded here as a concrete action item: get a real date from the user before the acceptance checklist is used as a schedule.

7.2. **No committed fallback deadline.** The spec allows a "clearly labeled UI demonstration" fallback but never says when the team decides to switch to it. Recommend picking a concrete go/no-go date (e.g., "if real on-device blocking isn't demonstrated successfully by day X, fall back") so the fallback isn't decided under fair-day pressure.

7.3. **iOS/Xcode/Swift version floor unspecified.** `.individual` Family Controls authorization requires a minimum iOS version (historically iOS 16+, with some refinements in later point releases) — the spec correctly defers "exact deployment target... subject to the feasibility test and current Apple documentation," which is reasonable, but recommend recording the chosen minimum once decided, since it affects which demo iPhone/OS combinations are viable.

7.4. **Simulator won't validate the real thing.** Not stated anywhere in the spec, though implied by "physical device evidence is required." Worth stating explicitly: the iOS Simulator can compile-check and lay out UI, but does not enforce real Family Controls restrictions, so no amount of Simulator testing substitutes for the physical-device tests already required. (Low severity only because the spec already requires physical-device testing throughout — this just makes the *reason* explicit for whoever implements it.)

7.5. **Accessibility acceptance item is underspecified.** "Check readable text, accessible control labels, and the essential flow with larger text" is a reasonable checklist item but doesn't say which Dynamic Type size to test at or which screens count as "essential flow" — low-severity, but worth a one-line clarification so the check is actually repeatable.

---

## 8. Fact ledger

| # | Claim | Status | Source |
|---|---|---|---|
| 1 | Development-only Family Controls capability requires a **paid** Apple Developer Program account; a free Personal Team cannot use it at all (capability doesn't appear in Xcode) | VERIFIED (Apple docs + Apple DTS engineer forum reply) | developer.apple.com/documentation/xcode/configuring-family-controls; developer.apple.com/forums/thread/764682 |
| 2 | Development use (Xcode → physical device, no TestFlight/App Store) does **not** require Apple's separate distribution-entitlement approval/review | VERIFIED (Apple docs) | developer.apple.com/documentation/xcode/configuring-family-controls |
| 3 | The distribution entitlement (needed only for TestFlight/App Store) goes through a review process with reportedly long, opaque wait times in some 2026 cases | RESEARCH NEEDED (forum reports, not an Apple-published SLA) | developer.apple.com/forums/thread/818553 |
| 4 | `ManagedSettingsStore` shields persist through force-quit and device restart | VERIFIED (Apple docs pattern) / RESEARCH NEEDED for edge-case reliability | habitdoom.com/blog/shipping-familycontrols-ios |
| 5 | `ManagedSettingsStore` shields can persist even after the owning app is **deleted**, with no automatic OS cleanup | RESEARCH NEEDED (consistent developer reports, not an Apple-published guarantee either way) | developer.apple.com/forums/thread/802242; habitdoom.com/blog/shipping-familycontrols-ios |
| 6 | `FamilyActivityPicker` selections expose only opaque tokens — no app name or bundle ID available to the app | VERIFIED (Apple framework design, corroborated by multiple developer forum threads) | habitdoom.com/blog/shipping-familycontrols-ios; developer.apple.com/forums (bundle-ID threads) |
| 7 | `clearAllSettings()` / clearing shields is not 100% reliable in all reported cases | RESEARCH NEEDED | developer.apple.com/forums/thread/744157 |
| 8 | This repository currently resides on a Windows machine; Xcode/iOS builds require a Mac | VERIFIED (observed directly: this session's device platform is `win32`) | this session's environment |
| 9 | The four spec/instruction docs disagree on whether the feasibility spike is blocked by the "no code yet" phase gate | VERIFIED (repo text, quoted in §2.1) | CLAUDE.md, AGENTS.md, PROJECT_SPEC.md |
| 10 | Whether the specific Apple ID intended for this project is enrolled in the paid Developer Program | DEVICE TEST / ACCOUNT CHECK NEEDED | not stated anywhere in the repo |
| 11 | Whether persisted `ApplicationToken`s remain valid across app/OS updates | DEVICE TEST NEEDED | not found in sources reviewed |

---

## 9. Suggested next actions (for the user/Codex, not actioned by this review)

1. Confirm Mac access before anything else — this blocks the entire plan regardless of Apple-account status.
2. Resolve the §2.1 ordering contradiction explicitly: is the feasibility spike authorized now, or does it wait for an explicit "begin implementation"?
3. Confirm the Apple ID for this project is (or can quickly become) a paid Apple Developer Program member; this is the one Apple-side gate actually required for a device-only demo, per §3.1.
4. Get a real target date from the user (§2.2, §7.1) and set an explicit fallback-decision date (§7.2).
5. Once code exists, treat the §5.2 state-transition table and the §6.3 fixed store-identity decision as due before, not during, implementation.

---

## Sources consulted (live-checked 2026-09-17)

- [Requesting the Family Controls entitlement — Apple Developer Documentation](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement)
- [Configuring Family Controls — Apple Developer Documentation](https://developer.apple.com/documentation/xcode/configuring-family-controls)
- [Family Controls Capabilities missing from capabilities menu in XCode — Apple Developer Forums (thread 764682)](https://developer.apple.com/forums/thread/764682)
- [Family controls entitlement request submitted on March 9, 2026 — no response — Apple Developer Forums (thread 818553)](https://developer.apple.com/forums/thread/818553)
- [After uninstalling the app, ManagedSettingsStore.shield is still active — Apple Developer Forums (thread 802242)](https://developer.apple.com/forums/thread/802242)
- [ManagedSettingsStore.clearAllSettings() sometimes doesn't work — Apple Developer Forums (thread 744157)](https://developer.apple.com/forums/thread/744157)
- [You Cannot Run Family Controls on a Real Device with a Personal Team — hsb.horse](https://hsb.horse/en/blog/personal-team-family-controls-limitation/)
- [FamilyControls in Production: The Edges — Habit Doom](https://habitdoom.com/blog/shipping-familycontrols-ios)

This review's own text (§1–§9) is otherwise based on `CLAUDE.md`, `AGENTS.md`, and `PROJECT_SPEC.md` as they exist in this repository at review time, plus direct observation of this session's environment (§8, item 8).
