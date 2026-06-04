# Overlay Content Centering Fix

## Status

- Implementation changes and automated validation are complete in the repo as of 2026-05-22.
- Manual built-in-display, external-display, and fullscreen-Space centering checks still remain under Post-Completion.

## Overview

- Fix the break overlay foreground alignment so `Время отвлечься`, the countdown, and `Skip` are centered in the visible overlay bounds on the built-in MacBook display.
- Preserve the current visual design: bundled background image, dark readability layer, fonts, spacing, countdown behavior, and `Skip` styling.
- Keep this plan scoped to `BreakOverlayView` SwiftUI layout. Do not change AppKit window creation, display enumeration, focus retention, timer flow, or resource packaging in this plan.
- The background may still crop with `.scaledToFill()` on non-16:9 displays, but the foreground controls must remain centered in the actual window area.

## Context (from discovery)

- Files/components involved: `Mahu/BreakOverlayView.swift`, `MahuTests/BreakOverlayViewTests.swift`, `Mahu/BreakOverlayManager.swift` for context only, `docs/plans/completed/2026-05-22-overlay-background-rendering-fix.md`, `README.md`, `AGENTS.md`, and `docs/decisions.md`.
- Related patterns found: `BreakOverlayView` now explicitly loads `background.png` with `NSImage` and renders it via `Image(nsImage:)`; the root `ZStack` has no explicit fullscreen sizing contract.
- Dependencies identified: SwiftUI `GeometryReader`, `.frame(width:height:alignment:)`, `.clipped()`, AppKit `NSHostingView`, XCTest, and existing `xcodebuild`/`make build` validation commands.
- Observed bug: on the MacBook display, foreground elements are shifted horizontally while the connected external monitor appears correct.
- Likely cause: `scaledToFill()` can make the background image's layout wider than the visible 16:10 window, and the foreground `VStack` can center relative to that expanded `ZStack` instead of the window bounds.
- Current worktree note: `icon.png` and `images/` are unrelated untracked items; do not modify, move, or delete them for this fix.
- `ralphex` is installed at `/opt/homebrew/bin/ralphex`.

## Development Approach

- **Testing approach**: Regular code first, then focused tests in the same task before moving to the next task.
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
- Preserve current user-visible overlay behavior and resource-loading behavior.
- Do not use hardcoded `.offset(...)` values. That would only fit one display and regress other aspect ratios.
- Do not change `BreakOverlayManager` or `LiveBreakOverlayWindow` in this plan. If SwiftUI-only sizing is insufficient, record a blocker and create a separate AppKit-hosting plan.

## Testing Strategy

- **Unit tests**: required for every task that changes code.
- **Overlay tests**: keep existing checks for title, countdown, `Skip`, image-loader fallback, and single image-load behavior green.
- **Layout tests**: avoid brittle pixel/snapshot tests unless the project already has stable infrastructure for them. Prefer view construction and behavior-preservation tests for automated coverage.
- **Build verification**: run documented `xcodebuild` test/build commands and `make build`.
- **E2E tests**: none exist. Do not introduce a UI automation framework for this small layout fix; final visual centering remains a manual acceptance check.

## Progress Tracking

- Mark completed items with `[x]` immediately when done.
- Add newly discovered tasks with ➕ prefix.
- Document issues/blockers with ⚠️ prefix.
- Update plan if implementation deviates from original scope.
- Keep plan in sync with actual work done.

## What Goes Where

- **Implementation Steps**: unchecked task items for code changes, tests, documentation updates, and deterministic validation commands achievable inside this codebase.
- **Post-Completion**: manual visual checks on real displays and fullscreen Spaces.
- **Checkbox placement**: Checkboxes belong only in Task sections (`### Task N:` or `### Iteration N:`). Do not put checkboxes in Success criteria, Overview, or Context because they cause extra loop iterations.

## Implementation Steps

