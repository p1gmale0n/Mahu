# Overlay Display Hot-Plug

## Overview

- Add active-break display hot-plug handling so Mahu keeps break overlay windows synchronized when displays are connected, disconnected, or resized during a break.
- Preserve current break state: countdown, `Skip`, previous-frontmost app restore, focus retention, and timer flow must not reset when displays change.
- Keep the implementation owned by `BreakOverlayManager`; do not move screen-change handling into `AppCoordinator`.
- Keep live config reload explicitly out of scope. Future GUI configuration should own runtime settings changes.

## Context (from discovery)

- Files/components involved: `Mahu/BreakOverlayManager.swift`, likely a new focused source file for screen-change observation, `MahuTests/BreakOverlayManagerTests.swift`, possibly `MahuTests/BreakOverlayDisplayHotPlugTests.swift`, `MahuTests/BreakOverlayFocusRetentionTests.swift`, `MahuTests/BreakOverlayTestSupport.swift`, `README.md`, `AGENTS.md`, and `docs/decisions.md`.
- Related patterns found: `BreakOverlayManager` already uses injected screen/window collaborators, a focus-observation registrar, idempotent cancellation closures, and fake registrars in tests.
- Dependencies identified: `NSApplication.didChangeScreenParametersNotification`, `NotificationCenter`, `NSScreen.screens`, `NSWindow`, `NSHostingView`, XCTest fake screen providers, and existing `xcodebuild`/`make build` validation commands.
- Current behavior: `NSScreen.screens` is read once in `showBreak()`, and `windows` is a plain `[BreakOverlayWindowing]` array without display identity.
- Current gap: display additions/removals during an active break do not create, close, or reposition overlay windows until the next break cycle.
- Worktree note: `icon.png` and `images/` are unrelated untracked items; do not modify, move, or delete them for this plan.
- `ralphex` is installed at `/opt/homebrew/bin/ralphex`.

## Development Approach

- **Testing approach**: Regular code first, then focused tests in the same task before moving to the next task.
- Use Option A: incremental display resync inside `BreakOverlayManager`.
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
- Maintain backward compatibility with current timer/config/status-item behavior.
- Do not implement live config reload or file watching.
- Do not use private APIs, Accessibility/Input Monitoring permissions, event taps, keyboard/mouse capture, or global shortcut blocking.
- Cognitive-load guard: `BreakOverlayManager.swift` is already near 300 lines, so put new live notification/coalescing support in a focused source file or keep manager changes minimal.

## Testing Strategy

- **Unit tests**: required for every task that changes code.
- **Manager tests**: verify display add/remove/frame-change behavior with injected screen provider, fake window builder, and fake screen observer registrar.
- **Focus tests**: verify display resync preserves focus retention, previous-app restore, and observer cancellation semantics.
- **Build verification**: run documented `xcodebuild` test/build commands and `make build`.
- **E2E tests**: none exist. Do not introduce UI automation for real monitor hot-plugging; hardware behavior remains manual validation.

## Progress Tracking

- Mark completed items with `[x]` immediately when done.
- Add newly discovered tasks with ➕ prefix.
- Document issues/blockers with ⚠️ prefix.
- Update plan if implementation deviates from original scope.
- Keep plan in sync with actual work done.

## What Goes Where

- **Implementation Steps**: unchecked task items for code changes, tests, documentation updates, and deterministic validation commands achievable inside this codebase.
- **Post-Completion**: manual external-display, display scaling/resolution, and fullscreen Space checks.
- **Checkbox placement**: Checkboxes belong only in Task sections (`### Task N:` or `### Iteration N:`). Do not put checkboxes in Success criteria, Overview, or Context because they cause extra loop iterations.

## Implementation Steps

### Task 1: Add screen-change observation seam
- [x] add a `BreakScreenObservationCancellation` typealias and `BreakScreenObservationRegistrar` typealias near the existing focus-observation types or in a focused new source file
- [x] implement a live screen observer using `NSApplication.didChangeScreenParametersNotification` and public `NotificationCenter` APIs
- [x] coalesce repeated screen-change notifications on the MainActor before invoking the resync handler
- [x] make screen-observation cancellation idempotent, matching the current focus-observer pattern
- [x] inject the screen-observation registrar into `BreakOverlayManager` with a live default and test override
- [x] add a fake screen observer registrar in `MahuTests/BreakOverlayTestSupport.swift` or a focused test-support file
- [x] write tests proving `showBreak()` does not register screen observation when there are no displays and returns `false`
- [x] run `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` - must pass before next task

### Task 2: Track active overlay windows by display
- [x] replace the internal plain windows array with display-associated active overlay records, while preserving existing external behavior
- [x] keep each active record tied to its `DisplayDescriptor` and `BreakOverlayWindowing`
- [x] update `showBreak()` to create active overlay records from the initial screen provider result
- [x] update `hideBreak()` and `Skip` handling to close all active overlay windows and clear both focus and screen observers
- [x] update focus-loss handling to re-show all current active overlay windows and reactivate Mahu
- [x] write tests proving initial one-window-per-display behavior remains unchanged
- [x] write tests proving `hideBreak()` and `Skip` close all active overlay windows after the internal model change
- [x] run `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` - must pass before next task

### Task 3: Resync overlays on display changes
- [x] add a private screen-change handler that reads the current `screenProvider()` only while a break is active
- [x] create overlay windows for newly added displays using the existing shared `BreakOverlayViewModel`
- [x] close overlay windows for removed displays without calling `hideBreak()` or restoring the previous app
- [x] recreate or replace overlay windows when an existing display frame changes
- [x] keep existing windows for unchanged displays instead of rebuilding all windows
- [x] reactivate Mahu only when a display change actually creates, removes, or replaces overlay windows
- [x] if `screenProvider()` returns an empty list during an active break, do not clear `viewModel`, do not cancel observers, and do not silently end the break
- [x] write tests for adding a display during an active break
- [x] write tests for removing a display during an active break
- [x] write tests for display frame changes during an active break
- [x] write tests for empty screen-provider results during an active break
- [x] run `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` - must pass before next task

