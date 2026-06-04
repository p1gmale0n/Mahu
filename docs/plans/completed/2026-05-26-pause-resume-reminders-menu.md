# Pause and Resume Reminders Menu

Status: Completed (2026-05-26)

## Overview

- Add tray/status menu controls that let the user pause and resume Mahu reminders.
- The feature disables or enables automatic break reminders; it is not a countdown pause/resume mechanism.
- When reminders are paused during a work interval, Mahu stops consuming timer time and does not show break overlays.
- When reminders are resumed, Mahu starts a fresh work interval from the configured `workDurationSeconds` rather than continuing a partially elapsed interval.
- Keep active break behavior unchanged: break overlays remain controlled by the existing countdown and `Skip` button. Do not add pause controls for an active break.
- Keep the app menu-bar-only, App Store-friendly, and public-API-only.

## Context (from discovery)

- Files/components involved:
  - `Mahu/StatusItemController.swift` — owns `NSStatusItem`, icon setup, and the tray menu. It currently installs an icon-only status item with a menu containing only `Quit`.
  - `Mahu/AppCoordinator.swift` — loads config, creates the timer, schedules ticks, drives overlay show/hide/update, and owns the current runtime timer lifecycle.
  - `Mahu/BreakTimer.swift` — owns work/rest phase state, `advance(by:)`, and `skipBreak()`.
  - `MahuTests/StatusItemControllerTests.swift` — verifies status item icon/menu behavior and quit action.
  - `MahuTests/AppCoordinatorTests.swift` and `MahuTests/AppCoordinatorBreakPresentationTests.swift` — verify tick scheduling, phase transitions, skip behavior, overlay visibility accounting, and coordinator seams.
  - `MahuTests/BreakTimerTests.swift` — verifies timer phase transitions and skip behavior.
  - `MahuTests/AppCoordinatorTestSupport.swift` — contains fake status item, overlay manager, timer, and uptime helpers used by coordinator tests.
  - `README.md` — currently lists pause/resume and manual start-break menu actions as deferred features.
  - `docs/decisions.md` — records architecture/process decisions and should capture the new reminder pause/resume semantics.
  - `Makefile` — `make build` creates `build/Mahu.app`.
- Related patterns found:
  - AppKit UI side effects stay at the edges: `StatusItemController` owns `NSStatusItem`; `AppCoordinator` owns timer and overlay flow.
  - Existing code prefers small injected protocols/seams over direct AppKit coupling in tests.
  - Existing tests use deterministic fake schedulers and uptime providers instead of sleeping real time.
  - Current runtime model has only work/rest phases; pause/resume should be modeled as an application reminder-enabled state, not as a new break phase.
  - `ralphex` is installed at `/opt/homebrew/bin/ralphex`.
- Dependencies identified:
  - `xcodebuild test`, `xcodebuild build`, and `make build` are the required automated verification commands.
  - There are no UI E2E tests in this project; live tray menu behavior remains manual verification.

## Development Approach

- **Testing approach**: TDD — first add failing tests that define reminder pause/resume semantics, then implement the smallest code changes to pass them.
- Chosen approach: model this as `Pause Reminders` / `Resume Reminders`, not as manual `Start Break` and not as countdown continuation.
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
- Maintain backward compatibility: no Dock icon, no settings UI, no persistent pause state, no manual `Start Break`, no input capture/private APIs.

## Testing Strategy

- **Unit tests**: required for every task.
- Add/extend coordinator tests for:
  - pausing reminders stops timer advancement while the scheduler can still tick.
  - resuming reminders creates or resets to a fresh work interval from config.
  - pause/resume status changes update the tray menu state.
  - pause action is idempotent while already paused.
  - resume action is idempotent while already enabled.
- Add/extend status item tests for:
  - menu contains `Pause Reminders` and `Quit` when reminders are enabled.
  - menu contains `Resume Reminders` and `Quit` when reminders are paused.
  - pause/resume menu actions call injected handlers.
  - existing icon-only behavior and Quit action remain intact.
