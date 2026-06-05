# Tray Timer Width Stabilization

## Overview

Fix the tray status item timer-mode layout so `Paused` and countdown text are fully visible next to the tray icon without shrinking or jittering during timer updates.

The bug became visible after config parsing started correctly loading `showStatusItemTimerState: true`: Mahu can now enter timer-mode, but the live menu bar may truncate `Paused` to `Pau`. The likely cause is `StatusItemController` measuring `NSStatusBarButton.fittingSize.width` after the status item has already been constrained to a narrower countdown width.

This plan keeps the existing optional tray timer feature and freeze-to-widest behavior. It changes only status item width measurement and related regression coverage; config parsing, JSONC support, and coordinator timer semantics remain out of scope.

## Context (from discovery)

- Files/components involved:
  - `Mahu/StatusItemController.swift` — owns `NSStatusItem`, icon/title rendering, pause visual state, timer-mode width calculation, and freeze-to-widest state.
  - `Mahu/StatusDisplayFormatter.swift` — formats active countdowns and `Paused`; current text output is correct.
  - `Mahu/AppCoordinator.swift` — wires status item updates but should not own AppKit layout policy.
  - `Mahu/AppConfig.swift` — `showStatusItemTimerState` controls whether text is displayed; not the source of truncation.
  - `MahuTests/StatusItemTimerDisplayTests.swift` — best place for focused width regression coverage.
  - `MahuTests/AppCoordinatorStatusItemPauseResumeTests.swift` / `StatusItemMenuAcceptanceTests.swift` — existing surrounding behavior tests.
  - `docs/decisions.md` — record measurement-policy change if implemented.
- Related patterns found:
  - Timer mode uses icon + attributed title with a two-space prefix.
  - Text uses monospaced digits for countdown stability.
  - Width is frozen to the widest observed timer-mode length to prevent menu-bar drift.
  - Pausing work should show `Paused`; pausing during rest should keep showing the break countdown.
  - Disabling timer mode should reset the status item to icon-only square length.
- Dependencies identified:
  - No external dependencies.
  - Live `NSStatusItem` rendering still needs manual menu-bar verification because XCTest can inspect AppKit state but cannot fully prove system menu-bar truncation.

## Development Approach

- **Testing approach**: TDD.
- Complete each task fully before moving to the next.
- Make small, focused changes.
- **CRITICAL: every task MUST include new/updated tests** for code changes in that task:
  - add a failing regression for `00:10` countdown → paused work showing full `Paused` width;
  - update width stability tests if measurement behavior changes;
  - cover both success and edge cases.
- **CRITICAL: all tests must pass before starting next task** - no exceptions.
- **CRITICAL: update this plan file when scope changes during implementation**.
- Keep status item layout code inside `StatusItemController`.
- Do not change config loading, JSONC behavior, or coordinator timer semantics.
- Preserve freeze-to-widest behavior in timer mode.

## Testing Strategy

- **Unit tests** are required for every task.
- Use existing AppKit/XCTest status item seams where possible.
- Add regression coverage that proves `Paused` causes the status item width to expand beyond a narrower countdown width when timer mode is enabled.
- Preserve existing coverage for:
  - icon-only default square length;
  - countdown title formatting and monospaced digits;
  - width stability across countdown digit changes;
  - rest-phase pause keeping countdown visible;
  - timer-mode disable resetting to square icon-only mode.
- Manual live menu-bar verification remains required after automated tests pass.

## Progress Tracking

- Mark completed items with `[x]` immediately when done.
- Add newly discovered tasks with a `➕` prefix.
- Document issues/blockers with a `⚠️` prefix.
- Update this plan if implementation deviates from the original scope.
- Keep the plan in sync with actual work done.

## What Goes Where

- **Implementation Steps**: code changes, tests, documentation/decision updates, and deterministic verification commands.
- **Post-Completion**: live menu-bar screenshot/manual verification.
- **Checkbox placement**: checkboxes belong only in Task sections. Do not add checkboxes to Overview, Context, Technical Details, or Post-Completion.

## Implementation Steps

### Task 1: Add a failing paused-width regression test

