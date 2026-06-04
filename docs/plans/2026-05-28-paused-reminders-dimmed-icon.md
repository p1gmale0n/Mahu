# Paused Reminders Dimmed Icon

## Overview

- Add a visual paused-state cue to Mahu's existing tray/status icon when reminders are paused.
- Reuse the existing `TrayIconTemplate` icon asset; do not add a separate paused icon asset.
- Keep the current reminder semantics unchanged: `Pause Reminders` disables automatic reminders, and `Resume Reminders` starts a fresh work interval.
- Keep the tray menu behavior unchanged: enabled state shows `Pause Reminders` and `Quit`; paused state shows `Resume Reminders` and `Quit`.
- Implement the visual state inside `StatusItemController`, where AppKit status-item UI state already lives.

## Context (from discovery)

- Files/components involved:
  - `Mahu/StatusItemController.swift` — owns `NSStatusItem`, icon setup, menu construction, and `setRemindersPaused(_:)`. This is the primary implementation target.
  - `MahuTests/StatusItemControllerTests.swift` — verifies status icon provider usage, icon-only behavior, tray icon loading, template sizing, fallback, `Quit`, and plist menu-bar-only behavior.
  - `MahuTests/StatusItemMenuAcceptanceTests.swift` — verifies `Pause Reminders` / `Resume Reminders`, `Quit`, callback dispatch, fresh enabled state, and no `Start Break` action.
  - `MahuTests/TrayIconAssetTests.swift` — verifies the existing `TrayIconTemplate` asset dimensions/transparency/glyph contract; should remain unchanged unless asset behavior accidentally drifts.
  - `Mahu/AppCoordinator.swift` — already calls `setRemindersPaused(_:)`; should not need timer-semantic changes for this visual-only feature.
  - `MahuTests/AppCoordinatorReminderPauseTests.swift` — protects pause/resume semantics and status menu state updates; should remain green.
  - `README.md` — documents current behavior and manual tray checks; should mention the dimmed paused icon.
  - `docs/decisions.md` — should record the decision to dim the existing icon at runtime rather than introduce a new asset.
  - `docs/plans/completed/2026-05-26-pause-resume-reminders-menu.md` — completed reminder pause/resume contract to preserve.
  - `docs/plans/completed/2026-05-25-tray-icon-transparent-glyph.md` — completed tray icon asset contract to preserve.
  - `Makefile` — `make build` creates `build/Mahu.app`.
- Related patterns found:
  - AppKit UI side effects stay inside `StatusItemController`; `AppCoordinator` owns reminder/timer semantics.
  - Existing tests use injected `statusIconProvider` and real temporary `NSStatusItem` instances for status item behavior.
  - Existing visual tray readability remains manual-only because XCTest cannot prove live menu-bar rendering quality.
  - `ralphex` is installed at `/opt/homebrew/bin/ralphex`.
- Dependencies identified:
  - `xcodebuild test`, `xcodebuild build`, and `make build` are the required automated verification commands.
  - No UI E2E test framework exists in this repo.

## Development Approach

- **Testing approach**: TDD — first add failing tests for paused icon dimming, then implement the smallest UI-state change to pass them.
- Chosen approach: dim the existing status item button/icon presentation at runtime, initially through status button opacity, while keeping the same `TrayIconTemplate` asset and menu callbacks.
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
- Maintain backward compatibility: no Dock icon, no new asset, no settings UI, no `Start Break`, no persistent pause state, no timer semantic changes.

## Testing Strategy

- **Unit tests**: required for every task.
- Add/extend `StatusItemController` tests for:
  - initial enabled state uses normal icon opacity after `install()`.
  - `setRemindersPaused(true)` visually dims the status icon/button.
  - `setRemindersPaused(false)` restores normal icon/button opacity.
  - dimming does not disable the status item button or prevent menu interactions.
  - menu items remain `Pause Reminders` / `Resume Reminders` plus `Quit`.
- Preserve existing asset tests as guardrails proving the same `TrayIconTemplate` source asset remains in use.
- Preserve coordinator pause/resume tests; this feature should not alter timer state semantics.
- **E2E tests**: none exist. Do not introduce UI automation. Use manual menu-bar checks in Post-Completion.

## Progress Tracking

- Mark completed items with `[x]` immediately when done.
- Add newly discovered tasks with ➕ prefix.
- Document issues/blockers with ⚠️ prefix.
- Update plan if implementation deviates from original scope.
- Keep plan in sync with actual work done.

## What Goes Where

- **Implementation Steps** (unchecked task checkboxes): tasks achievable within this codebase - tests, status-item UI changes, documentation, and automated verification.
- **Post-Completion**: items requiring manual action - live tray icon readability checks in real macOS menu-bar states.
- **Checkbox placement**: Checkboxes belong only in Task sections. Do not put checkboxes in Success criteria, Overview, or Context.

## Implementation Steps

