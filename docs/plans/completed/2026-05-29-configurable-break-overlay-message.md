# Configurable Break Overlay Message

Status: Completed (2026-05-29)

## Overview

Add a config-backed way to customize the main break overlay message text. Today Mahu always shows the hardcoded Russian text `Время отвлечься`. This plan adds a new config key, `breakOverlayMessageText`, so users can provide any non-empty Unicode string while preserving the current default when the field is absent.

The config file remains the only settings surface for this feature. There is no Settings UI and no live config reload in this plan; Mahu reads the message at launch together with the rest of `AppConfig`.

## Context (from discovery)

- Files/components involved:
  - `Mahu/AppConfig.swift`: config model and backward-compatible decoding pattern for optional fields.
  - `Mahu/ConfigStore.swift`: config loading, missing-file creation, invalid-config fallback, file size/type guards.
  - `Mahu/BreakOverlayView.swift`: `BreakOverlayViewModel.titleText` is currently hardcoded as `Время отвлечься`.
  - `Mahu/BreakOverlayManager.swift`: creates the shared `BreakOverlayViewModel` when a break starts; display resync reuses that view model.
  - `Mahu/AppCoordinator.swift`: loads config once, stores `activeConfig`, and calls `overlayManager.showBreak(...)` when rest starts.
  - `Mahu/AppCoordinatorSupport.swift`: defines `BreakOverlayManaging` protocol used by coordinator tests.
  - `Mahu/BreakOverlaySupport.swift`: builds live overlay windows from the shared view model; likely no direct changes needed if message lives in the view model.
  - `MahuTests/BreakOverlayViewTests.swift`: currently asserts the hardcoded default title and foreground rendering.
  - `MahuTests/ConfigStoreTests.swift` and related config tests: cover missing/invalid/default config behavior.
  - `MahuTests/AppCoordinatorTestSupport.swift`: fake overlay manager currently records show events without message text.
  - `MahuTests/AppCoordinatorBreakPresentationTests.swift`: verifies show/update/hide break flow.
  - `MahuTests/BreakOverlayManagerTests.swift`: verifies shared view model and display resync behavior.
  - `README.md`, `AGENTS.md`, `docs/decisions.md`: behavior, config, invariants, and decision history.
- Related patterns found:
  - Missing config creates a default config file and continues running.
  - Invalid JSON, decoding errors, unsupported durations, oversized files, and unsupported filesystem entries fall back to `AppConfig.default`.
  - `showStatusItemTimerState` already established the pattern: missing optional key defaults safely; invalid explicit type follows invalid-config fallback.
  - Overlay layout must keep the `GeometryReader` bounded centering fix; do not simplify it while touching `BreakOverlayView`.
- Dependencies identified:
  - Swift `String` / `Codable` for Unicode message text.
  - Existing AppKit/SwiftUI overlay rendering; no external localization framework is needed.

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
- Maintain backward compatibility: old config files without `breakOverlayMessageText` must keep loading and must show the current default text.

## Testing Strategy

- **Unit tests**: required for every task.
- **Config tests**: prove default, missing-key, custom Unicode, empty/whitespace, null, and invalid-type behavior.
- **Overlay view tests**: prove default and custom message rendering while preserving countdown/Skip behavior.
- **Overlay manager tests**: prove custom message is stored in the shared view model and preserved across display resync.
- **Coordinator tests**: prove launch-loaded config message is passed to overlay show when a break starts.
- **E2E tests**: the project has no UI E2E suite. Real overlay readability for long/custom text remains a manual check.

## Progress Tracking

- Mark completed items with `[x]` immediately when done.
- Add newly discovered tasks with ➕ prefix.
- Document issues/blockers with ⚠️ prefix.
- Update plan if implementation deviates from original scope.
- Keep plan in sync with actual work done.

## What Goes Where

- **Implementation Steps** (unchecked task checkboxes): tasks achievable within this codebase - code changes, tests, documentation updates.
- **Post-Completion** (no checkboxes): items requiring external action - manual overlay checks on real displays.
- **Checkbox placement**: Checkboxes belong only in Task sections (`### Task N:` or `### Iteration N:`). Do not put checkboxes in Success criteria, Overview, or Context — they cause extra loop iterations.

## Implementation Steps

### Task 1: Add backward-compatible config field

- [x] add config tests proving `AppConfig.default.breakOverlayMessageText == "Время отвлечься"`
- [x] add config tests proving existing JSON without `breakOverlayMessageText` still loads with the default message
- [x] add config tests proving a custom non-empty Unicode string loads unchanged
- [x] add config tests proving empty and whitespace-only strings normalize to the default message
- [x] add config tests proving `null` and non-string values follow the existing invalid-config fallback behavior
- [x] implement `breakOverlayMessageText` in `AppConfig` with backward-compatible decoding and default config encoding
- [x] run config tests - must pass before Task 2

### Task 2: Make BreakOverlayViewModel message-driven

- [x] add tests proving `BreakOverlayViewModel` defaults to `Время отвлечься` when no custom text is provided
- [x] add tests proving `BreakOverlayViewModel` preserves a custom Unicode title string
- [x] add tests proving `BreakOverlayView` foreground renders the custom message with countdown and `Skip`
- [x] add tests or assertions preserving existing countdown formatting and skip callback behavior
- [x] implement message storage in `BreakOverlayViewModel` without reading config inside SwiftUI view code
- [x] run `BreakOverlayViewTests` - must pass before Task 3

### Task 3: Wire message through BreakOverlayManager