### Task 1: Center overlay content within explicit window bounds
- [x] update `Mahu/BreakOverlayView.swift` to wrap the root overlay layout in `GeometryReader`
- [x] constrain the background image or fallback color to `geometry.size.width` and `geometry.size.height`
- [x] keep `.scaledToFill()` for the background image but add clipping so the image crop cannot expand the root layout size
- [x] constrain the dark readability layer to the same geometry-sized bounds
- [x] place the foreground `VStack` in a geometry-sized frame with center alignment so it centers on the visible overlay window, not on the cropped image
- [x] preserve current fonts, spacing, opacity, countdown text, and `Skip` action behavior
- [x] update `MahuTests/BreakOverlayViewTests.swift` so existing title/countdown/`Skip` and background fallback coverage remains green after the layout change
- [x] add a focused test that constructs the overlay with a non-16:9-sized background image loader and verifies required foreground text remains present
- [x] run `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` - must pass before next task

### Task 2: Verify scope boundaries and automated acceptance
- [x] verify `Mahu/BreakOverlayManager.swift` is unchanged by this plan
- [x] verify `BreakOverlayBackgroundImageLoader` still loads from the bundled resource and still returns nil for missing/undecodable images
- [x] verify no hardcoded display-specific offsets, dimensions, or MacBook-only constants were introduced
- [x] run full unit test suite with `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run final app build with `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run `make build`

### Task 3: Update documentation and decision history
- [x] update `docs/decisions.md` with the final implementation decision for explicit fullscreen SwiftUI layout sizing
- [x] update `README.md` with manual centering verification guidance in `## Manual Checks`
- [x] update this plan with final validation notes and any manual display checks completed

### Task 4: Verify acceptance criteria
- [x] verify the foreground layout is explicitly centered within the overlay window bounds in code
- [x] verify the background still fills the overlay with `.scaledToFill()` and remains clipped to the visible bounds
- [x] verify title, countdown, `Skip`, image fallback, focus retention, multi-display window creation, and timer flow remain unchanged
- [x] run full unit test suite with `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run final app build with `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run `make build`

*Note: manual MacBook/external-monitor visual verification belongs in Post-Completion because this environment cannot prove live rendered pixel alignment in real overlay windows.*

## Validation Notes

- 2026-05-22: `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` passed after the centering fix.
- 2026-05-22: `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` passed after the centering fix.
- 2026-05-22: `make build` passed and produced `build/Mahu.app`.
- 2026-05-22: No manual display checks were completed in this environment; built-in MacBook and external-monitor centering remain Post-Completion validation.
- 2026-05-22: Final acceptance verification confirmed `BreakOverlayView` still centers foreground content inside geometry-sized window bounds, keeps the `.scaledToFill()` background clipped to visible bounds, and preserves existing overlay/timer behavior without `BreakOverlayManager` changes.

## Technical Details

- Preferred SwiftUI shape:

```swift
var body: some View {
    GeometryReader { geometry in
        ZStack {
            backgroundView
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()

            Color.black.opacity(0.48)
                .frame(width: geometry.size.width, height: geometry.size.height)

            foregroundContent
                .padding(40)
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height,
                    alignment: .center
                )
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
    }
    .ignoresSafeArea()
}
```

- Keep helper extraction minimal. Extract `backgroundView` or `foregroundContent` only if it keeps the body readable; do not introduce a broad layout abstraction.
- The fix should make image crop independent from foreground centering.
- Avoid `.position(...)` or hardcoded `.offset(...)` because they are display-specific and likely to break the external monitor that already works.

## Post-Completion

*Items requiring manual intervention or external systems - no checkboxes, informational only.*

**Manual verification:**

- Build and run `build/Mahu.app` locally.
- Temporarily set short config durations in `~/Library/Application Support/Mahu/config.json`.
- On the built-in MacBook display, wait for the break overlay and confirm `Время отвлечься`, countdown, and `Skip` are horizontally and vertically centered in the visible overlay.
- With the external monitor connected, confirm the same foreground centering remains correct there.
- Confirm the background fills each overlay and may crop without shifting the foreground content.
- Press `Skip` and confirm the break ends normally.
- If available, test with a fullscreen Space because overlay positioning remains AppKit/manual-validation-sensitive.

**External/release follow-up:**

- If SwiftUI-only sizing does not fix the MacBook display, create a separate plan for explicit `NSHostingView` frame/autoresizing behavior instead of expanding this plan in-place.
