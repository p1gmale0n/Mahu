# Screen Lock Detection Model Fix

## Overview

Fix Mahu's screen-lock detection model so ordinary macOS Lock Screen usage, including Apple Menu → Lock Screen, immediately enters away suppression and prevents hidden break overlays or completion sounds while the screen is locked.

The previous session-lock plan treated `NSWorkspace.sessionDidResignActiveNotification` as the primary lock signal. Manual diagnosis showed that ordinary Apple Menu → Lock Screen emitted distributed `com.apple.screenIsLocked` / `com.apple.screenIsUnlocked` notifications, while `NSWorkspace.sessionDidResignActiveNotification` / `sessionDidBecomeActiveNotification` did not fire. This means the existing implementation can pass unit tests while missing the real user-facing lock path.

This plan corrects the domain model:

- `NSWorkspace` session-active notifications represent user-session switching / Fast User Switching style transitions.
- Screen lock is a separate user-away state and must be observed separately.
- Mahu should keep existing session-away timer semantics once any trusted away source fires: no elapsed consumption, no HID idle polling, no break overlay presentation, and no completion sound while away.
- Distributed screen-lock notifications are practical but not documented by Apple as stable public API names, so they must be isolated behind a small observer seam and documented as best-effort.
- `CGSessionCopyCurrentDictionary()` is a public CoreGraphics API for current Window Server session state and should be used for current/startup state sanity checks where useful. The observed `CGSSessionScreenIsLocked` key is not listed by Apple among the documented standard Window Server Session Properties, so this dependency also needs to be isolated and documented.

## Context (from discovery)

- Files/components involved:
  - `Mahu/SessionActivityObservation.swift` — current `NSWorkspace` session active/inactive observer; keep it for session switching but do not treat it as complete screen-lock coverage.
  - `Mahu/SleepWakeObservation.swift` — existing focused observer/cancellation pattern to reuse for a new screen-lock observer seam.
  - `Mahu/AppDelegate.swift` — pre-launch away-state latch; must include screen-lock state and events, not only `NSWorkspace` session inactive events.
  - `Mahu/AppCoordinator.swift` — existing away suppression, tick suppression, idle-away ordering, overlay hiding, and sound gating. Keep changes minimal because this file is already oversized.
  - `Mahu/AppCoordinatorSupport.swift` — possible place for small shared protocol/type seams if needed.
  - `Mahu/IdleAwayReconciliationPolicy.swift` — current active-work / paused-work / active-rest away recovery semantics; screen lock should reuse these semantics.
  - `Mahu/UserIdleTimeProvider.swift` — HID idle provider; must not be queried while screen-lock away suppression is active.
  - `Mahu/StatusDisplayFormatter.swift` and `Mahu/StatusItemController.swift` — existing `Away`/`Paused` tray formatting and title-width constraints.
  - `MahuTests/LiveSessionActivityObservationRegistrarTests.swift` — current observer tests for `NSWorkspace`; add or split tests for screen-lock observation.
  - `MahuTests/FakeSessionActivityObserverRegistrarTests.swift` — fake registrar pattern for deterministic event delivery.
  - `MahuTests/SmokeTests.swift` — AppDelegate startup/latch tests.
  - `MahuTests/AppCoordinatorSessionInactiveTickSuppressionTests.swift` — coordinator behavior for away suppression; extend or add focused tests without bloating this file further.
  - `MahuTests/AppCoordinatorStatusItemRecoveryBaselineTests.swift` and `MahuTests/AppCoordinatorStatusItemPauseResumeTests.swift` — status display and paused-state recovery coverage.
  - `Mahu.xcodeproj/project.pbxproj` — update target membership for any new source/test files.
  - `README.md`, `AGENTS.md`, and `docs/decisions.md` — update user-facing behavior, product invariants, and decision history.
- Related patterns found:
  - Idle-away reset is config-gated and threshold-based; screen lock suppression is always-on and immediate.
  - Existing session-away suppression semantics are correct once an away event reaches `AppCoordinator`.
  - `BreakTimer` must remain pure and must not learn about screen lock, session switching, or UI state.
  - `Away` must remain bounded by the existing `Paused` tray title-slot requirement.
  - AppKit side effects should stay at the edges; observers should be focused seams, not coordinator-internal notification code.
  - `AppCoordinator.swift` is over the local readability threshold, so new lock-source logic should live in a dedicated helper/observer file.
