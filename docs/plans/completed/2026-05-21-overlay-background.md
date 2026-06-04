# Overlay Background Image

## Status

- Implementation changes are complete in the repo as of 2026-05-21.
- Review-driven verification hardening was added on 2026-05-22 so XCTest decodes the bundled image and `make build` fails if either app bundle omits `background.png`.
- The runtime-loading details in this historical plan were superseded by `docs/plans/completed/2026-05-22-overlay-background-rendering-fix.md`.
- Manual visual verification on real displays and fullscreen Spaces is still pending.

## Overview

- Add the repository root `background.png` as a bundled app resource and use it as the fullscreen background for Mahu's break overlay.
- Preserve the current break overlay interaction: `Время отвлечься`, countdown, and `Skip` remain visible and functional.
- Keep the visual language dark, minimal, and readable by placing a dark overlay/treatment above the image.
- Integrate the resource through the existing Xcode project so the image is available inside the built `.app`, including `build/Mahu.app` produced by `make build`.

## Context (from discovery)

- Files/components involved: root `background.png`, `Mahu/BreakOverlayView.swift`, `MahuTests/BreakOverlayViewTests.swift`, `Mahu.xcodeproj/project.pbxproj`, `README.md`, `AGENTS.md`, and `docs/decisions.md`.
- Related patterns found: `BreakOverlayView` currently uses `Color.black.ignoresSafeArea()` as the background and tests required overlay text through `BreakOverlayViewTests`.
- Dependencies identified: SwiftUI `Image`, app bundle resources, Xcode `PBXResourcesBuildPhase`, XCTest bundle resource lookup.
- Asset state: no asset catalog exists today; `background.png` is an untracked root file and should be moved into app-owned resources.
- Worktree note: `config.json` is an unrelated untracked local config file; do not move, commit, or modify it as part of this feature.

## Development Approach

- **Testing approach**: Regular code first, then tests in each task before moving to the next task.
- Use Option A: raw bundle resource at `Mahu/Resources/background.png` with `Image("background")` in SwiftUI.
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
- Preserve current MVP behavior and focus-hardening behavior; this change should be visual/resource-only.
- Do not introduce external file-path loading for the background; the image must be bundled in the app.

## Testing Strategy

- **Unit tests**: required for every task that changes code or project resource wiring.
- **Bundle resource test**: verify the hosted app bundle resolves `background.png` and that the resource decodes as an image.
- **Overlay view tests**: keep existing checks for message, countdown, and `Skip` label; update them only if view structure changes require a more robust helper.
- **Build verification**: run both documented `xcodebuild` build/test commands and `make build` to prove the resource is copied into the local `.app` artifact.
- **E2E tests**: none exist. Do not introduce UI automation for this visual change; keep visual validation in Post-Completion.

## Progress Tracking

- Mark completed items with `[x]` immediately when done.
- Add newly discovered tasks with ➕ prefix.
- Document issues/blockers with ⚠️ prefix.
- Update plan if implementation deviates from original scope.
- Keep plan in sync with actual work done.

## What Goes Where

- **Implementation Steps** (unchecked task checkboxes): moving the image, Xcode project resource wiring, SwiftUI view update, tests, and documentation.
- **Post-Completion**: manual visual checks across display sizes, fullscreen Spaces, and release packaging review.
- **Checkbox placement**: Checkboxes belong only in Task sections. Do not put checkboxes in Success criteria, Overview, or Context.

## Implementation Steps

### Task 1: Move and bundle the background image
- [x] create `Mahu/Resources/` for app-owned non-code resources
- [x] move root `background.png` to `Mahu/Resources/background.png`
- [x] update `Mahu.xcodeproj/project.pbxproj` to include `background.png` in the `Mahu` target resources without adding it to sources
- [x] add a resource build phase if the app target does not already have one
- [x] write or update a test that verifies `background.png` resolves and decodes from the hosted app bundle
- [x] run tests - must pass before next task

### Task 2: Use the image in the break overlay view
- [x] update `Mahu/BreakOverlayView.swift` to render `Image("background")` as the fullscreen background
- [x] use `.resizable()`, `.scaledToFill()`, and `.ignoresSafeArea()` so the image covers the overlay window
- [x] add a dark overlay/treatment above the image to preserve text/countdown/button readability
- [x] keep the existing message, countdown, and `Skip` button behavior unchanged
- [x] update `MahuTests/BreakOverlayViewTests.swift` to keep coverage for required text and `Skip` label after the view change
- [x] run tests - must pass before next task

### Task 3: Verify resource packaging and app artifact
- [x] verify the image resource is present in the built app bundle after `xcodebuild build`
- [x] run full unit test suite with `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run final app build with `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run `make build`
- [x] verify `build/Mahu.app` contains `background.png` in its resources

### Task 4: Update documentation and project knowledge
- [x] update `README.md` current behavior to mention the break overlay uses a bundled background image with dark readability treatment
- [x] update `README.md` project structure if a new `Mahu/Resources/` directory is added
- [x] update `AGENTS.md` if future agents need to preserve the background-image readability rule
- [x] update `docs/decisions.md` if the final resource strategy differs from this plan (not needed - final implementation matches planned raw bundled resource strategy; documentation decision recorded)
- [x] update this plan with final validation notes and any manual visual checks completed

Validation notes:

- 2026-05-21: `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` rerun after Task 4 doc updates.
- 2026-05-21: `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` rerun after Task 4 doc updates.
- 2026-05-21: `make build` rerun after Task 4 doc updates.
- 2026-05-22: review follow-up hardened automated proof so XCTest decodes `background.png` from the hosted app bundle and `make build` fails if either the built or copied app bundle omits the resource.
- 2026-05-21: Manual visual checks from Post-Completion were not rerun in this headless environment.

## Technical Details

- Resource destination: `Mahu/Resources/background.png`.
- SwiftUI background shape:

```swift
Image("background")
    .resizable()
    .scaledToFill()
    .ignoresSafeArea()

Color.black.opacity(0.45)
    .ignoresSafeArea()
```

- The exact opacity can be adjusted during implementation, but the final overlay must keep white text and the `Skip` button readable.
- Prefer a raw bundle resource over `Assets.xcassets` for this one PNG because the project is currently hand-authored and has no asset catalog.
- Do not load the image from the repository root or user filesystem at runtime; it must work from the packaged `.app`.
- `scaledToFill()` may crop the image on non-16:9 displays. This is acceptable for fullscreen background art, but manual validation should check extreme aspect ratios.

## Post-Completion

*Items requiring manual intervention or external systems - no checkboxes, informational only.*

**Manual verification:**
- Build and run `build/Mahu.app` locally.
- Temporarily set short config durations and wait for the overlay.
- Confirm the background image fills the whole break overlay.
- Confirm title, countdown, and `Skip` remain readable against the image.
- Check at least one non-default display size or external display if available.
- Check fullscreen Space behavior if available, because overlay positioning remains AppKit/manual-validation sensitive.

**External/release follow-up:**
- Recheck app bundle size before release if the image is large.
- If more visual assets are added later, consider moving from raw bundle resources to an asset catalog in a separate plan.