- [x] add or update `MahuTests/StatusItemTimerDisplayTests.swift` with a regression where timer mode first displays a narrow countdown such as `00:10`
- [x] in the same test, pause reminders during work and assert the title becomes the full `"  Paused"`
- [x] assert the status item length expands or is at least sufficient for the full paused title instead of staying at the previous narrow countdown width
- [x] assert the menu switches to `Resume Reminders` and the tray icon remains visually dimmed without dimming button/title alpha
- [x] run targeted status item timer display tests and confirm the new regression fails for the current sizing bug before Task 2

### Task 2: Fix timer-mode width measurement in StatusItemController

- [x] update only the timer-mode width calculation path in `Mahu/StatusItemController.swift`
- [x] compute timer-mode width from the button's AppKit-reported natural width (`intrinsicContentSize`) instead of relying only on constrained `button.fittingSize.width`
- [x] keep `maximumTimerStatusItemLength = max(previous, measured)` so timer-mode width never shrinks while enabled
- [x] keep `setShowsTimerState(false)` resetting `maximumTimerStatusItemLength` and returning to `NSStatusItem.squareLength`
- [x] run targeted status item timer display tests - must pass before Task 3

### Task 3: Preserve timer-mode edge cases

- [x] verify pause during rest still shows the rest countdown, not `Paused`
- [x] verify resume from paused work returns to countdown without shrinking the status item length
- [x] verify long countdowns such as `100:00 -> 99:59` remain stable and do not shrink
- [x] verify icon-only mode remains unchanged when `showStatusItemTimerState` is disabled
- [x] run all status-item/coordinator display tests - must pass before Task 4

### Task 4: Update decision history if measurement policy changes

- [x] update `docs/decisions.md` with the chosen width measurement policy and why `fittingSize` alone was insufficient
- [x] update README or AGENTS only if the shipped user-facing/manual-check contract changes (not needed - no user-facing/manual-check contract changed)
- [x] run `git diff --check` - must pass before Task 5

### Task 5: Verify acceptance criteria

- [x] verify `showStatusItemTimerState: true` work-pause path renders full `Paused`, not a truncated `Pau`, through tests
- [x] verify countdown mode still renders icon + countdown text
- [x] verify width freeze still prevents timer text jitter/drift during countdown changes
- [x] verify JSONC/config behavior is not touched by this fix
- [x] run full unit test suite with `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run build with `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run `make build`
- [x] run `git diff --check`

## Technical Details

### Current failure mode

Current timer-mode code effectively does:

```swift
button.attributedTitle = makeTimerStateTitle(currentTimerStateText())
button.imagePosition = .imageLeading
let measuredLength = ceil(button.fittingSize.width)
maximumTimerStatusItemLength = max(maximumTimerStatusItemLength, measuredLength)
statusItem.length = maximumTimerStatusItemLength
```

This can under-measure when the button is already constrained by a previously frozen status item length. The result is a too-small `NSStatusItem.length`, so AppKit truncates `Paused` in the live menu bar.

### Desired behavior

- Timer mode may be slightly wider than before.
- The text must be fully visible for normal countdowns and `Paused`.
- Width must not shrink while timer mode is enabled.
- Width should reset only when timer mode is disabled.
- Layout policy stays localized in `StatusItemController`.

### Candidate measurement strategy

Measure conservatively using a max of:

- existing `button.fittingSize.width`,
- `button.intrinsicContentSize.width` as AppKit's natural width for the current icon/title combination,
- `NSStatusItem.squareLength` minimum.

The exact helper shape is up to implementation, but it should stay tied to AppKit-owned measurement instead of hardcoded menu-bar spacing guesses so the unit tests can assert the same native width contract.

## Post-Completion

*Items requiring manual intervention or external systems - no checkboxes, informational only.*

**Manual verification**:

- Use a config with `"showStatusItemTimerState": true` and short work duration.
- Launch `build/Mahu.app`.
- Pause reminders during work.
- Confirm the live menu bar shows the full `Paused` text, not `Pau`.
- Resume reminders and confirm the countdown returns without horizontal jitter.
- Confirm rest-phase pause still shows countdown rather than `Paused`.

**Future follow-up**:

- If native status item sizing remains inconsistent across macOS versions, consider a more explicit AppKit layout strategy, but avoid replacing the native status item view unless the conservative width calculation still fails manually.