- Dependencies identified:
  - Apple-documented public APIs:
    - `NSWorkspace.sessionDidResignActiveNotification` / `sessionDidBecomeActiveNotification` for user session switches.
    - `NSWorkspace.shared.notificationCenter` for workspace notifications.
    - `CGSessionCopyCurrentDictionary()` for current Window Server session dictionary.
    - `kCGSessionOnConsoleKey` as a documented session dictionary key.
  - Practical observed APIs / keys:
    - `DistributedNotificationCenter.default()` notifications named `com.apple.screenIsLocked` and `com.apple.screenIsUnlocked`.
    - `CGSSessionScreenIsLocked` inside the session dictionary.
  - External research context:
    - Apple docs describe `NSWorkspace.sessionDidResignActiveNotification` as a user session switch-out notification, not a screen-lock notification.
    - Apple DTS warns that undocumented stringly-typed notification names are not stable API contracts.
    - Manual observer evidence in this repo session: Apple Menu → Lock Screen emitted `Distributed com.apple.screenIsLocked` / `Distributed com.apple.screenIsUnlocked`, and did not emit the `NSWorkspace` session notifications.
- Current worktree warning:
  - Before executing this plan with ralphex, resolve the existing dirty worktree so this fix does not mix with unrelated idle/sleep test changes.

## Selected Approach

Chosen purpose: **Screen Lock Detection Model Fix**.

Chosen scope: **Minimal complete scope**:

- Add or refactor toward a screen-lock/user-away observation model rather than treating `NSWorkspace` session inactive as screen lock.
- Keep `NSWorkspace` notifications for session switching.
- Add a dedicated screen-lock source using `DistributedNotificationCenter` lock/unlock notifications.
- Add a current-state/startup screen-lock check using `CGSessionCopyCurrentDictionary()` where useful.
- Reuse current coordinator away semantics with idempotent handling.
- Update tests, README, AGENTS product invariants, and decision history.

Rejected for this plan:

- Private APIs, event taps, Accessibility/Input Monitoring, input capture, or keyboard/mouse capture.
- A broad lifecycle refactor of `AppCoordinator.swift` beyond what is necessary to wire the corrected observation model.
- A new config flag, Settings UI, or live config reload behavior.
- Changing idle-away reset semantics except where needed to preserve lock-away priority.

## Development Approach

- **Testing approach**: TDD.
- Complete each task fully before moving to the next.
- Make small, focused changes.
- Prefer new focused observer/helper files over growing `AppCoordinator.swift`.
- Preserve the existing coordinator away behavior once an away event is delivered.
- **CRITICAL: every task MUST include new/updated tests** for code changes in that task:
  - tests are not optional;
  - write unit tests for new functions/types;
  - write unit tests for modified wiring/behavior;
  - add tests for new lock/unlock code paths;
  - include both normal and duplicate/event-order edge scenarios.
- **CRITICAL: all tests must pass before starting next task** - no exceptions.
- **CRITICAL: update this plan file when scope changes during implementation**.
- Run targeted tests after each task.
- Maintain backward compatibility with existing idle-away, sleep/wake, pause/resume, tray timer, and overlay behavior.

## Testing Strategy

- **Unit tests** are required for every task.
- Use injected notification centers and state-provider closures; tests must not require real screen locking.
- Keep real manual lock/unlock validation in Post-Completion, not as automated task checkboxes.
- Required observer coverage:
  - distributed `com.apple.screenIsLocked` maps to the same away/inactive callback used by coordinator suppression;
  - distributed `com.apple.screenIsUnlocked` maps to the active/unaway callback;
  - existing `NSWorkspace` session switch notifications continue to work;
  - cancellation removes observers and remains idempotent;
  - duplicate events from multiple sources are safe.
- Required current-state coverage:
  - startup/current-state sampling detects `CGSSessionScreenIsLocked == true` as away;
  - missing/false lock key is treated as unlocked only when the session dictionary is otherwise usable;
  - nil/unusable session dictionary is handled safely and documented.
