# Session Lock Away Reconciliation

## Overview

Treat macOS session lock / session inactive transitions as an immediate away state for Mahu, independent of HID idle duration and independent of `idleAwayResetEnabled`.

Manual verification showed the configurable idle-away fix works, but lock screen has a separate failure mode: locking the screen does not immediately make Mahu away, so a near-expired work timer can reach a break while the user cannot see the overlay. If the overlay later completes naturally, the completion sound can still play. Keyboard or mouse input on the lock screen can also reset CoreGraphics HID idle time, so `idleAwayResetThresholdSeconds` cannot reliably protect this case.

This plan adds a public `NSWorkspace` session activity observer and reconciles session inactive/active transitions through coordinator-owned timer state:

- while the user session is inactive, do not consume ordinary elapsed work/rest time;
- do not present break overlays or play completion sounds while locked/inactive;
- active work enters a fresh work interval and shows `Away` in optional tray timer mode;
- active rest closes silently into fresh work;
- paused reminders remain paused;
- unlock clears `Away`, refreshes timer baselines, and resumes from the fresh work / paused state.

## Context (from discovery)

- Files/components involved:
  - `Mahu/AppCoordinator.swift` — central timer orchestration, idle-away suppression, sleep/wake reconciliation, overlay show/hide, and sound gating. It is already large, so implementation should keep changes minimal and push observer/policy details into focused helpers where possible.
  - `Mahu/SleepWakeObservation.swift` — existing `NSWorkspace` observer seam pattern for `willSleep` / `didWake`; best template for a new session activity observer.
  - `Mahu/IdleAwayReconciliationPolicy.swift` — shared active-work / paused-work / active-rest recovery outcomes; useful for aligning session lock recovery semantics without involving HID idle.
  - `Mahu/UserIdleTimeProvider.swift` — CoreGraphics HID idle provider; session lock handling must not rely on this provider while the session is inactive.
  - `Mahu/AppCoordinatorSupport.swift` — coordinator seams, `BreakOverlayManaging`, `StatusItemControlling`, and scheduler types.
  - `Mahu/StatusDisplayFormatter.swift` and `Mahu/StatusItemController.swift` — existing `Away` tray state and width/anchor behavior.
  - `Mahu/BreakOverlayManager.swift` — overlay lifecycle and focus-retention observer; do not add lock detection here unless coordinator ownership proves impossible.
  - `MahuTests/AppCoordinatorTestSupport.swift` — fake registrars, fake status item, fake overlay, fake sound player, scripted idle provider; add a fake session activity registrar here or in a focused test support file.
  - `MahuTests/LiveSleepWakeObservationRegistrarTests.swift` — template for live observer registration/cancellation tests.
  - `MahuTests/AppCoordinatorIdleAwayPhaseBehaviorTests.swift`, `MahuTests/AppCoordinatorSleepWakeAccountingTests.swift`, and `MahuTests/AppCoordinatorBreakSoundTests.swift` — relevant coordinator behavior coverage.
  - `README.md`, `AGENTS.md`, and `docs/decisions.md` — user-facing behavior, product invariants, and decision history.
- Related patterns found:
  - Idle-away reset is now opt-in and config-gated; lock/session inactive suppression is a separate safety/lifecycle behavior and should stay always-on for now.
  - `Away` is already the bounded tray label for suppression and must not require more width than `Paused`.
  - Long sleep and long away active-rest recovery closes overlays silently and does not play completion sound.
  - `BreakTimer` remains pure and must not learn about session lock or UI state.
  - Runtime settings remain the in-process source of truth; no live config reload or disk re-read should be introduced.
  - Manual validation remains required for real macOS session lock/unlock paths.
