# Sleep/Wake Timer Reconciliation

## Status

Completed on 2026-06-03. Archived under `docs/plans/completed/` after external review follow-up fixes.
This change set addresses Tasks 1-9 in this plan.

## Overview

Implement sleep/wake timer reconciliation for Mahu's public-ready release path. Today Mahu intentionally advances timers only while the Mac is awake, but it does not reconcile long sleeps: if the work timer had only a few minutes remaining before the user closed the laptop for lunch, Mahu may show a break soon after wake even though the user was away for a long time.

This plan adds bounded sleep/wake lifecycle handling: after a long sleep, Mahu starts a fresh work interval instead of preserving near-expired work state. Short sleeps preserve the current timer state. The implementation must use public macOS APIs, keep `BreakTimer` pure, avoid live config reload, and avoid growing `AppCoordinator` with bulky notification code.

## Context (from discovery)

- Files/components involved:
  - `Mahu/AppCoordinator.swift`: owns timer orchestration, pause/resume, runtime settings, uptime baseline, pending elapsed time, overlay show/hide/update flow. Currently uses `ProcessInfo.processInfo.systemUptime` through an injected `currentUptime` seam.
  - `Mahu/AppCoordinatorSupport.swift`: coordinator seams for timer, status item, overlay, scheduler/current uptime; likely location for sleep/wake seam declarations.
  - `Mahu/BreakTimer.swift`: pure work/rest state machine; should remain unaware of sleep/wake and notifications.
  - `Mahu/BreakOverlayManager.swift`: overlay window lifecycle; active break teardown must not play completion sound when long sleep reconciliation resets to fresh work.
  - `Mahu/BreakScreenObservation.swift` and `Mahu/BreakOverlayManager.swift`: existing examples of notification observer registration/cancellation patterns.
  - `MahuTests/AppCoordinatorTestSupport.swift`: fake timer/status/overlay/runtime settings support; needs fake sleep/wake registrar.
  - `MahuTests/AppCoordinatorTests.swift`, `AppCoordinatorBreakPresentationTests.swift`, `AppCoordinatorReminderPauseTests.swift`, `AppCoordinatorBreakSoundTests.swift`, and runtime-settings tests: likely affected by wake-reset policies.
  - `README.md`, `AGENTS.md`, `docs/decisions.md`: currently document sleep/wake reconciliation as deferred and timers as awake-time only.
- Related patterns found:
  - `AppCoordinator` already resets work interval on resume and runtime settings work-duration changes.
  - Active rest phase preserves countdown/Skip state across display visibility changes; reconciliation must explicitly choose how long sleep differs from transient display disappearance.
  - Natural visible rest completion plays sound once; forced reset after long sleep must not trigger completion sound.
  - No live config reload: wake handling should use current runtime settings, not reread `config.json`.
  - `AppCoordinator.swift` is near/over the local readability threshold, so observer registration and sleep/wake support should live in focused support files.
- Dependencies identified:
  - AppKit public notifications: `NSWorkspace.willSleepNotification` and `NSWorkspace.didWakeNotification` via `NSWorkspace.shared.notificationCenter`.
  - A testable wall-clock time seam to measure sleep duration; awake uptime alone cannot measure time spent asleep.

## Development Approach

- **Testing approach**: TDD.
- Complete each task fully before moving to the next.
- Make small, focused changes.
- **CRITICAL: every task MUST include new/updated tests** for code changes in that task.
  - tests are not optional - they are a required part of the checklist
  - write unit tests for new functions/methods
  - write unit tests for modified functions/methods
  - add new test cases for new code paths
  - update existing test cases if behavior changes
  - tests cover both success and error scenarios
- **CRITICAL: all tests must pass before starting next task** - no exceptions.
- **CRITICAL: update this plan file when scope changes during implementation**.
- Run tests after each change.
- Maintain backward compatibility: no config schema changes, no Settings UI, and no live file reload.

## Testing Strategy

