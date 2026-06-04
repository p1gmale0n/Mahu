# Overlay Focus Hardening

## Status

- Implementation changes are complete in the repo as of 2026-05-21.
- Manual hardware verification is still pending for `Cmd+Tab` bounce-back timing, previous-app restore after break end or `Skip`, external displays, and fullscreen Spaces.

## Overview

- Harden Mahu's active break overlay against accidental focus switching, especially `Cmd+Tab` to another application while the overlay still covers the screen.
- The feature should not block system shortcuts directly. Instead, while a break is active, Mahu should quickly reassert itself as the active app and bring all overlay windows back to the front if focus leaves the app.
- This reduces the risk of typing or triggering actions in another app hidden behind the overlay, while preserving public-API and App Store-aware constraints.
- The implementation should integrate with the existing `BreakOverlayManager` because it already owns overlay windows, app activation, previous-frontmost-app capture, and restore behavior.

## Context (from discovery)

- Files/components involved: `Mahu/BreakOverlayManager.swift`, `MahuTests/BreakOverlayManagerTests.swift`, `README.md`, `AGENTS.md`, and `docs/decisions.md`.
- Related patterns found: `BreakOverlayManager` already creates one `.screenSaver` borderless key-capable window per `NSScreen`, calls `makeKeyAndOrderFront(nil)`, calls `NSApp.activate(ignoringOtherApps: true)`, and restores the previous frontmost app when the break ends.
- Dependencies identified: public AppKit APIs, `NSApplication.didResignActiveNotification`, `NSWorkspace.didActivateApplicationNotification`, `NotificationCenter`, `NSWorkspace`, existing fake window builder tests.
- Current constraints: no system-level keyboard/mouse capture, no private APIs, keep AppKit side effects at the overlay edge, keep fullscreen Spaces and real multi-display behavior as manual validation.
- Worktree note: the repo currently has unrelated uncommitted build-helper changes (`Makefile`, `.gitignore`, README/decisions updates) and an untracked `config.json`; do not overwrite or revert them while executing this plan.

## Development Approach

- **Testing approach**: Regular code first, then tests in each task before moving to the next task.
- Use Option A: public API focus bounce-back through application/workspace notifications.
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
- Maintain backward compatibility with current MVP behavior: `Skip`, countdown updates, previous-app restore, all-displays overlay, and config/timer flow must keep working.
- Do not add `CGEventTap`, Accessibility permissions, global keyboard capture, global mouse capture, or private APIs.

## Testing Strategy

- **Unit tests**: required for every task that adds or changes code.
- **Focus observer tests**: simulate focus-loss events through an injectable observer/registrar instead of relying on real `NSWorkspace` notifications.
- **Overlay manager tests**: verify active overlay focus-loss re-shows existing windows and reactivates the app.
- **Lifecycle tests**: verify observers are installed only while a break is active and are removed on `hideBreak()` and `Skip`.
- **Regression tests**: verify previous-frontmost-app restore is not overwritten by bounce-back events.
- **E2E tests**: none exist. Do not introduce UI automation for this feature; keep real `Cmd+Tab`, fullscreen Space, and multi-display behavior in Post-Completion manual checks.

## Progress Tracking

- Mark completed items with `[x]` immediately when done.
- Add newly discovered tasks with ➕ prefix.
- Document issues/blockers with ⚠️ prefix.
- Update plan if implementation deviates from original scope.
- Keep plan in sync with actual work done.

## What Goes Where

- **Implementation Steps** (`[ ]` checkboxes): code changes, tests, and documentation updates achievable inside this repo.
- **Post-Completion**: manual `Cmd+Tab`, external display, fullscreen Space, and release/App Store checks.
- **Checkbox placement**: Checkboxes belong only in Task sections. Do not put checkboxes in Success criteria, Overview, or Context.

## Implementation Steps

### Task 1: Add focus-change observation seam
- [x] add a small focus-change observation abstraction near `BreakOverlayManager` so production can subscribe to public AppKit/NSWorkspace notifications and tests can trigger events deterministically
- [x] implement the live observer using public APIs only, preferring `NSApplication.didResignActiveNotification` and/or `NSWorkspace.didActivateApplicationNotification`
- [x] make observer registration return a cancellation closure or token that can be called exactly once during overlay teardown
- [x] write tests with a fake observer proving registration happens when a break is shown
- [x] write tests proving no observer action fires before a break is shown
- [x] run tests - must pass before next task