- Dependencies identified:
  - Preferred public APIs from Apple docs:
    - `NSWorkspace.sessionDidResignActiveNotification`
    - `NSWorkspace.sessionDidBecomeActiveNotification`
    - registration through `NSWorkspace.shared.notificationCenter`
  - External context: `.tmp/external-context/apple-macos-session-state/session-lock-and-screen-sleep-notifications.md`.
  - Avoid using undocumented distributed notification names such as `com.apple.screenIsLocked` / `com.apple.screenIsUnlocked` as the primary mechanism.
  - `ralphex` is installed at `/opt/homebrew/bin/ralphex`.

## Selected Approach

Chosen purpose: **Session lock away suppression**.

Chosen scope: **Observer seam + AppCoordinator suppression + `Away` tray + docs**.

Chosen semantics:

- Session lock / inactive is an immediate away signal, not a threshold-based idle event.
- Session lock suppression is always-on and does not depend on `idleAwayResetEnabled`.
- On session inactive:
  - active work → fresh work interval, suppress elapsed while inactive, show `Away` in optional tray timer mode;
  - active rest → close overlay silently, do not play completion sound, move to fresh work;
  - paused work → remain paused and do not show `Away` over `Paused`;
  - clear pending elapsed and refresh uptime baseline;
  - reset/re-arm idle-away episode state so lock-screen input cannot affect the next enabled idle-away episode.
- While session inactive:
  - do not consume ordinary elapsed time;
  - do not query the HID idle provider;
  - do not present break overlays;
  - do not play completion sound.
- On session active:
  - clear session-away suppression / `Away`;
  - refresh uptime baseline so locked time is not consumed on the next tick;
  - continue from the fresh work interval or paused state established on lock.

## Development Approach

- **Testing approach**: TDD.
- Complete each task fully before moving to the next.
- Make small, focused changes.
- Keep `AppCoordinator.swift`, `AppCoordinatorSupport.swift`, and `BreakOverlayManager.swift` from growing substantially; add focused observer/support files where possible.
- **CRITICAL: every task MUST include new/updated tests** for code changes in that task:
  - tests are not optional;
  - write observer tests for registration/cancellation and fake delivery;
  - write coordinator tests for active work, paused work, active rest, locked ticks, unlock baseline, sound suppression, and idle-provider isolation;
  - write/update tray state tests for session-lock `Away` if existing `Away` tests do not cover it;
  - update project file membership for any new source/test files.
- **CRITICAL: all tests must pass before starting next task** - no exceptions.
- **CRITICAL: update this plan file when scope changes during implementation**.
- Run targeted tests after each task.
- Maintain backward compatibility and do not add new config keys for this feature.

## Testing Strategy

- **Unit tests** are required for every task.
- Use injected session activity registrars in coordinator tests; unit tests must not require real screen locking.
- Use an idle provider fake that fails if queried while session inactive.
- Required observer coverage:
  - live registrar observes `NSWorkspace.sessionDidResignActiveNotification` and `sessionDidBecomeActiveNotification` through the workspace notification center;
  - cancellation removes observers and is idempotent;
  - fake registrar can fire inactive/active callbacks deterministically.
- Required coordinator coverage:
  - near-expired active work + session inactive resets to fresh work and does not present break overlay;
  - active rest + session inactive hides overlay silently and does not play completion sound;
  - paused work + session inactive remains paused and resumes as paused;
  - repeated ticks while session inactive do not consume elapsed and do not query the HID idle provider;
  - session active clears `Away` and refreshes baseline so locked duration is not consumed on the next tick;
  - session active without prior inactive is non-destructive;
  - session inactive resets/re-arms idle-away state so lock-screen input does not leak into later enabled idle-away suppression.
- Required tray/status coverage:
  - optional tray timer mode shows `Away` while session-away suppression is active;
  - icon-only mode remains icon-only;
  - paused reminders show `Paused`, not `Away`;
  - `Away` still fits within the existing `Paused` title-slot constraint.

## Progress Tracking

- Mark completed items with `[x]` immediately when done.
- Add newly discovered tasks with a `➕` prefix.
- Document issues/blockers with a `⚠️` prefix.
- Update plan if implementation deviates from original scope.
- Keep the plan in sync with actual work done.