- **Unit tests**: required for every task.
- **Observer seam tests**: prove live/custom registrar behavior and cancellation without requiring real system sleep.
- **Coordinator policy tests**: prove long/short sleep handling across work, paused work, active rest, and wake-without-prior-sleep cases.
- **Regression tests**: prove no accidental break sound on long-sleep rest reset, no immediate break after wake with nearly expired work timer, and no timer advancement while paused.
- **E2E tests**: no UI E2E suite exists. Real lid-close/wake behavior remains manual-only.

## Progress Tracking

- Mark completed items with `[x]` immediately when done.
- Add newly discovered tasks with ➕ prefix.
- Document issues/blockers with ⚠️ prefix.
- Update plan if implementation deviates from original scope.
- Keep plan in sync with actual work done.

## What Goes Where

- **Implementation Steps** (`[ ]` checkboxes): tasks achievable within this codebase - code changes, tests, documentation updates.
- **Post-Completion** (no checkboxes): items requiring external action - real sleep/wake manual validation on hardware.
- **Checkbox placement**: Checkboxes belong only in Task sections (`### Task N:` or `### Iteration N:`). Do not put checkboxes in Success criteria, Overview, or Context — they cause extra loop iterations.

## Implementation Steps

### Task 1: Add sleep/wake observation seam

- [x] add tests for a test sleep/wake registrar that can deliver `willSleep` and `didWake` callbacks deterministically
- [x] add tests for live registrar cancellation being idempotent and preventing later deliveries where practical
- [x] add a focused `SleepWakeObservation` support file or equivalent seam using public `NSWorkspace` notifications
- [x] expose an injected cancellation handle/type without embedding notification code directly in `AppCoordinator`
- [x] run new observer seam tests - must pass before Task 2

### Task 2: Add coordinator dependencies and non-destructive wake baseline handling

- [x] add tests proving `didWake` without a recorded `willSleep` does not reset timer destructively
- [x] add tests proving wake handling updates `lastTickUptime`/baseline so the next scheduler tick does not consume stale elapsed time
- [x] inject sleep/wake registrar and wall-clock provider into `AppCoordinator` through focused seams
- [x] register observation on coordinator start and cancel observation on teardown/deinit
- [x] keep `BreakTimer` unchanged and sleep/wake-unaware
- [x] run focused coordinator startup/teardown tests - must pass before Task 3

### Task 3: Reset active work after long sleep

- [x] add test where work timer has little time remaining, long sleep occurs, and wake resets to a fresh full work interval
- [x] add test proving the next tick after long sleep does not immediately transition to rest
- [x] add test proving short sleep below the internal threshold preserves remaining work time
- [x] implement internal `longSleepResetThresholdSeconds` policy with default `300` seconds and no config field
- [x] reset pending elapsed, uptime baseline, timer, and status display after long sleep during active work
- [x] run focused work-phase sleep/wake tests - must pass before Task 4

### Task 4: Preserve paused work semantics across sleep/wake

- [x] add test proving long sleep while reminders are paused keeps reminders paused and does not show a break
- [x] add test proving long sleep while paused resets pending elapsed/baseline so no hidden work time is consumed
- [x] add test proving resume after long sleep starts a fresh work interval from current runtime settings
- [x] implement paused-work sleep/wake policy without changing the pause/resume menu contract
- [x] run pause/reminder sleep/wake tests - must pass before Task 5

### Task 5: Handle active rest across short and long sleep

- [x] add test proving short sleep during active rest preserves the current break countdown and overlay state
- [x] add test proving long sleep during active rest hides the old overlay and starts a fresh work interval
- [x] add test proving long sleep during active rest does not play break completion sound
- [x] add test proving long sleep during active rest preserves `Skip`/overlay teardown invariants and does not call natural-completion paths
- [x] implement rest-phase sleep/wake policy using existing overlay teardown seams where possible
- [x] run active-rest sleep/wake and break-sound tests - must pass before Task 6

### Task 6: Preserve integration behavior and regressions

