# Runtime Settings Foundation

Status: Completed (2026-05-31)

## Overview

Introduce a runtime settings foundation so a future Settings window can apply changes while Mahu is running without making app components read JSON directly or adding live file watching. The manually editable config file remains the persistence/backward-compatibility layer, while a single runtime settings source becomes the in-process source of truth.

This plan does not add a Settings UI. It creates the model/store/seams and coordinator policies needed for future UI-driven updates: immediate UI-only updates, safe timer schedule changes, and clear persistence behavior.

## Context (from discovery)

- Files/components involved:
  - `Mahu/AppConfig.swift`: current persisted settings value with work/break durations, tray timer display toggle, and break overlay message text.
  - `Mahu/ConfigStore.swift`: disk loading, config hardening, fallback behavior; currently has `load()` only.
  - `Mahu/AppCoordinator.swift`: currently loads config once, stores `activeConfig`, creates `BreakTimer`, applies status item mode, and passes message text to overlay start.
  - `Mahu/AppCoordinatorSupport.swift`: coordinator-facing protocols/seams; likely place for settings-store protocol support.
  - `Mahu/BreakTimer.swift`: pure state machine; should remain unaware of config/store/UI.
  - `Mahu/StatusItemController.swift`: AppKit edge that can already apply `setShowsTimerState(_:)` immediately.
  - `Mahu/BreakOverlayManager.swift`: AppKit edge that receives message text at break start and preserves shared view model during display resync.
  - `MahuTests/AppCoordinatorTestSupport.swift`: fake timer/status/overlay support; needs fake settings store.
  - `MahuTests/AppCoordinatorTests.swift`, `AppCoordinatorStatusItemDisplayTests.swift`, `AppCoordinatorStatusItemPauseResumeTests.swift`, `AppCoordinatorBreakPresentationTests.swift`, `AppCoordinatorReminderPauseTests.swift`: coordinator policy coverage.
  - `MahuTests/ConfigStoreTests.swift`: config persistence/fallback coverage; needs save tests.
  - `README.md`, `AGENTS.md`, `docs/decisions.md`: runtime settings behavior and no-file-watcher decision.
- Related patterns found:
  - Manual config is loaded once at launch today; hidden live reloads were previously rejected.
  - Optional UI settings such as `showStatusItemTimerState` are safe to apply immediately through existing status item seams.
  - Break overlay message text is currently applied when a new break starts; active break resync preserves the shared view model.
  - Pause/resume semantics: pause freezes work-phase reminder progress; resume starts a fresh work interval from the current settings source.
  - `AppCoordinator.swift` is near the local readability threshold, so settings types/store/policies should live in focused support files where practical.
- Dependencies identified:
  - Swift value-type settings model (`AppConfig` or `AppSettings`).
  - A MainActor runtime store/seam with testable updates.
  - Disk persistence through `ConfigStore` without becoming a global observable singleton.

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
- Maintain backward compatibility: existing config fallback/loading behavior must remain unchanged, and manual JSON edits during app runtime must not become implicit live reloads.

## Testing Strategy

- **Unit tests**: required for every task.
- **Store tests**: prove runtime settings store initialization, update notification, and no filesystem dependency.
- **Config persistence tests**: prove `ConfigStore.save` writes loadable config and handles write failures deterministically.
- **Coordinator policy tests**: prove immediate UI-only updates and safe timer schedule update semantics across work, paused work, and active rest phases.
- **Regression tests**: prove no repeated config loads on ticks/runtime updates and active break overlays are not restarted by settings changes.
- **E2E tests**: no UI E2E suite exists. Future Settings UI is out of scope.

## Progress Tracking

- Mark completed items with `[x]` immediately when done.
- Add newly discovered tasks with ➕ prefix.
- Document issues/blockers with ⚠️ prefix.
- Update plan if implementation deviates from original scope.
- Keep plan in sync with actual work done.

## What Goes Where

- **Implementation Steps** (`[ ]` checkboxes): tasks achievable within this codebase - code changes, tests, documentation updates.
- **Post-Completion** (no checkboxes): items requiring external action - future Settings UI, manual runtime checks.
- **Checkbox placement**: Checkboxes belong only in Task sections (`### Task N:` or `### Iteration N:`). Do not put checkboxes in Success criteria, Overview, or Context — they cause extra loop iterations.

## Implementation Steps

### Task 1: Introduce runtime settings model and store seam

- [x] add tests for initializing a runtime settings store from `AppConfig.default`
- [x] add tests proving runtime settings updates publish/callback exactly once per accepted update
- [x] add tests proving runtime settings updates do not call `ConfigStore.load()` or touch the filesystem
- [x] implement a focused runtime settings value/store seam, reusing `AppConfig` as the value if a separate `AppSettings` type would add no immediate value
- [x] keep the store MainActor-safe and injectable for coordinator tests
- [x] run new runtime settings store tests - must pass before Task 2

### Task 2: Add ConfigStore save/persistence API

- [x] add tests proving `ConfigStore.save` writes valid JSON that `load()` can read back
- [x] add tests proving `ConfigStore.save` creates the config parent directory when needed
- [x] add tests proving save failure is reported or logged without crashing
- [x] add tests proving existing `load()` fallback behavior remains unchanged
- [x] implement `ConfigStore.save(_:)` or equivalent persistence API without adding file watching
- [x] run `ConfigStoreTests` and related config tests - must pass before Task 3

### Task 3: Wire AppCoordinator to runtime settings source