## What Goes Where

- **Implementation Steps**: code changes, tests, documentation/decision updates, and deterministic verification commands.
- **Post-Completion**: manual lock/unlock checks, Fast User Switching checks, real tray checks, and release/signing checks.
- **Checkbox placement**: checkboxes belong only in Task sections. Do not add checkboxes to Overview, Context, Technical Details, Success Criteria, or Post-Completion.

## Implementation Steps

### Task 1: Add session activity observer seam

- [x] add failing tests for a fake session activity registrar that can fire inactive and active callbacks deterministically
- [x] add failing live observer tests using posted `NSWorkspace.sessionDidResignActiveNotification` / `sessionDidBecomeActiveNotification` notifications and idempotent cancellation expectations
- [x] create `Mahu/SessionActivityObservation.swift` with an injectable registrar/cancellation model based on the sleep/wake observer pattern
- [x] register with `NSWorkspace.shared.notificationCenter`, not `NotificationCenter.default`
- [x] add new source/test files to `Mahu.xcodeproj/project.pbxproj` if needed
- [x] run targeted session activity observer tests - must pass before Task 2

### Task 2: Reconcile session inactive in AppCoordinator

- [x] add failing coordinator tests proving near-expired active work + session inactive resets to a fresh work interval and does not show a break overlay
- [x] add failing coordinator tests proving active rest + session inactive hides the overlay silently and does not play completion sound
- [x] add failing coordinator tests proving paused work + session inactive stays paused and does not emit `Away` over `Paused`
- [x] wire the session activity registrar into `AppCoordinator` with minimal coordinator changes and safe cancellation
- [x] implement session inactive handling: clear pending elapsed, refresh uptime baseline, reset/re-arm idle-away state, apply fresh work / preserve paused semantics, and set session-away suppression state
- [x] run targeted coordinator session-inactive tests - must pass before Task 3

### Task 3: Suppress ticks and idle polling while session inactive

- [x] add failing tests proving repeated scheduled ticks while session inactive do not consume elapsed time and do not query the HID idle provider
- [x] add failing tests proving no break overlay is created and no completion sound plays while session inactive even if the work/rest timer would otherwise cross a boundary
- [x] update coordinator tick flow so session-away suppression has higher priority than idle-away polling and ordinary elapsed consumption
- [x] ensure session inactive state remains independent of `idleAwayResetEnabled` and current idle-away threshold settings
- [x] run targeted locked-tick suppression and break sound tests - must pass before Task 4

### Task 4: Reconcile session active / unlock

- [x] add failing tests proving session active clears `Away` and refreshes the uptime baseline so locked duration is not consumed on the next tick
- [x] add failing tests proving session active without prior session inactive is non-destructive
- [x] add failing tests proving session inactive followed by active re-arms idle-away state so later enabled idle-away detection uses fresh awake/user-session state
- [x] implement session active handling to clear session-away suppression, refresh timer/status display, and keep the fresh work or paused state established on lock
- [x] handle Apple’s documented edge case where session inactive notification may arrive during launch without crashing or double-starting state
- [x] run targeted session active/unlock tests - must pass before Task 5

### Task 5: Preserve `Away` tray constraints for session lock

 - [x] add or update tests proving optional tray timer mode shows `Away` while session-away suppression is active
 - [x] add or update tests proving icon-only mode remains icon-only while session-away suppression is active
 - [x] add or update tests proving `Paused` remains distinct from session-away `Away`
 - [x] add or update tests proving `Away` still does not require more title width than `Paused` and does not break icon anchoring
 - [x] update status item/coordinator display wiring only if existing `Away` support is not sufficient for session-lock suppression
 - [x] run targeted status item / tray anchor tests - must pass before Task 6

### Task 6: Update documentation and decision history

