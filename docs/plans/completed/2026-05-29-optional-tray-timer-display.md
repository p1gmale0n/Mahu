# Optional Tray Timer Display

Status: Completed (2026-05-29)

## Overview

Add an optional status-item display mode that shows Mahu's current timer state in the macOS menu bar. The current icon-only status item remains the default behavior. When the new config option is enabled, Mahu should show the existing tray icon plus the active timer's remaining time as `MM:SS`; when reminders are paused, the status item should show the existing tray icon plus `Paused`.

The feature is controlled by the manually editable config file at `~/Library/Application Support/Mahu/config.json`. There is no Settings UI, no menu toggle, and no live config reload in this plan.

## Context (from discovery)

- Files/components involved:
  - `Mahu/StatusItemController.swift`: owns `NSStatusItem`, the tray icon, pause/resume menu, dimming, and AppKit presentation details.
  - `Mahu/AppCoordinator.swift`: owns timer, pause/resume, overlay, and scheduler orchestration. It is already close to the local readability threshold, so avoid adding bulky display logic here.
  - `Mahu/AppCoordinatorSupport.swift`: defines `StatusItemControlling` and related seams used in coordinator tests.
  - `Mahu/BreakTimer.swift`: pure work/rest state machine; should remain UI-agnostic.
  - `Mahu/AppConfig.swift` and `Mahu/ConfigStore.swift`: config model/loading/defaults; need backward-compatible decoding for the new option.
  - `MahuTests/StatusItemControllerTests.swift`: icon-only and AppKit status-item behavior coverage.
  - `MahuTests/StatusItemMenuAcceptanceTests.swift`: pause/resume menu contract coverage.
  - `MahuTests/AppCoordinatorTests.swift` and `MahuTests/AppCoordinatorReminderPauseTests.swift`: timer and pause/resume orchestration coverage.
  - `MahuTests/AppCoordinatorTestSupport.swift`: fake status item controller seam.
  - `MahuTests/ConfigStoreTests.swift`: config default/invalid/missing behavior coverage.
  - `README.md`, `AGENTS.md`, `docs/decisions.md`: behavior, invariants, and decision documentation.
- Related patterns found:
  - `StatusItemController` receives an injected `NSStatusItem` and icon provider, so status-item display behavior is testable without launching the whole app.
  - Existing pause semantics: pause disables future work-timer progress during work phase; resume starts a fresh work interval from launch-loaded config. Active break countdown continues unchanged.
  - Existing icon-only behavior uses `NSStatusItem.squareLength`, empty button title, `.imageOnly`, and dimming via button alpha.
  - Existing countdown formatting uses `AppConfig.safeDisplayWholeSeconds` and `MM:SS` in `BreakOverlayViewModel`.
- Dependencies identified:
  - AppKit `NSStatusItem` length/image-title behavior. Timer display likely needs `.variableLength` or equivalent in enabled mode, while icon-only should remain square.
  - Config decoding must not break existing user config files that lack the new key.

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
- Maintain backward compatibility: old config files without `showStatusItemTimerState` must keep loading and must default to icon-only behavior.

## Testing Strategy

- **Unit tests**: required for every task.
- **Config tests**: prove default, missing-key, valid enabled, and invalid-value behavior.
- **Formatter/model tests**: prove deterministic `MM:SS` and `Paused` output without AppKit.
- **Status item tests**: prove icon-only mode is unchanged and timer mode uses the same icon plus text.
- **Coordinator tests**: prove status display updates on start, work ticks, rest ticks, pause, resume, skip, and natural completion.
- **E2E tests**: the project has no UI E2E suite; real menu-bar readability remains a manual check.

## Progress Tracking

- Mark completed items with `[x]` immediately when done.
- Add newly discovered tasks with ➕ prefix.
- Document issues/blockers with ⚠️ prefix.
- Update plan if implementation deviates from original scope.
- Keep plan in sync with actual work done.

## What Goes Where

- **Implementation Steps** (`[ ]` checkboxes): tasks achievable within this codebase - code changes, tests, documentation updates.
- **Post-Completion** (no checkboxes): items requiring external action - manual UI verification on real menu bar and multi-display checks.
- **Checkbox placement**: Checkboxes belong only in Task sections (`### Task N:` or `### Iteration N:`). Do not put checkboxes in Success criteria, Overview, or Context — they cause extra loop iterations.

## Implementation Steps

### Task 1: Add backward-compatible config contract

- [x] add config tests proving `AppConfig.default.showStatusItemTimerState == false`
- [x] add config tests proving existing JSON without `showStatusItemTimerState` still loads as icon-only
- [x] add config tests proving `"showStatusItemTimerState": true` enables timer display mode
- [x] add config tests proving invalid/non-boolean `showStatusItemTimerState` falls back safely using the project's existing invalid-config behavior
- [x] implement `showStatusItemTimerState` in `AppConfig` with backward-compatible decoding and default config encoding
- [x] run `ConfigStoreTests` - must pass before Task 2

### Task 2: Add status display model and formatter

- [x] create a small internal status display model/formatter separate from `AppCoordinator` and `BreakTimer`
- [x] write tests for active work timer formatting as `MM:SS`
- [x] write tests for active rest timer formatting as `MM:SS`
- [x] write tests for paused display text as `Paused`
- [x] write tests for edge cases using `AppConfig.safeDisplayWholeSeconds` behavior, including fractional, negative, and large durations where appropriate
- [x] implement the formatter/model without introducing AppKit dependencies
- [x] run the new formatter/model tests - must pass before Task 3

### Task 3: Implement optional timer mode in StatusItemController