### Task 4: Preserve focus and restore semantics after hot-plug
- [x] verify hot-plug resync does not call `previousAppCapture` again
- [x] verify `hideBreak()` still restores only the app captured at break start after display changes
- [x] verify focus-loss after display changes re-shows all current overlay windows
- [x] verify repeated `showBreak()` cancels previous focus and screen observers before registering new ones
- [x] verify `hideBreak()` and `Skip` cancel both focus and screen observers before later fake events can fire
- [x] write or update tests in `BreakOverlayFocusRetentionTests.swift`, `BreakOverlayManagerTests.swift`, or a new `BreakOverlayDisplayHotPlugTests.swift`
- [x] run `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` - must pass before next task

### Task 5: Update documentation and decision history
- [x] update `README.md` current behavior and manual checks to mention active-break display hot-plug handling
- [x] update `AGENTS.md` if future agents need to preserve the hot-plug behavior as a product invariant
- [x] update `docs/decisions.md` with the final implementation decision for display hot-plug handling
- [x] update this plan with final validation notes and any manual display checks completed
- [x] keep live config reload documented as out of scope if the topic appears in implementation notes

Validation notes:
- Automated verification passed on 2026-05-22 with `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`.
- Automated verification passed on 2026-05-22 with `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`.
- Automated verification passed on 2026-05-22 with `make build`.
- Acceptance criteria were re-verified on 2026-05-22 with the same commands plus existing hot-plug/focus/background/status/config XCTest coverage.
- Real monitor hot-plugging, display scaling, and fullscreen Space behavior still remain manual-only in this environment even though the abstraction-level acceptance criteria are automated.
- No manual display hot-plug or fullscreen Space checks were completed in this environment; those remain in Post-Completion.

### Task 6: Verify acceptance criteria
- [x] verify active-break display additions create overlay windows without restarting the break (covered by `BreakOverlayManagerTests.testScreenChangeAddsDisplayDuringActiveBreak`; real monitor hot-plug still manual-only)
- [x] verify active-break display removals close stale overlay windows without ending the break when at least one display remains (covered by `BreakOverlayManagerTests.testScreenChangeRemovesDisplayDuringActiveBreak`; real monitor disconnect still manual-only)
- [x] verify display frame changes resync overlay windows (covered by `BreakOverlayManagerTests.testScreenChangeReplacesWindowWhenDisplayFrameChanges`; real scaling/resolution changes still manual-only)
- [x] verify countdown and `Skip` remain shared across all current overlay windows (covered by shared `BreakOverlayViewModel` usage plus hot-plug/focus tests; cross-display UI remains manual-only)
- [x] verify AppCoordinator, timer flow, config loading, status item, and background rendering behavior remain unchanged
- [x] verify no live config reload, file watcher, private API, Accessibility permission, event tap, keyboard/mouse capture, or global shortcut blocking was added
- [x] run full unit test suite with `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run final app build with `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run `make build`

*Note: real monitor hot-plugging, display scaling, and fullscreen Space behavior belong in Post-Completion because this environment can only validate the abstraction-level logic.*

## Technical Details

- Preferred live observer shape:

```swift
typealias BreakScreenObservationCancellation = @MainActor () -> Void
typealias BreakScreenObservationRegistrar = @MainActor (@escaping () -> Void) -> BreakScreenObservationCancellation
```

- Preferred ownership: `BreakOverlayManager` owns both focus and screen observers during an active break.
- Preferred internal model:

```swift
private struct ActiveOverlay {
    let display: DisplayDescriptor
    let window: BreakOverlayWindowing
}
```

- Preferred resync flow:

```swift
private func handleScreenChange() {
    guard let viewModel else {
        return
    }

    let currentDisplays = screenProvider()
    // Reconcile active overlays by DisplayDescriptor.
    // Add new windows, close removed or changed windows, preserve unchanged windows.
}
```

- Do not call `showBreak()` from the screen-change handler. It would recapture previous app state, replace observers, and risk resetting break semantics.
- Do not call `hideBreak()` from the screen-change handler. Display hot-plug should be a window-resync operation, not a break lifecycle transition.
- If a display disappears and later returns, a new overlay window should use the existing shared `viewModel` so countdown and `Skip` remain consistent.

## Post-Completion

*Items requiring manual intervention or external systems - no checkboxes, informational only.*

**Manual verification:**

- Build and run `build/Mahu.app` locally.
- Temporarily set short config durations in `~/Library/Application Support/Mahu/config.json`.
- Start a break with only the built-in display, then connect an external monitor and confirm an overlay appears on the new display.
- Start a break with an external monitor connected, then disconnect it and confirm the remaining display keeps the overlay.
- Change display resolution or scaling during an active break and confirm overlay windows resync.
- Press `Cmd+Tab` after hot-plug and confirm Mahu still reasserts focus.
- Press `Skip` after hot-plug and confirm all current overlay windows close.
- Let a break end naturally after hot-plug and confirm the previous frontmost app is restored.
- Test with a fullscreen app or Space if available and document any limitations separately.

**External/release follow-up:**

- Revisit fullscreen Spaces hardening separately if hot-plugging exposes Space-specific overlay placement issues.
- Implement future GUI settings separately instead of adding live config reload to this hot-plug work.