- [x] update `README.md` with session lock behavior, lock/unlock manual checks, and the distinction between session-lock suppression and config-gated idle-away reset
- [x] update `AGENTS.md` with the product invariant that session inactive/lock suppression is always-on and uses bounded `Away` in optional tray timer mode
- [x] append a `docs/decisions.md` entry for using public `NSWorkspace` session active/inactive notifications and keeping lock suppression config-independent
- [x] reference `.tmp/external-context/apple-macos-session-state/session-lock-and-screen-sleep-notifications.md` only as external research context if helpful; do not make app behavior depend on undocumented distributed lock notifications
- [x] run `git diff --check` - must pass before Task 7

### Task 7: Verify acceptance criteria

 - [x] verify lock/session inactive is handled through public `NSWorkspace` session notifications, not private APIs or distributed lock notification names
 - [x] verify session inactive suppresses elapsed consumption, HID idle polling, break overlay presentation, and completion sound
 - [x] verify active work locks into fresh work, active rest closes silently, and paused work remains paused
 - [x] verify unlock clears `Away`, refreshes uptime baseline, and resumes from fresh work / paused state without consuming locked time
 - [x] verify session-lock behavior is always-on and does not depend on `idleAwayResetEnabled`
 - [x] verify `Away` remains bounded by `Paused` and icon-only tray mode remains icon-only
 - [x] run full unit test suite with `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
 - [x] run build with `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
 - [x] run `make build`
 - [x] run `git diff --check`

## Technical Details

### Public notification source

Use AppKit `NSWorkspace` session activity notifications:

```swift
NSWorkspace.sessionDidResignActiveNotification
NSWorkspace.sessionDidBecomeActiveNotification
```

Registration must use:

```swift
NSWorkspace.shared.notificationCenter
```

The notification object is the shared `NSWorkspace` instance and the notifications do not provide `userInfo`, so the coordinator must own any session state.

### Rejected primary sources

- `com.apple.screenIsLocked` / `com.apple.screenIsUnlocked` distributed notifications are widely observed but not documented by Apple as stable public notification names; do not use them as the primary mechanism.
- Event taps, Accessibility/Input Monitoring, and input capture are out of scope and violate the project’s public-API/App Store posture.
- HID idle duration is not sufficient for lock screen handling because keyboard/mouse events on the lock screen can reset the idle timer.

### Session lock policy

Session inactive is an immediate away signal:

- no threshold;
- no config flag;
- no disk config reload;
- no `BreakTimer` changes.

Coordinator state should give session-away suppression priority over idle-away polling and ordinary timer advancement.

### Relationship to idle-away and sleep/wake

- Idle-away remains opt-in through `idleAwayResetEnabled` and threshold-based while macOS stays awake and the user session is active.
- Session lock suppression is always-on because it prevents hidden overlays and sounds while the user cannot see the app.
- Device sleep/wake reconciliation remains separate and should keep its current long-sleep semantics.

## Post-Completion

*Items requiring manual intervention or external systems - no checkboxes, informational only.*

**Manual verification**:

- With missing/default config and a short work timer, lock the screen before expiration and confirm Mahu does not show a break overlay or play completion sound while locked.
- Unlock and confirm the tray returns from `Away` to a fresh work countdown, or remains `Paused` if reminders were paused.
- Lock during an active break and confirm the overlay closes silently with no completion sound.
- Confirm `Away` fits within the same tray footprint as `Paused` and does not move the tray icon.
- Test common lock paths: Control-Command-Q, Apple menu Lock Screen, auto-lock, and if possible Fast User Switching.
- Test with external display/fullscreen Spaces if available, because overlay/window behavior can differ by display/session transition.

**Future follow-up**:

- If manual testing shows `NSWorkspace.sessionDidResignActiveNotification` misses a specific lock path, consider a separate explicit decision for a best-effort distributed-notification fallback, isolated behind a small observer seam.
- If users later need alternate unlock behavior, consider a configurable recovery mode, but keep overlay/sound suppression while locked as a safety invariant.
