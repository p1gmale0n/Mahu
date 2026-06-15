# Settings Window Polish Fixes

## Overview

Polish the shipped Mahu Settings window after the initial ralphex integration pass. The current window opens and is wired to runtime settings, but several controls are visually unclear or awkward:

- the default window is too small and hides settings behind scrolling;
- timer duration controls show values but do not allow manual numeric input;
- Launch at Login should be a disabled/read-only display of the current config/runtime value, not an editable Settings control;
- idle-away threshold value is clipped/hidden and should sit at the far right immediately before the toggle;
- break overlay message editing is visually unclear, and the English placeholder `Time to look away` is confusing next to the actual Russian default message.

This follow-up keeps the existing Settings architecture: AppKit owns the window, SwiftUI owns the view, `RuntimeSettingsStore` remains the in-process source of truth, and `ConfigStore` remains strict-JSON persistence. It is primarily a UI/UX correction pass with focused tests and documentation updates for the changed Launch at Login Settings contract.

## Context (from discovery)

- Files/components involved:
  - `Mahu/SettingsView.swift` — current SwiftUI form layout and main visual fix target.
  - `Mahu/SettingsViewModel.swift` — ranges, display strings, parsing/update actions, save warning state.
  - `Mahu/SettingsWindowController.swift` — AppKit window sizing, reuse, and SwiftUI hosting.
  - `Mahu/AppConfig+SettingsEditing.swift` — settings update helpers used by the view model.
  - `Mahu/StatusItemMenu.swift`, `Mahu/StatusItemController.swift`, `Mahu/AppDelegate.swift` — existing Settings entry point and composition, not expected to need major changes.
  - `MahuTests/SettingsViewModelTests.swift` — existing view-model tests, already large; avoid adding too many unrelated cases here.
  - `MahuTests/SettingsWindowControllerTests.swift` — window sizing/reuse tests.
  - `MahuTests/SettingsRuntimeIntegrationTests.swift` — runtime/persistence integration tests.
  - `README.md`, `AGENTS.md`, `docs/decisions.md` — docs must reflect the read-only Launch at Login Settings behavior.
  - `docs/plans/completed/2026-06-10-settings-window-integration.md` — completed baseline plan.
- Related patterns found:
  - Settings uses `RuntimeSettingsStore.update(_:)` first, then `ConfigStore.save(_:)`.
  - Existing Settings UI intentionally avoids `@AppStorage` and live config reload.
  - The app is `LSUIElement` menu-bar only; Settings is opened from the status menu through an AppKit-owned window.
  - SwiftUI layout cannot be fully proven by XCTest, so manual screenshot/UI checks remain required.
- Dependencies identified:
  - Manual numeric input needs a commit model that does not persist invalid intermediate strings on every keystroke.
  - Read-only Launch at Login is a product-contract change from the initial Settings integration and must be documented.
  - A strict “fit everything” window size must not make the window unusable on small screens; keep resizable/scroll fallback.

## Development Approach

- **Testing approach**: Regular — implement focused UI/model fixes, then add/update tests in the same task before moving to the next.
- Complete each task fully before moving to the next.
- Make small, focused changes.
- Every code task must include new/updated tests for the changed behavior.
- All tests must pass before starting the next task.
- Update this plan file when scope changes during implementation.
- Maintain backward compatibility with existing config files and runtime settings behavior.
- Do not reintroduce `@AppStorage`, UserDefaults persistence, live config reload, or a second settings source.

## Testing Strategy

- **Unit tests**: required for view-model parsing/commit behavior, read-only Launch at Login state, message-field state, and window sizing contracts.
- Prefer adding focused new test files for polish-specific contracts instead of further bloating `SettingsViewModelTests.swift` if the new cases are substantial.
- **E2E tests**: no UI e2e harness exists; do not add one for this polish pass.
- **Manual checks**: required for real macOS visual layout because SwiftUI `Form`, `Stepper`, `TextField`, and `NSWindow` sizing differ between runtime and unit-test inspection.