- [x] add regression test proving runtime settings are not reloaded from disk on wake
- [x] add regression test proving status item timer display updates to full work duration after long sleep reset
- [x] add regression test proving sleep/wake observation cancellation prevents callbacks after coordinator teardown
- [x] update existing coordinator tests affected by the new observer dependency
- [x] run relevant coordinator, runtime settings, status item, overlay, and sound tests - must pass before Task 7

### Task 7: Verify acceptance criteria

- [x] verify long sleep during work starts a fresh work interval
- [x] verify short sleep preserves current timer phase/countdown
- [x] verify paused reminders remain paused after long sleep
- [x] verify long sleep during active rest closes/reset without completion sound and starts fresh work
- [x] verify `didWake` without previous `willSleep` is non-destructive
- [x] verify no config schema changes and no file watching were introduced
- [x] run full unit test suite: `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run raw build: `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run app bundle build: `make build`

### Task 8: Update documentation and decision history

- [x] update `README.md` Current Behavior to remove the old “sleep is not reconciled yet” gap
- [x] remove or revise the sleep/wake deferred feature entry in `README.md`
- [x] add README manual checks for long sleep, short sleep, paused work, and active break sleep/wake scenarios
- [x] update `AGENTS.md` product invariants/deferred features to reflect shipped sleep/wake reconciliation
- [x] append `docs/decisions.md` with the sleep/wake policy, threshold rationale, and public-API observer decision
- [x] run documentation-adjacent checks available in the project, or note if there are none (no dedicated docs-only checker exists in this repo; validated by manual doc review plus `xcodebuild test`, `xcodebuild build`, and `make build`)

### Task 9: Final plan close-out

- [x] update this plan file if implementation deviated from the original task sequence (no sequence deviation; tasks were completed in the planned order)
- [x] ensure all completed implementation checkboxes are marked `[x]`
- [x] add any newly discovered manual verification limitations to Post-Completion

*Note: ralphex automatically moves completed plans to `docs/plans/completed/`.*

## Technical Details

- Long-sleep threshold:
  - Internal constant: `300` seconds.
  - Not a config field in this plan.
  - Rationale: avoids expanding the manual config contract before there is Settings UI; prevents lunch/closed-lid returns from triggering immediate breaks while preserving short sleep/lock behavior.
- Observation flow:
  - On `willSleep`: record wall-clock sleep start.
  - On `didWake`: reset uptime baseline; if recorded wall-clock sleep duration is at least threshold, apply reconciliation policy.
  - If `didWake` arrives without recorded `willSleep`: do not destructively reset phase/timer; only prevent stale elapsed consumption.
- Long sleep policies:
  - Active work: reset to a fresh work interval from current runtime settings.
  - Paused work: remain paused, clear pending elapsed/baseline, and let resume start fresh from current runtime settings.
  - Active rest: hide old overlay without completion sound and start fresh work interval.
- Short sleep policies:
  - Preserve current work/rest phase and countdown state.
  - Reset baseline so the next tick does not consume sleep-related stale elapsed time.
- Responsibility boundaries:
  - `BreakTimer` remains pure.
  - Sleep/wake observer code lives outside `AppCoordinator` where practical.
  - `AppCoordinator` owns policy routing and timer/overlay/status state transitions.
  - No live config reload, no Settings UI, no private APIs.

## Post-Completion

*Items requiring manual intervention or external systems - no checkboxes, informational only.*

**Manual verification**:

- Set short work duration, wait until the work timer is near expiration, sleep the Mac longer than 5 minutes, wake it, and confirm the timer starts fresh and no immediate break appears.
- Repeat with a short sleep below threshold and confirm the timer continues from the previous remaining time.
- Repeat while reminders are paused and confirm Mahu stays paused and does not show a break.
- Repeat during an active break and confirm Mahu exits the old break without completion sound and starts a fresh work interval.
- Confirm real `NSWorkspace` sleep/wake notifications are received on lid close/open and menu Apple sleep/wake flows.
- Fullscreen Spaces and external-display wake ordering remain manual-only because XCTest uses registrar fakes and cannot prove live WindowServer notification timing after sleep.

**External system updates**:

- None expected.
