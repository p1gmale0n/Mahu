# Tray Timer Icon Anchor Stabilization

## Status

Completed on 2026-06-04. Pending archive after external review.
This change set addresses Tasks 1-6 in this plan.
Post-review hardening already landed on top of the original tasks: runtime duration updates now distinguish between clear-only baseline resets before active-work timer restarts and immediate recomputation for paused/rest display states.

## Overview

Stabilize the tray status item icon position when timer-mode text switches between countdown values and `Paused`.

The previous tray-width fix prevents text truncation by freezing the outer `NSStatusItem.length`, but AppKit still centers the current `icon + title` content group inside that fixed slot. Because `Paused` and countdown strings have different natural widths, the icon can visibly shift left/right when switching states.

This plan keeps Mahu on the native `NSStatusItem` / `NSStatusBarButton` path and avoids a custom status item view. The intended fix is to stabilize the title area itself, so the content group presented to AppKit has a consistent width across `MM:SS`, long countdowns, and `Paused`.

## Context (from discovery)

- Files/components involved:
  - `Mahu/StatusItemController.swift` — owns native status item rendering, title construction, width caches, pause visual state, and timer-mode layout policy.
  - `Mahu/StatusDisplayFormatter.swift` — formats countdowns and `Paused`; not the source of drift.
  - `Mahu/AppCoordinator.swift` — wires status updates; should not own AppKit layout policy.
  - `MahuTests/StatusItemTimerDisplayTests.swift` — existing timer-mode coverage; near the local file-size limit.
  - New focused test file may be preferable, e.g. `MahuTests/StatusItemTimerAnchorTests.swift`, if anchor-slot tests would bloat the existing file.
  - `MahuTests/StatusItemMenuAcceptanceTests.swift` — real menu action coverage for pause/resume.
  - `docs/decisions.md` — record the title-slot policy decision.
- Related patterns found:
  - Timer-mode text uses a two-space prefix and `NSFont.monospacedDigitSystemFont` for stable digit widths.
  - Monospaced digits do not make letters, colons, or different-length strings equal width.
  - Existing `maximumTimerStatusItemLength` freezes the outer item width, not the inner title slot.
  - Work pause shows `Paused`; rest pause keeps showing countdown.
  - Timer mode can be runtime-toggled and must reset internal width caches when disabled.
- Dependencies identified:
  - No external dependencies.
  - Live menu-bar pixel behavior remains manual-only; XCTest can prove state and width policy but not exact system menu-bar rendering.

## Development Approach

- **Testing approach**: TDD.
- Complete each task fully before moving to the next.
- Make small, focused changes.
- **CRITICAL: every task MUST include new/updated tests** for code changes in that task:
  - add tests for `MM:SS <-> Paused` icon-anchor/title-slot stability;
  - add tests for long countdowns wider than or comparable to `Paused`;
  - add tests for reset/recompute behavior on explicit display/settings reset boundaries.
- **CRITICAL: all tests must pass before starting next task** - no exceptions.
- **CRITICAL: update this plan file when scope changes during implementation**.
- Keep native `NSStatusItem` behavior; do not introduce a custom status item view unless this plan is explicitly revised.
- Keep layout policy inside `StatusItemController`.
- Do not change config parsing, JSONC behavior, or coordinator timer semantics.

## Testing Strategy

- **Unit tests** are required for every task.
- Prefer a small focused test file if adding anchor-slot assertions would push `StatusItemTimerDisplayTests.swift` too far past the readability limit.
- Required coverage:
  - `MM:SS -> Paused -> MM:SS` keeps a stable title slot/content width;
  - long countdown such as `100:00 -> Paused -> 99:59` stays stable and does not shrink per tick;
  - `Paused` remains fully visible;
  - rest-phase pause keeps countdown visible;
  - disabling timer mode resets both outer status item width and title-slot width caches;
  - future settings/display reset seam allows width recomputation without allowing per-tick shrink/jitter.
- Manual live menu-bar verification remains required after automated tests pass.

## Progress Tracking

- Mark completed items with `[x]` immediately when done.
- Add newly discovered tasks with a `➕` prefix.
- Document issues/blockers with a `⚠️` prefix.
- Update this plan if implementation deviates from the original scope.
- Keep the plan in sync with actual work done.

## What Goes Where

- **Implementation Steps**: code changes, tests, documentation/decision updates, and deterministic verification commands.
- **Post-Completion**: live tray/menu-bar visual verification.
- **Checkbox placement**: checkboxes belong only in Task sections. Do not add checkboxes to Overview, Context, Technical Details, or Post-Completion.

## Implementation Steps

### Task 1: Add failing icon-anchor/title-slot regression tests