## Progress Tracking

- Mark completed items with `[x]` immediately when done.
- Add newly discovered tasks with ➕ prefix.
- Document issues/blockers with ⚠️ prefix.
- Update plan if implementation deviates from original scope.
- Keep plan in sync with actual work done.

## What Goes Where

- **Implementation Steps** checkboxes are for codebase-achievable work: code, tests, docs, and validation commands.
- **Post-Completion** has no checkboxes and is for manual UI/signing/Login Item verification.
- Checkboxes belong only in Task sections. Do not add checkboxes in Success criteria, Overview, Context, or Post-Completion.

## Implementation Steps

### Task 1: Make the Settings window fit the full form by default

- [x] update `Mahu/SettingsView.swift` default frame so all current sections fit without immediate scrolling on normal macOS displays
- [x] update `Mahu/SettingsWindowController.swift` sizing if needed so initial content size/minimum size are deterministic and large enough for the full form
- [x] preserve resizable window behavior and a safe scroll/resize fallback for small displays or accessibility text scaling
- [x] update `MahuTests/SettingsWindowControllerTests.swift` to assert the expected minimum/content size is large enough for the complete Settings form
- [x] run focused settings window tests - must pass before Task 2

### Task 2: Add editable numeric timer duration controls

- [x] add a focused SwiftUI numeric stepper row component or helper for `TextField` plus `Stepper` with the numeric text field immediately before the stepper arrows
- [x] apply the row to `Work Duration`, keeping minutes, range `1...180`, and manual input support
- [x] apply the row to `Break Duration`, keeping seconds, range `5...600`, and step `5`
- [x] make manual input commit on submit and focus loss, clamping/rounding to the same ranges as the stepper without saving invalid intermediate strings
- [x] write/update tests for parsing, clamping, rounding-to-step, commit-on-submit/focus-loss model behavior, and immediate stepper updates
- [x] add any new production/test source files to `Mahu.xcodeproj/project.pbxproj`
- [x] run focused settings model/control tests - must pass before Task 3

### Task 3: Make Launch at Login read-only in Settings

- [x] update `Mahu/SettingsView.swift` so the Launch at Login toggle is disabled/read-only but still reflects `viewModel.launchAtLoginEnabled`
- [x] prevent the Settings UI from calling `viewModel.updateLaunchAtLoginEnabled` from user interaction while preserving the existing runtime sync path for config/runtime changes outside this control
- [x] update footer copy to explain that the Settings row reflects desired state and is currently changed through config/signing-supported flows, not this disabled control
- [x] update or add tests proving the Settings-facing Launch at Login control is read-only and does not mutate runtime settings through UI interaction
- [x] update `README.md`, `AGENTS.md`, and `docs/decisions.md` to supersede the earlier editable Settings toggle contract
- [x] run focused Settings/runtime Launch at Login tests - must pass before Task 4

### Task 4: Fix idle-away threshold row layout

- [x] update the `Away Behavior` row so the threshold number is always visible at the far right, immediately before the idle-away toggle
- [x] use the same editable numeric field + stepper style as timer rows for the idle-away threshold, using minutes and range `1...240`
- [x] keep the threshold visible when idle-away reset is off; disable editing if needed, but do not hide the current value
- [x] preserve the toggle behavior for `idleAwayResetEnabled` and avoid any HID idle polling changes
- [x] write/update tests for threshold visibility state, enabled/disabled editability state, and threshold commit behavior
- [x] run focused idle-away settings tests - must pass before Task 5

### Task 5: Make break overlay message editing obvious

- [x] remove the confusing `Time to look away` placeholder from `SettingsViewModel`/`SettingsView`
- [x] style the break overlay message input as an obvious editable text field, such as a rounded/bordered full-width field under or beside the label
- [x] ensure the current message value is the only visible editable text; the default Russian message should appear as the value when it is the active setting
- [x] preserve existing draft/commit behavior and whitespace-to-default normalization
- [x] add helper/footer text if needed, for example that the message is shown on future break overlays
- [x] write/update tests for placeholder removal, draft value display state, commit behavior, and empty/whitespace normalization
- [x] run focused break-message settings tests - must pass before Task 6

