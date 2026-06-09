# Idle Away Timer Reset

## Overview

Add idle/away-based timer reconciliation for users who step away from the computer without putting macOS to sleep.

Mahu already treats long sleep as sufficient rest and resets to a fresh work session. This plan adds the analogous behavior for long system idle periods: if the user has been away for at least 300 seconds while the Mac stays awake, Mahu should treat that away time as rest and avoid immediately interrupting the user with a stale near-expired work timer or stale break overlay when they return.

This plan keeps the existing sleep/wake behavior, timer semantics, and config schema intact. It adds a public CoreGraphics idle-time seam, policy tests, and minimal coordinator wiring. It does not add live config reload, event taps, Accessibility/Input Monitoring, or private APIs.

## Context (from discovery)

- Files/components involved:
  - `Mahu/AppCoordinator.swift` — owns timer ticks, sleep/wake reconciliation, overlay transitions, and runtime settings usage; already large, so only minimal wiring and small helper calls belong here.
  - `Mahu/AppCoordinatorSupport.swift` — contains sleep/wake policy helpers and runtime settings support; already large, so avoid putting live idle API implementation here.
  - `Mahu/SleepWakeObservation.swift` — existing public lifecycle seam; idle should be a separate seam, not mixed into sleep observer code.
  - New focused idle provider file, e.g. `Mahu/UserIdleTimeObservation.swift` or `Mahu/IdleActivityObservation.swift`.
  - New focused tests, preferably `MahuTests/AppCoordinatorIdleAwayResetTests.swift`, instead of growing already-large coordinator tests.
  - `README.md`, `AGENTS.md`, and `docs/decisions.md` for behavior/decision updates.
- Related patterns found:
  - Long sleep uses a fixed internal 300-second threshold.
  - Active work after long sleep resets to a fresh work interval.
  - Paused work stays paused and resumes into a fresh work interval.
  - Active rest after long sleep closes silently into fresh work without completion sound.
  - Runtime settings are read from the in-process store, not reloaded from disk.
  - `BreakTimer` remains pure and should not learn about sleep/idle/user activity.
- Dependencies identified:
  - Recommended public idle API: `CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: CGEventType(rawValue: UInt32.max)!)` from CoreGraphics (`kCGAnyInputEventType`).
  - External context: `.tmp/external-context/macos-idle-time/idle-time-public-apis.md`.
  - Avoid event taps, global input hooks, Accessibility APIs, or IOKit `HIDIdleTime` unless CoreGraphics proves insufficient.

## Development Approach

- **Testing approach**: TDD.
- Complete each task fully before moving to the next.
- Make small, focused changes.
- **CRITICAL: every task MUST include new/updated tests** for code changes in that task:
  - policy tests for threshold boundaries and phase semantics;
  - coordinator tests for active work, paused work, active rest, and repeated idle ticks;
  - provider tests for invalid idle values where feasible.
- **CRITICAL: all tests must pass before starting next task** - no exceptions.
- **CRITICAL: update this plan file when scope changes during implementation**.
- Keep config schema unchanged for this plan.
- Keep idle reset threshold fixed at 300 seconds, matching long sleep threshold.
- Keep idle behavior advisory and failure-tolerant.

## Testing Strategy

- **Unit tests** are required for every task.
- Use injected idle providers in tests; unit tests must not depend on real user inactivity.
- Add a new focused coordinator idle test file rather than adding large blocks to `AppCoordinatorTests.swift`.
- Required coverage:
  - idle `< 300s` preserves normal countdown behavior;
  - idle `== 300s` triggers long-away reset;
  - active work near expiration resets to fresh work and does not immediately start a break;
  - paused work remains paused and resume starts fresh;
  - active rest closes overlay silently and does not play completion sound;
  - repeated ticks while still idle reset only once per idle episode;
  - user activity re-arms the next idle episode;
  - invalid idle values such as NaN/negative values are treated as not idle;
  - runtime settings are used from the current runtime store, not reloaded from disk.
- Manual verification remains required for real macOS HID idle behavior.

## Progress Tracking

- Mark completed items with `[x]` immediately when done.
- Add newly discovered tasks with a `➕` prefix.
- Document issues/blockers with a `⚠️` prefix.
- Update this plan if implementation deviates from the original scope.
- Keep the plan in sync with actual work done.

## What Goes Where

- **Implementation Steps**: code changes, tests, documentation/decision updates, and deterministic verification commands.
- **Post-Completion**: manual idle checks on real macOS hardware/session state.
- **Checkbox placement**: checkboxes belong only in Task sections. Do not add checkboxes to Overview, Context, Technical Details, or Post-Completion.

## Implementation Steps

### Task 1: Add idle time provider seam

- [x] define a small `UserIdleTimeProviding` / `CurrentIdleDurationProvider` seam that returns idle duration in seconds
- [x] add a live CoreGraphics implementation using `CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: CGEventType(rawValue: UInt32.max)!)`
- [x] normalize invalid provider values such as NaN, infinity, and negative seconds into a safe non-idle value
- [x] write tests for invalid value normalization and fake provider behavior
- [x] run targeted idle provider tests - must pass before Task 2

### Task 2: Add long-away reconciliation policy