- [x] add tests proving icon-only mode remains unchanged: square length, empty title, `.imageOnly`, same icon provider path, menu intact
- [x] add tests proving timer mode shows existing tray icon plus `MM:SS`
- [x] add tests proving timer mode shows existing tray icon plus `Paused` when reminders are paused
- [x] add tests proving switching pause/resume keeps menu titles correct in timer mode
- [x] implement status-item display mode handling in `StatusItemController`, using a variable-length status item only when timer display is enabled
- [x] preserve existing dimming behavior without disabling the status item control
- [x] run `StatusItemControllerTests` and `StatusItemMenuAcceptanceTests` - must pass before Task 4

### Task 4: Wire coordinator updates without bloating AppCoordinator

- [x] extend `StatusItemControlling` and `FakeStatusItemController` to accept display mode/state updates
- [x] add coordinator tests proving startup sends initial work remaining state when config enables timer display
- [x] add coordinator tests proving work ticks update the status item timer text
- [x] add coordinator tests proving rest phase updates the status item timer text together with overlay updates
- [x] add coordinator tests proving pause shows `Paused` and stops work countdown advancement while paused
- [x] add coordinator tests proving resume resets to a fresh full work interval and updates status display
- [x] add coordinator tests proving skip and natural completion update display to the next work interval
- [x] implement coordinator wiring using a small helper/adapter if needed to keep `AppCoordinator.swift` readable
- [x] run `AppCoordinatorTests`, `AppCoordinatorReminderPauseTests`, `AppCoordinatorStatusItemDisplayTests`, and `AppCoordinatorStatusItemPauseResumeTests` - must pass before Task 5

### Task 5: Verify acceptance criteria

- [x] verify icon-only remains the default config and default runtime behavior via automated tests (`ConfigStoreStatusItemTimerTests`, `StatusItemTimerDisplayTests`); manual menu-bar inspection remains in Post-Completion
- [x] verify old config files without `showStatusItemTimerState` still load successfully via automated tests (`ConfigStoreStatusItemTimerTests`)
- [x] verify timer mode shows `MM:SS` for active work and active rest timers via automated tests (`StatusDisplayFormatterTests`, `StatusItemTimerDisplayTests`, `AppCoordinatorStatusItemDisplayTests`)
- [x] verify timer mode shows `Paused` when reminders are paused via automated tests (`StatusDisplayFormatterTests`, `StatusItemTimerDisplayTests`, `AppCoordinatorStatusItemPauseResumeTests`)
- [x] verify pause/resume menu behavior remains unchanged via automated tests (`StatusItemMenuAcceptanceTests`, `AppCoordinatorReminderPauseTests`, `AppCoordinatorStatusItemPauseResumeTests`); highlighted-state/manual readability checks remain in Post-Completion
- [x] run full unit test suite: `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run raw build: `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run app bundle build: `make build`

### Task 6: Update documentation and decision history

- [x] update `README.md` Current Behavior to describe optional tray timer display
- [x] update `README.md` Configuration example and notes with `showStatusItemTimerState`
- [x] remove or revise the Deferred Features item for remaining-time display in the status item
- [x] update `README.md` Manual Checks for icon-only and timer display modes
- [x] update `AGENTS.md` product invariants so future agents no longer treat remaining-time display as deferred-only
- [x] append `docs/decisions.md` with the config-backed status display decision and backward-compatibility rationale
- [x] run documentation-adjacent checks available in the project, or note if there are none (no dedicated doc-only checks exist; project validation remains `xcodebuild test`, `xcodebuild build`, and `make build`)

### Task 7: Final plan close-out

- [x] update this plan file if implementation deviated from the original task sequence (no deviation; tasks completed in original order)
- [x] ensure all completed implementation checkboxes are marked `[x]`
- [x] add any newly discovered manual verification limitations to Post-Completion

*Note: ralphex automatically moves completed plans to `docs/plans/completed/`.*

## Technical Details

- Config key:
  - `showStatusItemTimerState: Bool`
  - default: `false`
  - missing key in existing config: decode as `false`
  - invalid type/value: follow existing invalid-config fallback behavior
- Display behavior:
  - `false`: icon-only, current `NSStatusItem.squareLength`, empty title, `.imageOnly`
  - `true` and not paused: existing tray icon plus remaining timer text as `MM:SS`
  - `true` and paused: existing tray icon plus `Paused`
  - active work timer: show work remaining time
  - active rest timer: show break remaining time
- Processing flow:
  - `ConfigStore` loads config once at launch.
  - `AppCoordinator.start()` configures the status item display mode from loaded config.
  - `AppCoordinator` updates a status display seam after timer state changes and pause/resume changes.
  - `StatusItemController` owns AppKit-specific presentation and menu behavior.
  - `BreakTimer` remains pure and unaware of UI display mode.

## Post-Completion

*Items requiring manual intervention or external systems - no checkboxes, informational only.*

**Manual verification**:

- Run fresh `build/Mahu.app` with default/missing `showStatusItemTimerState` and confirm icon-only mode is unchanged.
- Run fresh `build/Mahu.app` with `"showStatusItemTimerState": true` and confirm menu bar shows icon plus timer text.
- Confirm text readability in light mode, dark mode, and highlighted menu state.
- Confirm native `NSStatusItem` width, truncation, and spacing remain acceptable with live macOS menu-bar rendering; XCTest covers controller state but cannot prove real menu-bar layout.
- Confirm `Pause Reminders` changes display to `Paused` and menu to `Resume Reminders`.
- Confirm `Resume Reminders` returns display to a fresh full work interval.
- Confirm active break countdown appears in the status item and does not disrupt overlay behavior.
- Confirm no Dock icon and no extra menu items are introduced.

**External system updates**:

- None expected.