### Task 1: Add paused icon dimming tests
- [x] add a `StatusItemControllerTests` case proving `install()` starts with normal status button/icon opacity while reminders are enabled
- [x] add a `StatusItemControllerTests` case proving `setRemindersPaused(true)` dims the existing status item icon/button without changing the menu contract
- [x] add a `StatusItemControllerTests` case proving `setRemindersPaused(false)` restores normal icon/button opacity
- [x] assert the status item button remains enabled or otherwise interactable after dimming, without using disabled-control semantics
- [x] run `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` and confirm the new tests fail before Task 2

### Task 2: Implement runtime dimming in `StatusItemController`
- [x] add explicit normal and paused visual-state constants in `Mahu/StatusItemController.swift`, for example normal opacity `1.0` and paused opacity around `0.45` to `0.60`
- [x] update `install()` to apply the current visual state after assigning the status icon
- [x] update `setRemindersPaused(_:)` to update both the menu and the icon/button visual state
- [x] keep `statusIconProvider`, `makeTrayTemplateStatusIcon`, `makeDefaultStatusIcon`, and the asset catalog unchanged
- [x] keep the status item button/menu interactable; do not use `isEnabled = false` for the paused cue
- [x] run `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` - must pass before Task 3

### Task 3: Verify acceptance behavior stays unchanged
- [x] extend `MahuTests/StatusItemMenuAcceptanceTests.swift` or add a focused acceptance test proving pause changes menu title and dims icon in the same state transition
- [x] verify resume restores both `Pause Reminders` title and normal icon opacity
- [x] verify no `Start Break` action is added
- [x] verify `MahuTests/TrayIconAssetTests.swift` still passes without adding or changing paused icon assets
- [x] run `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` - must pass before Task 4

### Task 4: Verify acceptance criteria and builds
- [x] verify only the existing `TrayIconTemplate` asset is used and no new paused icon asset was added
- [x] verify pause/resume timer semantics remain unchanged by running the existing coordinator reminder pause tests
- [x] run full unit tests with `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run raw app build with `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run local artifact build with `make build`

### Task 5: Update documentation and decision record
- [x] update `README.md` Current Behavior to say paused reminders visually dim the tray/status icon
- [x] update `README.md` Manual Checks to include verifying dimmed icon on pause and normal icon on resume
- [x] update `docs/decisions.md` with the decision to dim the existing runtime status icon instead of adding a separate paused asset
- [x] update this plan if implementation discovers that status button opacity is insufficient and a dimmed image-copy fallback is needed (not needed; current opacity-based cue remains the chosen implementation)
- [x] run `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` after documentation-related code/test changes, if any

## Technical Details

- Preferred implementation shape:
  - Keep `StatusItemController.remindersPaused` as the source for status UI state.
  - Add a private helper such as `applyReminderVisualState()`.
  - In enabled state, set the status item button to normal opacity.
  - In paused state, set the status item button/icon to a visibly dimmed opacity while keeping the menu clickable.
- Initial dimming value:
  - Use a conservative paused opacity around `0.45` to `0.60`.
  - Pick a value that is visibly different but still recognizable in light/dark menu bars.
- Asset constraints:
  - Keep using `Mahu/Assets.xcassets/TrayIconTemplate.imageset/TrayIconTemplate.png` and `TrayIconTemplate@2x.png`.
  - Do not add `PausedTrayIcon`, `TrayIconTemplatePaused`, or a second imageset.
  - Do not change the transparent glyph-only asset contract.
- Layering constraints:
  - `StatusItemController` owns the visual dimming.
  - `AppCoordinator` should not gain visual-icon logic.
  - `BreakTimer` should not change for this feature.

## Success Criteria

- When reminders are enabled, the tray icon appears in its normal state and the menu shows `Pause Reminders` plus `Quit`.
- When reminders are paused, the same tray icon appears visibly dimmed and the menu shows `Resume Reminders` plus `Quit`.
- When reminders are resumed, the tray icon returns to normal appearance.
- The status item remains clickable and the menu still opens while dimmed.
- No new paused icon asset is added.
- Pause/resume timer semantics remain unchanged.
- No `Start Break` action is added.
- `xcodebuild test`, `xcodebuild build`, and `make build` pass.
- `README.md` and `docs/decisions.md` reflect the visual paused-state behavior.

## Post-Completion

*Items requiring manual intervention or external systems - no checkboxes, informational only.*

**Manual verification:**
- Launch `build/Mahu.app` and confirm the app has no Dock icon.
- Open the tray menu and confirm it starts with `Pause Reminders` and `Quit`.
- Choose `Pause Reminders` and confirm the tray icon visibly dims while the menu remains usable.
- Choose `Resume Reminders` and confirm the tray icon returns to normal brightness.
- Confirm no `Start Break` action appears.
- Check icon readability in light mode, dark mode, highlighted/open-menu state, and increased contrast/high contrast if available.
- If the opacity-based cue is too subtle or looks disabled in a bad way, switch to a dimmed image-copy implementation while still reusing the same source asset.

**External/release follow-up:**
- Revisit paused-state icon treatment during final design polish or localization work.
- If future remaining-time display is added to the status item, verify it does not conflict visually with the dimmed paused icon.