- Required coordinator coverage:
  - Apple Menu style screen-lock event before a near-expired work timer resets to fresh work and suppresses overlay/sound;
  - screen lock during active rest closes overlay silently and does not play completion sound;
  - repeated locked ticks do not consume elapsed and do not query the HID idle provider;
  - unlock clears `Away` and refreshes the baseline without consuming locked duration;
  - duplicate `NSWorkspace` + distributed lock/unlock events do not double-reset or regress timer state;
  - paused reminders remain paused and show `Paused`, not `Away`.
- Required documentation coverage:
  - README explains screen lock vs session switch vs idle-away clearly;
  - AGENTS product invariant no longer claims `NSWorkspace` alone handles ordinary lock screen;
  - docs/decisions records the trade-off and API stability caveat.

## Progress Tracking

- Mark completed items with `[x]` immediately when done.
- Add newly discovered tasks with a `➕` prefix.
- Document issues/blockers with a `⚠️` prefix.
- Update plan if implementation deviates from original scope.
- Keep the plan in sync with actual work done.

## What Goes Where

- **Implementation Steps**: code changes, tests, documentation/decision updates, and deterministic verification commands.
- **Post-Completion**: manual Apple Menu Lock Screen checks, Control-Command-Q checks, auto-lock checks, real tray checks, and external display/fullscreen Space checks.
- **Checkbox placement**: checkboxes belong only in Task sections. Do not add checkboxes to Overview, Context, Technical Details, Success Criteria, or Post-Completion.

## Implementation Steps

### Task 1: Add screen-lock current-state seam

- [x] add failing tests for a screen-lock state provider that reads an injected session dictionary and treats `CGSSessionScreenIsLocked == true` as locked/away
- [x] add failing tests for missing/false lock key, nil dictionary, and non-console/unknown session edge cases with the safest documented behavior for Mahu
- [x] create a focused screen-lock state provider, for example `Mahu/ScreenLockStateProvider.swift`, backed by `CGSessionCopyCurrentDictionary()` in production and an injected dictionary provider in tests
- [x] keep the `CGSSessionScreenIsLocked` string isolated in this provider with a short comment explaining that it is an observed session key, while `CGSessionCopyCurrentDictionary()` is the public API boundary
- [x] add the new source/test files to `Mahu.xcodeproj/project.pbxproj` if needed
- [x] run targeted screen-lock state provider tests - must pass before Task 2

### Task 2: Add distributed screen-lock notification observer

- [x] add failing tests proving `com.apple.screenIsLocked` delivered through an injected distributed notification center maps to the lock/away callback
- [x] add failing tests proving `com.apple.screenIsUnlocked` delivered through an injected distributed notification center maps to the unlock/active callback
- [x] add failing tests proving observer cancellation removes distributed observers and is idempotent
- [x] create a focused observer seam, for example `Mahu/ScreenLockObservation.swift`, using `DistributedNotificationCenter.default()` in production and injectable notification delivery in tests
- [x] preserve main-actor delivery and cancellation safety following the `SleepWakeObservation.swift` / `SessionActivityObservation.swift` pattern
- [x] add the new source/test files to `Mahu.xcodeproj/project.pbxproj` if needed
- [x] run targeted screen-lock observer tests - must pass before Task 3

### Task 3: Compose session-switch and screen-lock events into one away source

- [x] add failing tests proving existing `NSWorkspace.sessionDidResignActiveNotification` / `sessionDidBecomeActiveNotification` still map to away/active callbacks
- [x] add failing tests proving distributed screen-lock events and `NSWorkspace` session-switch events can both feed the same away/active coordinator seam without duplicate-state regressions
- [x] introduce a semantically accurate combined registrar name if needed, such as `UserAwayActivityObservationRegistrar`, while keeping old session-switch observer behavior intact
- [x] update `AppCoordinator` and `AppDelegate` dependency names/signatures only as much as needed to stop treating `NSWorkspace` as the whole screen-lock model
- [x] ensure duplicate lock/unlock events from multiple sources remain idempotent by relying on existing coordinator guards or adding narrowly scoped guards if tests require them
- [x] run targeted combined-observer and existing session activity tests - must pass before Task 4

### Task 4: Preserve startup lock latch behavior