- Add `BreakTimer` tests only if production changes move reset semantics into `BreakTimer`; otherwise keep pause/resume above `BreakTimer` in `AppCoordinator`.
- **E2E tests**: none exist. Do not introduce UI automation for this menu-only feature. Use manual menu-bar verification in Post-Completion.

## Progress Tracking

- Mark completed items with `[x]` immediately when done.
- Add newly discovered tasks with ➕ prefix.
- Document issues/blockers with ⚠️ prefix.
- Update plan if implementation deviates from original scope.
- Keep plan in sync with actual work done.

## What Goes Where

- **Implementation Steps** (`[ ]` checkboxes): tasks achievable within this codebase - code changes, tests, documentation updates, and automated verification.
- **Post-Completion**: items requiring manual action - live tray menu verification, interaction during real break overlay, and appearance checks.
- **Checkbox placement**: Checkboxes belong only in Task sections. Do not put checkboxes in Success criteria, Overview, or Context.

## Implementation Steps

### Task 1: Define tray menu pause/resume contract in tests
- [x] update `MahuTests/StatusItemControllerTests.swift` to expect a `Pause Reminders` menu item plus `Quit` when reminders are enabled
- [x] add a `StatusItemControllerTests` case proving the `Pause Reminders` item invokes an injected pause handler
- [x] add a `StatusItemControllerTests` case proving the paused menu state shows `Resume Reminders` plus `Quit`
- [x] add a `StatusItemControllerTests` case proving the `Resume Reminders` item invokes an injected resume handler
- [x] verify existing icon-only status item and Quit tests still describe the intended behavior after the new menu items are added
- [x] run `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` and confirm the new tests fail before Task 2

### Task 2: Implement status menu state and handlers
- [x] update `Mahu/StatusItemController.swift` to accept injected pause/resume handlers without moving timer logic into the status item layer
- [x] add a small status menu state API, such as `setRemindersPaused(_:)`, that rebuilds or updates the menu title between `Pause Reminders` and `Resume Reminders`
- [x] preserve the icon-only status item behavior, tray icon loading, app icon fallback, and `Quit` shortcut
- [x] keep `Quit` behavior unchanged and avoid adding `Start Break` or any settings UI
- [x] run `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` - must pass before Task 3

### Task 3: Define coordinator reminder disable/enable semantics in tests
- [x] update `MahuTests/AppCoordinatorTestSupport.swift` if needed so the fake status controller can capture pause/resume handlers and menu paused-state updates
- [x] add an `AppCoordinatorTests` case proving pause disables timer advancement even if scheduled ticks continue firing
- [x] add an `AppCoordinatorTests` case proving resume starts a fresh work interval from the configured duration instead of continuing elapsed remainder
- [x] add an `AppCoordinatorTests` case proving pause and resume update the status item menu state exactly once per effective state change
- [x] add idempotency tests proving repeated pause or repeated resume does not duplicate reset work or corrupt scheduler state
- [x] run `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` and confirm the new coordinator tests fail before Task 4

### Task 4: Implement reminder pause/resume in `AppCoordinator`
- [x] extend `StatusItemControlling` and `AppCoordinator` wiring so `StatusItemController` receives pause/resume callbacks during `start()`
- [x] implement pause as a runtime `remindersPaused` state that prevents work timer advancement and prevents new break presentation while paused
- [x] implement resume as a fresh work interval reset using the current loaded config and a new `BreakTimer`, with `pendingElapsedSeconds` cleared and `lastTickUptime` reset
- [x] ensure active break behavior remains unchanged: existing overlay countdown and `Skip` behavior continue to own break completion; do not add break pause controls
- [x] ensure pause/resume state is not persisted and app launch always starts reminders enabled
- [x] run `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` - must pass before Task 5