- [x] update coordinator tests so startup initializes from the runtime settings source instead of repeatedly calling `loadConfig`
- [x] add tests proving `loadConfig`/disk load happens only once during startup setup and not during ticks/runtime setting updates
- [x] update `AppCoordinator` initialization to create or receive a runtime settings store while preserving existing test ergonomics where possible
- [x] replace `activeConfig` reads with current runtime settings reads where appropriate
- [x] keep `BreakTimer` pure and avoid adding settings logic there
- [x] run focused coordinator startup/tick tests - must pass before Task 4

### Task 4: Apply UI-only settings immediately

- [x] add tests proving runtime `showStatusItemTimerState` changes call `StatusItemControlling.setShowsTimerState` immediately
- [x] add tests proving turning tray timer mode on/off at runtime does not recreate the timer or overlay
- [x] add tests proving runtime `breakOverlayMessageText` changes apply to the next break, not an already visible break
- [x] implement runtime settings change handling for UI-only settings through coordinator routing
- [x] preserve existing status item timer text updates after the toggle changes
- [x] run status item display and coordinator runtime settings tests - must pass before Task 5

### Task 5: Define and implement timer schedule update policies

- [x] add tests proving work-duration changes during active work start a fresh work interval from the new duration
- [x] add tests proving break-duration changes during active work affect the next break duration
- [x] add tests proving duration changes while paused in work are stored and resume starts a fresh interval from current settings
- [x] add tests proving duration changes during active rest do not replace the current break countdown, `Skip` state, or overlay windows
- [x] add tests proving new durations apply after active rest completes or is skipped
- [x] implement the explicit schedule update policy in coordinator/helper code without bloating `AppCoordinator.swift`
- [x] run coordinator schedule policy tests - must pass before Task 6

### Task 6: Preserve overlay, pause, and status regressions

- [x] add regression tests proving active break settings updates do not call `showBreak` again
- [x] add regression tests proving active break settings updates do not hide the overlay
- [x] add regression tests proving pause/resume menu behavior remains unchanged after runtime settings updates
- [x] add regression tests proving status timer display state remains accurate after runtime duration changes
- [x] update fakes in `AppCoordinatorTestSupport.swift` only as needed for these assertions (not needed)
- [x] run relevant coordinator, status item, and overlay tests - must pass before Task 7

### Task 7: Verify acceptance criteria

- [x] verify `ConfigStore` remains disk persistence only and no file watcher is introduced
- [x] verify there is a single injectable runtime settings source of truth
- [x] verify manual config remains launch-loaded and runtime changes come through the settings store/API
- [x] verify future UI can update settings without making components read JSON directly
- [x] run full unit test suite: `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run raw build: `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run app bundle build: `make build`

### Task 8: Update documentation and decision history

- [x] update `README.md` to distinguish launch-loaded manual config from future runtime Settings UI updates
- [x] update `README.md` if new persistence behavior or runtime policies need user-facing notes
- [x] update `AGENTS.md` with the runtime settings architecture invariant if needed
- [x] append `docs/decisions.md` with the runtime settings source, no-file-watcher, and schedule-update policy decisions
- [x] run documentation-adjacent checks available in the project, or note if there are none (no dedicated docs lint/check commands exist in this repo)

### Task 9: Final plan close-out

- [x] implementation followed the original task sequence; no sequence changes were needed
- [x] ensure all completed implementation checkboxes are marked `[x]`
- [x] add any newly discovered manual verification limitations to Post-Completion

*Note: keep this completed plan at its original path while the current review loop still targets it, then archive it under `docs/plans/completed/` once review close-out is finished.*

## Technical Details

- Runtime source of truth:
  - A single MainActor runtime settings store, initialized from launch-loaded config.
  - Future Settings UI should call the runtime store/API, not write JSON directly and wait for reload.
  - Disk save can fail without reverting the already accepted runtime update; the failure should be reported/logged deterministically.
- Disk persistence:
  - `ConfigStore` remains responsible for load/save only.
  - No polling, file watching, or hidden reloads.
  - Existing load hardening remains intact.
- Runtime policies:
  - `showStatusItemTimerState`: apply immediately to `StatusItemController`.
  - `breakOverlayMessageText`: apply to the next break; do not mutate an already visible break in this foundation plan.
  - Work duration change during active work: reset to a fresh work interval using the new duration.
  - Duration change while paused in work: store new settings; resume starts fresh from current settings.
  - Duration change during active rest: preserve current break countdown, overlay windows, and `Skip`; apply new durations after rest completes or is skipped.
- Responsibility boundaries:
  - `BreakTimer` stays pure.
  - `StatusItemController` stays AppKit presentation edge.
  - `BreakOverlayManager` stays overlay-window edge.
  - `AppCoordinator` routes settings changes but should delegate bulky adaptation logic to focused helpers where practical.

## Post-Completion

*Items requiring manual intervention or external systems - no checkboxes, informational only.*

**Manual verification**:

- No new Settings UI is expected from this plan.
- Runtime settings changes remain manually unverified in a live app session because this foundation work intentionally does not add a Settings UI or dedicated runtime-update harness.
- If a test harness or debug hook is added for runtime updates, manually verify tray timer toggle changes immediately without relaunch.
- Manually verify active work duration changes reset work countdown according to policy.
- Manually verify active break duration/message changes do not restart or replace the visible break.

**External system updates**:

- Future Settings UI should integrate by calling the runtime settings store/API introduced here.