### Task 2: Reassert overlay focus while break is active
- [x] update `BreakOverlayManager.showBreak` so focus-loss events while windows are active call `show()` on existing overlay windows again
- [x] call the existing `appActivator` during focus reassertion so Mahu becomes active again after accidental app switching
- [x] avoid rebuilding overlay windows during focus reassertion; reuse the current windows and shared view model
- [x] ensure focus reassertion does not capture or overwrite the original previous-frontmost application used for restore
- [x] write tests that simulate focus loss and assert existing fake windows receive an additional `show()` call and `appActivator` runs again
- [x] write tests proving previous app restore still points to the app captured when the break started
- [x] run tests - must pass before next task

### Task 3: Tear down focus retention safely
- [x] update `BreakOverlayManager.hideBreak` so focus observer cancellation happens before or during window teardown
- [x] ensure `Skip` closes windows, cancels focus retention, forwards the skip callback, and then does not react to later focus-loss events
- [x] ensure repeated `showBreak` calls replace old observer registrations without leaking duplicate observers
- [x] write tests for observer cancellation on normal break end
- [x] write tests for observer cancellation on `Skip`
- [x] write tests for repeated `showBreak` not causing duplicate bounce-back callbacks
- [x] run tests - must pass before next task

### Task 4: Verify acceptance criteria
- [x] verify focus-loss hardening uses only public AppKit/Foundation APIs
- [x] verify no `CGEventTap`, Accessibility permission, private API, global keyboard capture, or global mouse capture was added
- [x] verify existing overlay behavior still opens one window per display in abstraction-level tests
- [x] verify existing timer, config, status item, skip, and coordinator tests still pass
- [x] run full unit test suite with `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run final app build with `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run `make build` if the local build helper remains present in the worktree

### Task 5: Update documentation and project knowledge
- [x] update `README.md` current behavior to describe best-effort focus retention during active breaks
- [x] update `AGENTS.md` if implementation-specific gotchas should be preserved for future agents
- [x] update `docs/decisions.md` with the final focus-retention decision if implementation details differ from this plan
- [x] update this plan with any scope changes and final validation notes

Validation notes:
- No scope expansion was needed beyond the original public-API bounce-back design.
- `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` passed on 2026-05-21 during Task 5.
- `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` passed on 2026-05-21 during Task 5.
- `make build` passed on 2026-05-21 and produced `build/Mahu.app`.

## Technical Details

- Preferred design: keep focus-retention inside `BreakOverlayManager`, because it owns the lifetime of break windows and the previous-frontmost-app restore flow.
- Suggested production behavior:
  - On `showBreak`, create windows and activate Mahu as today.
  - Register a focus-loss observer only after there is at least one overlay window.
  - On focus-loss notification, if windows are still active, call `show()` on each existing `BreakOverlayWindowing` and call `appActivator()`.
  - On `hideBreak`, cancel the observer, close windows, clear view model, clear stored previous app, and restore the original previous app if requested.
- Suggested test seam:
  - Inject a focus observer closure/factory into `BreakOverlayManager`.
  - Fake observer stores an event handler that tests can call to simulate `Cmd+Tab`/active-app changes.
  - Fake windows expose `showCallCount` and `closeCallCount`, already matching existing test style.
- Important limitation: public APIs cannot fully prevent `Cmd+Tab`; they can only make Mahu reassert focus quickly after the system changes active application.

## Post-Completion

*Items requiring manual intervention or external systems - no checkboxes, informational only.*

**Manual verification:**
- Build and run `build/Mahu.app` locally.
- Temporarily set short config durations and wait for the overlay.
- Press `Cmd+Tab` while the overlay is visible and verify Mahu quickly returns to the front.
- Type immediately after attempting `Cmd+Tab` only to characterize bounce-back timing; the current public-API approach does not guarantee that zero keystrokes leak before Mahu reactivates.
- Let a break end naturally and also press `Skip`, then verify focus returns to the app that was frontmost before Mahu activated the overlay.
- Test with an external display if available.
- Test with a fullscreen app/Space and document any remaining limitations.

**External/release follow-up:**
- Revisit App Store review risk before adding stronger input-blocking behavior.
- If best-effort focus retention is insufficient, create a separate plan that explicitly evaluates Accessibility/Input Monitoring permissions and App Store trade-offs before implementation.