### Task 6: Verify acceptance criteria

- [x] manual test (skipped - not automatable): verify the Settings window opens with all sections visible without manual resizing on a normal display
- [x] manual test (skipped - not automatable): verify Work Duration and Break Duration can be changed by both manual text input and stepper arrows
- [x] manual test (skipped - not automatable): verify Launch at Login reflects config/runtime state but cannot be changed from Settings UI
- [x] manual test (skipped - not automatable): verify idle-away threshold value is visible at the far right before the toggle and follows the expected enabled/disabled editability behavior
- [x] manual test (skipped - not automatable): verify Break overlay message looks like an editable field and no longer shows `Time to look away`
- [x] verify edge cases are handled: invalid numeric input, out-of-range values, whitespace-only break message, save failure warning
- [x] run focused Settings tests
- [x] run full unit test suite with `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run build with `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run `make build`
- [x] run `git diff --check`

### Task 7: Final documentation pass

- [x] update `README.md` manual Settings checks to cover full-window fit, numeric manual input, read-only Launch at Login, visible idle threshold, and obvious message editing
- [x] update `AGENTS.md` Settings invariants so future agents preserve the read-only Launch at Login row and source-of-truth boundaries
- [x] ensure `docs/decisions.md` records the read-only Launch at Login and Settings polish decisions
- [x] inspect `git status --short --branch --untracked-files=all` and confirm only intended files changed
- [x] verify all implementation-plan checkboxes are complete before handoff

## Technical Details

- Numeric row behavior:
  - Use a text field for manual numeric input and a stepper for increment/decrement.
  - Place the text field directly before the stepper arrows on the trailing side of the row.
  - Commit manual text on submit and focus loss.
  - Clamp values to the same ranges already used by `SettingsViewModel`.
  - For break seconds, preserve step `5` and round committed manual values consistently with existing model normalization.
- Layout behavior:
  - Increase the default content size enough for all current Settings sections.
  - Keep the window resizable.
  - Do not rely only on SwiftUI `Form`'s current `fittingSize` if it underestimates content.
- Launch at Login behavior:
  - The disabled toggle reflects `launchAtLoginEnabled` from runtime/config.
  - User interaction in the Settings window must not mutate `launchAtLoginEnabled`.
  - Do not remove existing config/runtime Launch at Login sync logic; this is a UI affordance change, not removal of the feature.
- Break message behavior:
  - The editable text field should show the current value.
  - No English placeholder should appear when the actual default is Russian.
  - Draft typing alone must not rewrite runtime/config; commit on submit, focus loss, or window close.
  - Close-triggered draft commits must run through the retained AppKit window close path so save failures can keep the window open long enough to show the inline warning.
  - Whitespace-only input still normalizes to `AppConfig.defaultBreakOverlayMessageText` on commit.
  - A committed message change affects future break overlays only; an already visible break keeps its current title.

## Post-Completion

*Items requiring manual intervention or external systems - no checkboxes, informational only.*

**Manual verification:**

- Open Mahu Settings from the menu bar and confirm the whole form fits in the initial window on the target display.
- Confirm the window remains resizable and usable if manually shrunk or if system text scaling changes.
- Manually type Work Duration and Break Duration values, press Return, tab/focus away, and verify values commit/clamp correctly.
- Use stepper arrows for Work Duration, Break Duration, and idle-away threshold and verify the displayed values update cleanly.
- Confirm Launch at Login toggle is disabled/read-only while reflecting the current config/runtime value.
- Confirm idle-away threshold number remains visible next to the toggle even when idle-away reset is disabled.
- Confirm Break overlay message is visibly editable and no `Time to look away` text appears.

**External follow-up:**

- Real Launch at Login registration remains dependent on Apple-issued signing/macOS approval and is not validated by this UI polish pass.