### Task 5: Verify acceptance criteria and builds
- [x] verify the status menu shows `Pause Reminders` when reminders are enabled and `Resume Reminders` when paused (automated by `StatusItemControllerTests`; live tray render remains manual-only)
- [x] verify pausing reminders stops automatic work-to-break transitions until resume (automated by `AppCoordinatorReminderPauseTests`)
- [x] verify resuming reminders starts a full fresh work interval rather than continuing an old partial countdown (automated by `AppCoordinatorReminderPauseTests`)
- [x] verify no `Start Break` action was added (automated by `StatusItemMenuAcceptanceTests`)
- [x] run full unit tests with `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run raw app build with `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run local artifact build with `make build`

### Task 6: Update documentation and decision record
- [x] update `README.md` Current Behavior and Deferred Features to document `Pause Reminders` / `Resume Reminders` and remove pause/resume from deferred scope
- [x] update `README.md` Manual Checks with tray menu pause/resume verification steps
- [x] update `docs/decisions.md` with the decision that pause/resume means disabling/enabling reminders and resume starts a fresh work interval
- [x] update this plan if implementation discovers a different minimal seam or edge-case behavior (no additional plan changes were needed after verifying the shipped coordinator/status-item seam)
- [x] run `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` after documentation-related code/test changes, if any

## Technical Details

- Menu labels:
  - Enabled state: `Pause Reminders`
  - Paused state: `Resume Reminders`
  - Existing `Quit` item remains present with key equivalent `q`.
- Runtime semantics:
  - Pausing reminders disables automatic timer progress and prevents future break overlays from being triggered.
  - Resuming reminders starts a new full work interval from the currently loaded config.
  - Pause state is runtime-only and is not written to `config.json`, UserDefaults, or any other persistence.
  - On app launch, reminders are enabled by default.
- Layering:
  - `StatusItemController` owns AppKit menu construction and invokes injected callbacks.
  - `AppCoordinator` owns reminder enabled/paused state, timer reset, and overlay flow.
  - `BreakTimer` should remain focused on work/rest countdown unless implementation evidence shows a reset helper belongs there.
- Edge cases:
  - Repeated pause should be idempotent.
  - Repeated resume while already enabled should be idempotent.
  - Pausing should not cancel the scheduled tick closure unless implementation proves cancellation is simpler and safer; ticking while paused can be a no-op and keeps resume wiring simple.
  - If pause is somehow triggered during an active break, do not attempt to freeze the overlay countdown from the tray menu. Preserve the existing break overlay and `Skip` contract.

## Success Criteria

- The tray menu lets the user pause and resume reminders.
- The menu label reflects current reminder state: `Pause Reminders` when enabled, `Resume Reminders` when paused.
- Paused reminders do not trigger a break overlay.
- Resuming starts a fresh configured work interval, not a countdown continuation.
- Pause state is not persisted across app restarts.
- `Quit` still exits the app.
- Status item remains icon-only and menu-bar-only app behavior remains intact.
- No manual `Start Break` action is added.
- `xcodebuild test`, `xcodebuild build`, and `make build` pass.
- `README.md` and `docs/decisions.md` reflect the shipped semantics.

## Post-Completion

*Items requiring manual intervention or external systems - no checkboxes, informational only.*

**Manual verification:**
- Launch `build/Mahu.app` and confirm the app has no Dock icon.
- Open the tray menu and confirm it shows `Pause Reminders` and `Quit` while reminders are enabled.
- Choose `Pause Reminders`, then confirm the menu changes to `Resume Reminders` and no break overlay appears after the previous work interval would have elapsed.
- Choose `Resume Reminders`, then confirm the next break appears only after a full fresh work interval.
- Confirm `Quit` still exits the app.
- Confirm active break behavior remains unchanged: overlay countdown runs, `Skip` works, and no pause-specific overlay UI appears.

**External/release follow-up:**
- Revisit wording and localization if the app later adds a real settings UI or localized menu labels.
- If remaining-time display is added to the status item later, verify pause/resume state does not make the menu-bar UI ambiguous.