- [x] update `BreakOverlayManaging.showBreak` tests/support to include message text
- [x] add `BreakOverlayManager` tests proving `showBreak` creates a view model with the provided message
- [x] add `BreakOverlayManager` tests proving display hot-plug/resync preserves the same custom message and shared countdown/Skip state
- [x] implement `messageText` parameter in `BreakOverlayManager.showBreak`
- [x] update live overlay window construction only if needed to keep using the shared view model
- [x] run `BreakOverlayManagerTests` - must pass before Task 4

### Task 4: Wire coordinator from launch-loaded config

- [x] update fake overlay manager events in `AppCoordinatorTestSupport` to record message text
- [x] update existing coordinator break-presentation assertions affected by the new show-event shape
- [x] add coordinator test proving custom `breakOverlayMessageText` from loaded config reaches `showBreak`
- [x] add coordinator test proving missing config field still sends the default message
- [x] implement coordinator wiring using `activeConfig.breakOverlayMessageText` when starting rest phase
- [x] keep live config reload out of scope and avoid adding bulky display logic to `AppCoordinator`
- [x] run coordinator break-presentation tests - must pass before Task 5

### Task 5: Verify acceptance criteria

 - [x] verify old config files without `breakOverlayMessageText` still load successfully (covered by `ConfigStoreStatusItemTimerTests.testLoadReturnsDefaultBreakOverlayMessageWhenJSONOmitsMessageText`)
 - [x] verify default overlay message remains `Время отвлечься` (covered by `ConfigStoreStatusItemTimerTests.testDefaultConfigUsesDefaultBreakOverlayMessageText`, `BreakOverlayViewTests.testViewModelUsesDefaultTitleWhenCustomTextIsOmitted`, and `AppCoordinatorBreakPresentationTests.testMissingBreakOverlayMessageConfigFieldStillSendsDefaultMessage`)
 - [x] verify custom Unicode text is preserved and rendered (covered by `ConfigStoreStatusItemTimerTests.testLoadPreservesCustomUnicodeBreakOverlayMessageText`, `BreakOverlayViewTests.testBreakOverlayViewRendersCustomMessageWithCountdownAndSkip`, and `AppCoordinatorBreakPresentationTests.testCustomBreakOverlayMessageFromLoadedConfigReachesShowBreak`)
 - [x] verify empty/whitespace-only text uses the default message (covered by `ConfigStoreStatusItemTimerTests.testLoadNormalizesEmptyBreakOverlayMessageTextToDefault` and `testLoadNormalizesWhitespaceOnlyBreakOverlayMessageTextToDefault`)
 - [x] verify invalid text types and `null` fall back safely through existing config behavior (covered by `ConfigStoreStatusItemTimerTests.testLoadFallsBackToDefaultsWhenBreakOverlayMessageTextIsNull` and `testLoadFallsBackToDefaultsWhenBreakOverlayMessageTextIsNotAString`)
 - [x] verify active-break display resync preserves the configured message (covered by `BreakOverlayManagerTests.testScreenChangePreservesCustomMessageAndSharedBreakState`)
 - [x] run full unit test suite: `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
 - [x] run raw build: `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
 - [x] run app bundle build: `make build`

### Task 6: Update documentation and decision history

- [x] update `README.md` Current Behavior to describe the config-backed overlay message
- [x] update `README.md` Configuration example and notes with `breakOverlayMessageText`
- [x] update `README.md` Manual Checks with custom Unicode, whitespace-fallback, and display-resync overlay text scenarios
- [x] update `AGENTS.md` product invariant so the break message is documented as configurable with the Russian default
- [x] append `docs/decisions.md` with the config-backed overlay message decision and backward-compatibility rationale
- [x] run documentation-adjacent checks available in the project, or note if there are none (no dedicated docs-only checks exist; validated with `xcodebuild test`, `xcodebuild build`, and `make build`)

### Task 7: Final plan close-out

- [x] update this plan file if implementation deviated from the original task sequence (no deviation; tasks completed in the planned order)
- [x] ensure all completed implementation checkboxes are marked `[x]`
- [x] add any newly discovered manual verification limitations to Post-Completion

*Note: ralphex automatically moves completed plans to `docs/plans/completed/`.*

## Technical Details

- Config key:
  - `breakOverlayMessageText: String`
  - default: `Время отвлечься`
  - missing key in existing config: decode as default text
  - valid non-empty Unicode string: use unchanged
  - empty or whitespace-only string: normalize to default text
  - invalid type or `null`: follow existing invalid-config fallback behavior
- Processing flow:
  - `ConfigStore` loads config once at launch.
  - `AppCoordinator` uses `activeConfig.breakOverlayMessageText` when starting a rest phase.
  - `BreakOverlayManager.showBreak` receives message text and creates one shared `BreakOverlayViewModel` with that text.
  - Display resync reuses the same view model, preserving custom text, countdown, and `Skip` state.
  - `BreakOverlayView` renders `viewModel.titleText`; it does not read config directly.
- Unicode support:
  - Treat Swift `String` as the source of truth.
  - Do not add ASCII-only filtering or language-specific logic.
  - Keep layout centered and readable, with manual validation for very long text.

## Post-Completion

*Items requiring manual intervention or external systems - no checkboxes, informational only.*

**Manual verification**:

- Automation coverage stops at config/wiring/unit-build proof; real overlay text wrapping, readability, and centering on physical built-in/external displays during a live break remain manual-only.
- Run fresh `build/Mahu.app` with no `breakOverlayMessageText` and confirm the overlay shows `Время отвлечься`.
- Run fresh `build/Mahu.app` with a custom Unicode value such as `休憩しましょう — отдохни 🌿` and confirm the overlay shows it.
- Confirm empty or whitespace-only config text falls back to the default.
- Confirm the custom message remains centered/readable on the built-in display and external display if available.
- Start a break, hot-plug or resize a display, and confirm the custom message persists with the same countdown and `Skip` state.

**External system updates**:

- None expected.
