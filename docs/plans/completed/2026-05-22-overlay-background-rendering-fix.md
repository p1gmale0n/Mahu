# Overlay Background Rendering Fix

## Status

- Implementation changes and automated validation are complete in the repo as of 2026-05-22.
- Manual runtime visual verification of the live overlay is still pending and remains listed under Post-Completion.

## Overview

- Fix the runtime break overlay background so the bundled `background.png` visibly renders in the live app.
- Preserve the existing break overlay behavior: `Время отвлечься`, countdown, `Skip`, focus retention, multi-display windows, and timer flow must remain unchanged.
- Keep the current raw bundled resource strategy. Do not introduce an asset catalog for this bug fix.
- Add automated proof for explicit image loading and fallback behavior, while keeping final visual confirmation as a manual check.

## Context (from discovery)

- Files/components involved: `Mahu/BreakOverlayView.swift`, `MahuTests/SmokeTests.swift`, `MahuTests/BreakOverlayViewTests.swift`, possible new focused test file under `MahuTests/`, `Mahu.xcodeproj/project.pbxproj`, `Makefile`, `README.md`, `docs/decisions.md`, and `docs/plans/completed/2026-05-21-overlay-background.md`.
- Related patterns found: overlay UI lives in `BreakOverlayView`; window creation and focus behavior live in `BreakOverlayManager` and should not change for this fix.
- Dependencies identified: raw app bundle resource lookup, AppKit `NSImage`, SwiftUI `Image(nsImage:)`, XCTest, and existing `xcodebuild`/`make build` verification commands.
- Current evidence: `background.png` is already present in app resources and decodable from `Bundle.main`, but runtime overlay still does not show it.
- Likely cause: `Image("background")` is an implicit named-image lookup that is unreliable for a raw bundled PNG on macOS when the image is not in an asset catalog.
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
- Maintain backward compatibility with the current app bundle shape and existing user-visible overlay behavior.
- Keep AppKit side effects at the edges: do not change `BreakOverlayManager` unless explicit rendering work proves it is required.

## Testing Strategy

- **Unit tests**: required for every task that changes code or project wiring.
- **Loader tests**: verify successful `background.png` lookup/decoding and missing-resource fallback behavior.
- **Overlay tests**: preserve existing checks for title, countdown, and `Skip`; add coverage for the view using the explicit loader seam if practical without brittle pixel/snapshot tests.
- **Build verification**: run documented `xcodebuild` test/build commands and `make build`.
- **E2E tests**: none exist. Do not introduce UI automation for this visual bug fix; final rendered-pixel proof remains manual.

## Progress Tracking

- Mark completed items with `[x]` immediately when done.
- Add newly discovered tasks with ➕ prefix.
- Document issues/blockers with ⚠️ prefix.
- Update plan if implementation deviates from original scope.
- Keep plan in sync with actual work done.

## What Goes Where

- **Implementation Steps**: unchecked task items for code changes, tests, documentation updates, and deterministic validation commands achievable inside this codebase.
- **Post-Completion** (no checkboxes): manual visual checks, real external-display checks, and fullscreen Space verification.
- **Checkbox placement**: Checkboxes belong only in Task sections (`### Task N:` or `### Iteration N:`). Do not put checkboxes in Success criteria, Overview, or Context because they cause extra loop iterations.

## Implementation Steps

### Task 1: Make overlay background loading explicit
- [x] add a small image-loading seam in `Mahu/BreakOverlayView.swift` or a focused new source file that resolves `background.png` from an injected `Bundle`
- [x] decode the resolved resource with `NSImage(contentsOf:)` and expose an optional image result for the overlay
- [x] update `BreakOverlayView` to render the loaded image with `Image(nsImage:)`, `.resizable()`, `.scaledToFill()`, and `.ignoresSafeArea()` when loading succeeds
- [x] preserve a dark fallback background when image loading fails so the overlay remains readable and does not crash
- [x] keep the existing dark readability layer above the image and keep title/countdown/`Skip` behavior unchanged
- [x] write tests for successful hosted app bundle image loading
- [x] write tests for missing-resource fallback behavior using an injected empty or temporary bundle path
- [x] run `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` - must pass before next task

### Task 2: Verify overlay behavior stays unchanged
- [x] update `MahuTests/BreakOverlayViewTests.swift` only as needed to account for the new loader seam without making tests brittle
- [x] verify the view still exposes `Время отвлечься`, formatted countdown text, and `Skip`
- [x] verify the view can be constructed when the background image is unavailable
- [x] avoid pixel/snapshot tests unless the project already has a stable snapshot testing framework
- [x] run `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` - must pass before next task