- [x] add failing `AppDelegate` tests proving a startup screen-lock state sample starts `AppCoordinator` in away/inactive mode even if no `NSWorkspace` notification fires
- [x] add failing `AppDelegate` tests proving a distributed lock notification before `applicationDidFinishLaunching` latches away startup state
- [x] add failing `AppDelegate` tests proving unlock before `applicationDidFinishLaunching` clears the startup away latch
- [x] update `AppDelegate` startup wiring to sample screen-lock current state and observe pre-launch lock/unlock events alongside existing session activity events
- [x] preserve test-mode startup suppression through `MAHU_DISABLE_APP_COORDINATOR_STARTUP=1` and XCTest environment detection
- [x] run targeted `SmokeTests` / AppDelegate startup tests - must pass before Task 5

### Task 5: Verify coordinator lock-away semantics through the corrected model

- [x] add focused coordinator tests proving the screen-lock event path suppresses a near-expired active work boundary without overlay or completion sound
- [x] add focused coordinator tests proving screen lock during active rest closes overlays silently and does not play completion sound
- [x] add focused coordinator tests proving repeated locked ticks do not consume elapsed and do not query the HID idle provider
- [x] add focused coordinator tests proving unlock clears `Away`, refreshes the baseline, and resumes fresh work or preserved paused state without consuming locked duration
- [x] add focused coordinator tests proving duplicate `NSWorkspace` + distributed lock/unlock events do not double-reset fresh work or regress tray state
- [x] keep new tests in a focused file if existing coordinator test files are already too large
- [x] run targeted coordinator lock-away tests - must pass before Task 6

### Task 6: Preserve tray, idle-away, and sleep/wake boundaries

- [x] add or update tests proving paused reminders show `Paused`, not `Away`, when a screen-lock event arrives during paused work
- [x] add or update tests proving optional tray timer mode shows bounded `Away` for screen-lock suppression and icon-only mode remains icon-only
- [x] add or update tests proving enabled idle-away still works after a lock/unlock episode and disabled idle-away still does not query HID idle while active
- [x] add or update tests proving sleep/wake semantics remain separate from screen-lock notifications and long-sleep recovery still closes active breaks silently
- [x] update status/tray/idle/sleep wiring only if these tests reveal a regression from the corrected observation model (not needed; tests passed without production changes)
- [x] run targeted status item, idle-away, and sleep/wake tests - must pass before Task 7

### Task 7: Update documentation and decision history

- [x] update `README.md` to explain screen lock, session switch, idle-away, and sleep/wake as distinct lifecycle signals
- [x] update `README.md` manual checks so Apple Menu → Lock Screen is a primary acceptance scenario and no longer depends on `NSWorkspace` session-switch notifications
- [x] update `AGENTS.md` product invariants to state that ordinary screen lock uses an isolated best-effort distributed screen-lock observer plus current-state check, while `NSWorkspace` remains for session switching
- [x] append `docs/decisions.md` entry documenting why Mahu accepts isolated distributed `com.apple.screenIsLocked/unlocked` notifications and `CGSSessionScreenIsLocked` current-state sampling despite Apple documentation caveats
- [x] remove or correct outdated docs language that says distributed screen-lock notification names must not be used as a primary practical lock source for ordinary Lock Screen behavior
- [x] run `git diff --check` - must pass before Task 8

### Task 8: Verify acceptance criteria

 - [x] verify the implementation distinguishes screen lock from `NSWorkspace` session switch in naming, docs, and tests
 - [x] verify Apple Menu style screen lock is covered by automated tests through injected distributed notification delivery and current-state sampling
 - [x] verify existing `NSWorkspace` session-switch behavior still works and remains registered through `NSWorkspace.shared.notificationCenter`
 - [x] verify screen-lock away suppression prevents elapsed consumption, HID idle polling, break overlay presentation, and completion sound
 - [x] verify active work locks into fresh work, active rest closes silently, paused work remains paused, and unlock clears `Away` without consuming locked time
 - [x] verify `Away` remains bounded by `Paused` and icon-only tray mode remains icon-only
 - [x] run targeted tests for new/changed screen-lock, session activity, startup, coordinator, status, idle-away, and sleep/wake behavior
 - [x] run full test suite with `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
 - [x] run build with `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
 - [x] run `make build`
 - [x] run `git diff --check`

## Technical Details

### Corrected lifecycle model

Mahu should model user-away lifecycle inputs as separate sources that feed a shared away/active reconciliation path:

- **Screen lock**: ordinary Lock Screen, including Apple Menu → Lock Screen and Control-Command-Q. Practical live events are distributed `com.apple.screenIsLocked` / `com.apple.screenIsUnlocked`; current state can be sampled through `CGSessionCopyCurrentDictionary()`.
- **Session switch**: user session switches out/in, including Fast User Switching style transitions. Public AppKit notifications are `NSWorkspace.sessionDidResignActiveNotification` / `sessionDidBecomeActiveNotification`.
- **Idle-away**: optional config-gated HID idle threshold while the Mac is awake and user session is active.
- **Sleep/wake**: device sleep/wake reconciliation, including long-sleep reset behavior.

Once any screen-lock/session-away source marks the user away, coordinator semantics should remain the same:

- active work → reset to a fresh work interval and show `Away` when tray timer state is enabled;
- active rest → close overlays silently, do not play completion sound, and reset to fresh work;
- paused work → remain paused and show `Paused`, not `Away`;
- locked/away ticks → do not consume elapsed, do not query HID idle, do not create overlays, and do not play sounds;
- unlock/active → clear `Away`, refresh uptime baselines, and resume from fresh work or paused state.

### Public API and practical API boundaries

Apple-documented public APIs:

```swift
NSWorkspace.sessionDidResignActiveNotification
NSWorkspace.sessionDidBecomeActiveNotification
NSWorkspace.shared.notificationCenter
CGSessionCopyCurrentDictionary()
kCGSessionOnConsoleKey
```

Practical observed screen-lock inputs:

```swift
Notification.Name("com.apple.screenIsLocked")
Notification.Name("com.apple.screenIsUnlocked")
"CGSSessionScreenIsLocked"
```

Implementation requirements:

- isolate practical string dependencies in one small file or helper;
- document them as best-effort, non-invasive, and not Apple-documented stable constants;
- keep behavior idempotent if multiple sources fire for one lock episode;
- do not use event taps, Accessibility/Input Monitoring, private APIs, or input capture.

### Suggested targeted verification commands

Use exact test class names that exist after implementation; adjust only if new focused test files have different names.

```bash
xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO \
  -only-testing:MahuTests/LiveSessionActivityObservationRegistrarTests \
  -only-testing:MahuTests/FakeSessionActivityObserverRegistrarTests \
  -only-testing:MahuTests/SmokeTests \
  -only-testing:MahuTests/AppCoordinatorSessionInactiveTickSuppressionTests
```

Final verification:

```bash
xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO
xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO
make build
git diff --check
```

## Post-Completion

*Items requiring manual intervention or external systems - no checkboxes, informational only.*

**Manual verification**:

- Before running ralphex, resolve the current dirty worktree so this plan's changes do not mix with unrelated idle/sleep test changes.
- Relaunch the rebuilt `build/Mahu.app` after implementation; manual config edits still apply only after relaunch.
- With short config such as `workDurationSeconds: 10`, `breakDurationSeconds: 5`, and tray timer enabled, use Apple Menu → Lock Screen before the work timer expires and confirm:
  - tray transitions to bounded `Away` if visible;
  - no break overlay appears while locked;
  - no completion sound plays while locked;
  - unlock returns to fresh work or preserved `Paused` state.
- Repeat with Control-Command-Q.
- Repeat with auto-lock if configured.
- Lock during an active break and confirm overlays close silently and no completion sound plays.
- Confirm `Away` fits within the same tray footprint as `Paused` and does not move the tray icon.
- Test external display/fullscreen Spaces behavior if available, because overlay/window behavior can differ by display/session transition.
- If pursuing App Store distribution later, re-evaluate the documented stability risk of distributed lock notification names and the `CGSSessionScreenIsLocked` key during release review.

**External/system caveats**:

- Apple does not document `com.apple.screenIsLocked` / `com.apple.screenIsUnlocked` as stable notification constants.
- Apple does not list `CGSSessionScreenIsLocked` among the standard documented Window Server Session Properties, even though `CGSessionCopyCurrentDictionary()` itself is public.
- These practical inputs are accepted here because the documented `NSWorkspace` session-switch notification did not fire for ordinary Apple Menu Lock Screen, and Mahu's product requirement is to avoid hidden overlays/sounds while the screen is locked.