- [x] add an idle/away reconciliation policy helper near existing sleep/wake policy, without adding large live API code to `AppCoordinatorSupport.swift`
- [x] use the same fixed 300-second threshold semantics as long sleep
- [x] write tests for idle `< 300s`, `== 300s`, and `> 300s`
- [x] write tests for active work, paused work, and active rest policy outcomes
- [x] run targeted policy tests - must pass before Task 3

### Task 3: Wire idle reset into AppCoordinator tick flow

- [x] inject the idle provider into `AppCoordinator` with a safe production default
- [x] check idle duration during the normal timer tick flow before consuming ordinary elapsed work/rest time
- [x] apply long-away reset using current runtime settings, not disk config
- [x] clear pending elapsed time and refresh the uptime baseline when an idle reset is applied
- [x] keep `BreakTimer` free of idle/user-activity logic
- [x] run targeted coordinator idle tests - must pass before Task 4

### Task 4: Prevent repeated resets during one idle episode

- [x] add a one-reset-per-idle-episode guard so repeated ticks while idle `>= 300s` do not repeatedly reset work/rest state
- [x] re-arm idle reset when the idle provider reports activity below the threshold again
- [x] write tests for repeated idle ticks and activity re-arm behavior
- [x] write tests proving launch while already idle does not cause repeated destructive resets
- [x] run targeted idle episode tests - must pass before Task 5

### Task 5: Preserve phase-specific behavior

- [x] test active work near expiration + long idle resets to a full fresh work interval without presenting a break
- [x] test paused work + long idle remains paused and resumes into a fresh work interval
- [x] test active rest + long idle hides the overlay silently and does not play break completion sound
- [x] test short idle preserves existing timer countdown and phase behavior
- [x] test sleep/wake reconciliation remains independent and is not broken by idle polling
- [x] run all coordinator idle/sleep-related tests - must pass before Task 6

### Task 6: Update documentation and decision history

- [x] update `README.md` to describe long idle/away reset behavior and manual checks
- [x] update `AGENTS.md` with the product invariant for long idle resets without sleep
- [x] update `docs/decisions.md` with the CoreGraphics idle provider choice, fixed 300-second threshold, and phase semantics
- [x] run `git diff --check` - must pass before Task 7

### Task 7: Verify acceptance criteria

- [x] verify long idle `>= 300s` is treated as rest/away and resets Mahu to fresh work using current runtime settings (covered by `AppCoordinatorIdleAwayPhaseBehaviorTests` and full suite)
- [x] verify short idle does not trigger destructive reset (covered by `AppCoordinatorIdleAwayResetTests` and `AppCoordinatorIdleAwayPhaseBehaviorTests`)
- [x] verify paused reminders remain paused (covered by `AppCoordinatorIdleAwayPhaseBehaviorTests` and full suite)
- [x] verify active break closes silently on long idle (covered by `AppCoordinatorIdleAwayPhaseBehaviorTests` and full suite)
- [x] verify no config schema change or live config reload was introduced (code inspection: no `AppConfig`/`ConfigStore` schema changes, no file-watcher/live-reload wiring)
- [x] verify no private APIs, event taps, input capture, or Accessibility/Input Monitoring requirements were introduced (code inspection: public CoreGraphics idle query only)
- [x] run full unit test suite with `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run build with `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run `make build`
- [x] run `git diff --check`

## Technical Details

### Idle source

Use CoreGraphics for the live idle provider:

```swift
CGEventSource.secondsSinceLastEventType(
    .hidSystemState,
    eventType: CGEventType(rawValue: UInt32.max)!
)
```

This is a read-only system idle query. It does not install event taps, capture keyboard/mouse input, or require the app to be frontmost.

### Policy

For this plan, long idle uses the same threshold as long sleep:

```swift
300 seconds
```

Behavior by phase:

- active work + long idle → fresh work interval from current runtime settings;
- paused work + long idle → remain paused; resume starts fresh;
- active rest + long idle → close overlay silently and start fresh work;
- short idle → no destructive reset.

Repeated ticks while still idle should not repeatedly reset. Reset should re-arm only after observed user activity drops idle duration below threshold.

### Rejected alternatives

- Add config schema now: rejected to keep scope small and because no Settings UI exists yet.
- Use event taps/global hooks: rejected because they are invasive and permission-heavy.
- Use IOKit `HIDIdleTime`: rejected as first choice because CoreGraphics has a clearer app-level public API surface for this use case.
- Add a manual reset menu action instead: useful later, but it does not solve automatic away detection.

## Post-Completion

*Items requiring manual intervention or external systems - no checkboxes, informational only.*

**Manual verification**:

- Configure a short work duration and enable tray timer display if helpful.
- Launch `build/Mahu.app` without putting the Mac to sleep.
- Leave the computer untouched for more than 5 minutes.
- Return and verify Mahu starts from a fresh work interval instead of immediately showing a break.
- Repeat while reminders are paused and confirm they remain paused.
- Repeat during an active break and confirm the overlay closes silently without completion sound.
- Check external keyboard/mouse and external display setup, because HID idle behavior can vary by device/session.

**Future follow-up**:

- If users need different away thresholds, add a future Settings UI/runtime setting for idle reset threshold instead of editing this plan's fixed internal threshold.