### Task 3: Verify packaging and build commands
- [x] inspect `Mahu.xcodeproj/project.pbxproj` only if tests/builds show `background.png` is no longer copied as a resource (skipped - not needed; builds kept copying the resource)
- [x] run `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run `make build`
- [x] verify `build/Mahu.app/Contents/Resources/background.png` still exists after `make build`
- [x] document any packaging issue in this plan before changing project wiring (skipped - no packaging issue observed; project wiring unchanged)

### Task 4: Update documentation and decision history
- [x] update `docs/decisions.md` with the final implementation decision if the code changes from implicit `Image("background")` lookup to explicit bundle loading
- [x] update `README.md` only if behavior, setup, verification commands, or resource strategy wording changes
- [x] update this plan with final validation notes and any manual checks completed

Validation notes after Task 4:

- `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` passed after the explicit bundle-loading implementation and documentation updates.
- `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` passed with the existing raw bundled resource wiring unchanged.
- `make build` passed and still produced `build/Mahu.app` with `Contents/Resources/background.png` present.
- Manual runtime pixel verification was not completed in this environment and remains listed under Post-Completion.

### Task 5: Verify acceptance criteria
- [x] verify the overlay uses bundled `background.png` rather than the repository root or user filesystem
- [x] verify missing or undecodable background image does not crash the overlay
- [x] verify title, countdown, `Skip`, focus retention, multi-display window creation, and timer flow remain unchanged
- [x] run full unit test suite with `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run final app build with `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run `make build`

*Note: manual runtime visual verification belongs in Post-Completion because this environment cannot prove live rendered pixels in the overlay window.*

Validation notes after Task 5:

- `SmokeTests.testHostedAppBundleBackgroundImageLivesInsideBundleResources()` now proves the runtime resource resolves from `Bundle.main` instead of an incidental repository path.
- Missing-resource safety remains covered by `BreakOverlayViewTests.testBackgroundImageLoaderReturnsNilWhenResourceMissing()` and `testBreakOverlayViewCanBeConstructedWhenBackgroundImageIsUnavailable()`.
- Existing automated acceptance coverage for unchanged behavior remains in `BreakOverlayViewTests`, `BreakOverlayManagerTests`, `BreakOverlayFocusRetentionTests`, and `AppCoordinatorTests`; live visual/external-display checks still remain manual under Post-Completion.
- `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` passed.
- `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` passed.
- `make build` passed and still produced `build/Mahu.app` with `Contents/Resources/background.png` present.

## Technical Details

- Preferred implementation shape:

```swift
import AppKit

struct BreakOverlayBackgroundImageLoader {
    let bundle: Bundle

    func loadBackgroundImage() -> NSImage? {
        guard let url = bundle.url(forResource: "background", withExtension: "png") else {
            return nil
        }

        return NSImage(contentsOf: url)
    }
}
```

- Preferred SwiftUI rendering shape:

```swift
if let image = backgroundImage {
    Image(nsImage: image)
        .resizable()
        .scaledToFill()
        .ignoresSafeArea()
} else {
    Color.black.ignoresSafeArea()
}

Color.black.opacity(0.48)
    .ignoresSafeArea()
```

- Keep any loader small and testable. Do not add a broad resource-management abstraction for one image.
- If `NSImage(contentsOf:)` succeeds but the runtime image still does not render, the next suspect is SwiftUI layout sizing. Add explicit `GeometryReader` sizing only if needed after the explicit-loader fix.
- `scaledToFill()` may crop on unusual aspect ratios. That is acceptable for fullscreen background art, but manual checks should cover at least one non-default display size if possible.

## Post-Completion

*Items requiring manual intervention or external systems - no checkboxes, informational only.*

**Manual verification:**

- Build and run `build/Mahu.app` locally.
- Temporarily set short config durations in `~/Library/Application Support/Mahu/config.json`.
- Wait for the break overlay and confirm the bundled background image visibly fills the overlay.
- Confirm `Время отвлечься`, countdown, and `Skip` remain readable over the image.
- Press `Skip` and confirm the break ends normally.
- If available, test with an external display and a fullscreen Space because those remain AppKit/manual-validation-sensitive.

**External/release follow-up:**

- Recheck app bundle size before release if the background image changes.
- If additional visual assets are added later, consider a separate plan to introduce an asset catalog intentionally.