- [x] add focused tests for `MM:SS -> Paused -> MM:SS` proving the timer title/content slot width remains stable while visible text changes
- [x] add focused tests for long countdowns, such as `100:00 -> Paused -> 99:59`, proving the title slot does not shrink during ordinary ticks
- [x] add tests proving digits are treated as a countdown text class, not per-glyph width cases, because `monospacedDigitSystemFont` already equalizes numeric glyph widths
- [x] add or update tests proving rest-phase pause still shows countdown rather than `Paused`
- [x] run targeted status item tests and confirm the new anchor-slot regression fails before Task 2

### Task 2: Implement fixed-width timer title slot

- [x] update `StatusItemController` to track timer title-slot width separately from outer status item width
- [x] build timer-mode attributed titles with an invisible trailing spacer or equivalent fixed-width title-slot mechanism so shorter visible titles occupy the current slot width
- [x] keep visible title text unchanged for user-facing display and assertions, including the existing two-space prefix
- [x] keep `maximumTimerStatusItemLength` freeze-to-widest behavior for the outer `NSStatusItem.length`
- [x] run targeted anchor/status item tests - must pass before Task 3

### Task 3: Add explicit reset/recompute behavior for settings boundaries

- [x] add a small `StatusItemController` seam to reset/recompute timer display width baselines on explicit settings/display-reset boundaries without shrinking on ordinary timer ticks
- [x] reset both outer item width and title-slot width when timer mode is disabled
- [x] verify future runtime settings changes can call the reset seam without touching config parsing or timer semantics
- [x] test that after a reset, a shorter duration can use a smaller stable title slot, while normal countdown ticks still do not shrink the slot
- [x] run targeted status item tests - must pass before Task 4

### Task 4: Preserve existing status item behavior

- [x] verify `Paused` remains fully visible and the tray icon image remains dimmed while button/title alpha stays full opacity
- [x] verify real menu actions still switch `Pause Reminders` / `Resume Reminders` and preserve stable layout
- [x] verify no-icon fallback remains predictable and does not crash the title-slot logic
- [x] verify icon-only default mode remains `NSStatusItem.squareLength` with empty title
- [x] run all status-item and coordinator display/pause tests - must pass before Task 5

### Task 5: Update documentation and decision history

- [x] update `docs/decisions.md` with the fixed-width title-slot decision and why full monospace/custom view were rejected for this scope
- [x] update README or AGENTS only if the manual-check/user-facing contract needs clarification (not needed; current docs already cover pinned-width behavior and manual tray verification)
- [x] run `git diff --check` - must pass before Task 6

### Task 6: Verify acceptance criteria

- [x] verify `showStatusItemTimerState: true` work-pause path keeps the icon visually anchored for `MM:SS -> Paused -> MM:SS` through tests and manual checklist (manual tray check skipped - not automatable in this environment)
- [x] verify long countdowns do not shrink or reintroduce icon drift during normal ticks
- [x] verify `Paused` remains fully visible
- [x] verify rest-phase pause keeps countdown visible
- [x] verify no custom status item view was introduced
- [x] run full unit test suite with `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run build with `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run `make build`
- [x] run `git diff --check`

## Technical Details

### Current failure mode

The current outer width is frozen, but the visible content group still changes width:

```text
[ frozen status item slot ]
        [ icon + 00:10 ]

[ frozen status item slot ]
      [ icon + Paused ]
```

AppKit centers that changing group, so the icon moves even though `NSStatusItem.length` does not shrink.

### Desired title-slot behavior

The native button should effectively present a stable title slot:

```text
[ frozen status item slot ]
      [ icon + fixed-width-title-slot ]
```

The visible text can change, but the measured title area should remain stable across countdown and paused states until an explicit reset/recompute boundary occurs.

### Font note

`NSFont.monospacedDigitSystemFont` makes digits equal-width, but it does not make letters equal to digits or make different-length strings equal-width. Therefore full monospace text is not a complete fix: `00:10`, `Paused`, `100:00`, and `1:00:00` have different character counts and can still differ in total width.

### Future settings behavior

If a future Settings UI reduces work/rest durations after a previously longer timer widened the title slot, Mahu should be able to reset/recompute the stable width at that explicit settings-change boundary. Shrinking on ordinary timer ticks remains forbidden because it would reintroduce jitter.

## Post-Completion

*Items requiring manual intervention or external systems - no checkboxes, informational only.*

**Manual verification**:

- Use a config with `"showStatusItemTimerState": true` and short work duration.
- Launch `build/Mahu.app`.
- Observe countdown, then choose `Pause Reminders`, then `Resume Reminders`.
- Confirm the icon does not shift horizontally during `MM:SS -> Paused -> MM:SS`.
- Repeat with a longer countdown if practical.
- Confirm `Paused` remains fully visible and rest-phase pause still shows countdown.

**Future follow-up**:

- If fixed-width attributed titles do not stabilize live menu-bar rendering across macOS versions, consider a custom status item view as a larger follow-up, but only after native title-slot stabilization is proven insufficient.
