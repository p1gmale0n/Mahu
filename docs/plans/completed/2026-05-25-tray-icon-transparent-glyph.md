# Tray Icon Transparent Glyph

## Overview

- Fix the current macOS menu-bar tray/status icon visual issue where `TrayIconTemplate` appears as a visible square background in the menu bar.
- Replace the opaque tray PNGs with transparent-background, glyph-only template artwork derived from the same source artwork as the app icon.
- Preserve the shipped status item contract: menu-bar-only app, icon-only status item, `TrayIconTemplate` preferred over app-icon fallback, and a menu containing only `Quit`.
- Allow a thin outline/contour only if needed to keep the glyph readable at 18 pt; do not use a filled square, rounded square, or circular badge as the default solution.

## Context (from discovery)

- Files/components involved:
  - `Mahu/Assets.xcassets/TrayIconTemplate.imageset/tray-icon-template.png` — current 18x18 1x tray asset.
  - `Mahu/Assets.xcassets/TrayIconTemplate.imageset/tray-icon-template@2x.png` — current 36x36 2x tray asset.
  - `Mahu/Assets.xcassets/TrayIconTemplate.imageset/Contents.json` — asset metadata for the tray image set.
  - `icon.png` — source artwork used for the app icon and previous tray asset generation.
  - `MahuTests/StatusItemControllerTests.swift` or a new focused asset-test file — current status item tests verify loading, 18x18 size, template flag, provider preference, fallback, and menu behavior.
  - `Mahu/StatusItemController.swift` — already loads `TrayIconTemplate`, resizes/copies images to 18x18, enforces `isTemplate = true`, and keeps the status item icon-only.
  - `README.md` — documents the tray icon behavior and manual checks.
  - `docs/decisions.md` — records tray icon asset/fallback decisions and should capture the transparent-mask refinement.
- Related patterns found:
  - AppKit status-item responsibility remains in `StatusItemController`; this visual bug is asset-focused, so avoid moving behavior into `AppCoordinator`.
  - Existing plan `docs/plans/completed/2026-05-22-tray-icon-template-asset.md` already says unclear tray artwork should be refined rather than replaced with the full color app icon.
  - `ralphex` is installed at `/opt/homebrew/bin/ralphex`.
- Dependencies identified:
  - AppKit template rendering uses the image mask/alpha; fully opaque pixels become visible as a filled shape.
  - The current tray PNGs are `18x18` and `36x36`, but exploration found their alpha is fully opaque, including corners.
  - `xcodebuild test`, `xcodebuild build`, and `make build` are the required automated verification commands.

## Development Approach

- **Testing approach**: TDD — first add an asset regression test that fails on the current opaque-square PNGs, then regenerate the assets to pass it.
- Chosen approach: transparent glyph-only tray icon with optional thin outline/contour for 18 pt readability.
- Keep the scope asset-focused: do not change `StatusItemController.swift` unless implementation evidence shows the existing status-item contract is insufficient.
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
- Maintain backward compatibility: no Dock icon, no new status menu entries, no remaining-time status text, no pause/resume/manual break actions.

## Testing Strategy

- **Unit/asset tests**: required before asset regeneration.
- Add deterministic regression coverage for the source PNGs in `TrayIconTemplate.imageset`:
  - both `tray-icon-template.png` and `tray-icon-template@2x.png` exist.
  - sizes remain `18x18` and `36x36`.
  - corner/background pixels are transparent enough to avoid a square mask.
  - the image still contains non-transparent glyph pixels.
  - the asset has a meaningful mix of transparent and non-transparent pixels.
- Keep existing `StatusItemControllerTests` passing:
  - status item remains icon-only.
  - menu remains `Quit` only.
  - `TrayIconTemplate` still loads.
  - provider preference and app-icon fallback stay intact.
- **E2E tests**: none exist. Do not introduce UI automation for this visual polish. Use manual menu-bar verification in Post-Completion.

## Progress Tracking

- Mark completed items with `[x]` immediately when done.
- Add newly discovered tasks with ➕ prefix.
- Document issues/blockers with ⚠️ prefix.
- Update plan if implementation deviates from original scope.
- Keep plan in sync with actual work done.

## What Goes Where

- **Implementation Steps** (`[ ]` checkboxes): tasks achievable within this codebase - asset tests, asset regeneration, validation, documentation updates.
- **Post-Completion**: items requiring manual action - real menu-bar visual checks in light/dark/highlight/high-contrast appearances and on available displays.
- **Checkbox placement**: Checkboxes belong only in Task sections. Do not put checkboxes in Success criteria, Overview, or Context.

## Implementation Steps

### Task 1: Add tray asset transparency regression test
- [x] add a focused test in `MahuTests/StatusItemControllerTests.swift` or a new `TrayIconAssetTests.swift` that locates `Mahu/Assets.xcassets/TrayIconTemplate.imageset/tray-icon-template.png` and `tray-icon-template@2x.png`
- [x] assert the 1x asset is exactly `18x18` and the 2x asset is exactly `36x36`
- [x] assert the asset corners/background are transparent rather than fully opaque, so template rendering cannot produce a filled square
- [x] assert each asset still contains non-transparent glyph pixels and is not an empty transparent image
- [x] run `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` and confirm the new test fails on the current opaque assets before moving to Task 2

### Task 2: Regenerate `TrayIconTemplate` as transparent glyph artwork
- [x] regenerate `Mahu/Assets.xcassets/TrayIconTemplate.imageset/tray-icon-template.png` from `icon.png` as a transparent-background glyph at `18x18`
- [x] regenerate `Mahu/Assets.xcassets/TrayIconTemplate.imageset/tray-icon-template@2x.png` from `icon.png` as the matching transparent-background glyph at `36x36`
- [x] preserve `Mahu/Assets.xcassets/TrayIconTemplate.imageset/Contents.json` unless filenames or scales intentionally change
- [x] use a simple monochrome/template-friendly glyph; add only a thin outline/contour if needed for readability, and avoid filled square, rounded-square, or circular badge backgrounds
- [x] run `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` - must pass before next task

### Task 3: Verify status item contract remains unchanged
- [x] verify `Mahu/StatusItemController.swift` still prefers `TrayIconTemplate` and preserves app-icon fallback
- [x] verify `Mahu/StatusItemController.swift` still copies/resizes the loaded image to `18x18` and sets `isTemplate = true`
- [x] verify the status item remains icon-only and its menu still contains only `Quit`
- [x] verify `LSUIElement = true` remains unchanged in `Mahu/Info.plist`
- [x] run `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` - must pass before next task

### Task 4: Verify acceptance criteria
- [x] verify `TrayIconTemplate` PNGs have transparent corners/background and non-empty glyph pixels
- [x] verify no old opaque-square tray PNG remains in `Mahu/Assets.xcassets/TrayIconTemplate.imageset/`
- [x] run full unit test suite with `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run raw app build with `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run local artifact build with `make build`

### Task 5: Update documentation and decision record
- [x] update `docs/decisions.md` with the decision that `TrayIconTemplate` must be a transparent-background template mask/glyph, not an opaque scaled app-icon raster
- [x] update `README.md` if needed to clarify the tray icon is transparent glyph artwork and that visual readability remains manual-only
- [x] update this plan if implementation discovers a better asset-generation constraint or if a thin outline is required for readability
- [x] run the documented verification commands one final time if docs changed after validation

## Technical Details

- Target asset names:
  - `Mahu/Assets.xcassets/TrayIconTemplate.imageset/tray-icon-template.png`
  - `Mahu/Assets.xcassets/TrayIconTemplate.imageset/tray-icon-template@2x.png`
- Target dimensions:
  - 1x: `18x18` pixels.
  - 2x: `36x36` pixels.
- Required alpha behavior:
  - corners should be transparent, not opaque.
  - background should be transparent enough that the menu bar does not render a visible square.
  - glyph pixels should remain non-transparent so AppKit can tint the template image.
- Asset-generation guidance:
  - Use root `icon.png` as source artwork, but simplify/crop to the recognisable glyph shape rather than scaling the full app icon rectangle.
  - If automated mask extraction from `icon.png` produces an empty or unreadable tray asset at 18 pt, prefer a directly drawn simplified silhouette that preserves the same motif over reintroducing an opaque raster background.
  - Do not preserve the app icon's square background in the tray asset.
  - Prefer a single readable silhouette; use a thin outline only if the glyph disappears at 18 pt.
- Existing code path to preserve:
  - `StatusItemController.makeDefaultStatusIcon()` tries `TrayIconTemplate` first.
  - The fallback is a copied/resized compiled app icon.
  - Both paths return an explicit `18x18` template image copy.
- Known unrelated workspace artifact:
  - `images/` has appeared as untracked in prior checks; do not modify or rely on it unless the user explicitly brings it into scope.

## Success Criteria

- `TrayIconTemplate` no longer appears as a filled square in the menu bar.
- `tray-icon-template.png` and `tray-icon-template@2x.png` have transparent corners/background.
- The glyph remains visible and template/tint-friendly at status-item size.
- Status item remains icon-only.
- Menu contains only `Quit`, shortcut `q` is preserved, and `Quit` still terminates the app.
- App icon fallback path remains intact.
- Unit/asset tests prove dimensions and transparency/mask properties.
- `xcodebuild test`, `xcodebuild build`, and `make build` pass.
- `docs/decisions.md` and `README.md` are updated if the asset contract is clarified.

## Post-Completion

*Items requiring manual intervention or external systems - no checkboxes, informational only.*

**Manual verification:**
- Launch `build/Mahu.app` and confirm the status item appears in the menu bar.
- Confirm the status item visually no longer has a square background.
- Confirm the tray icon remains recognisable and not too thin or blurry at menu-bar size.
- Confirm the app has no Dock icon.
- Confirm the menu contains only `Quit` and `Quit` exits the app.
- Check the tray icon in light mode, dark mode, highlighted/open-menu state, high contrast / increased contrast if available, and on Retina and non-Retina displays if available.
- If the transparent glyph is still too detailed or unclear, refine the glyph shape/outline rather than reintroducing an opaque background.

**External/release follow-up:**
- Revisit final tray icon polish during signing/notarization/App Store release preparation.
- If future status countdown features are added, verify they do not crowd or visually compete with the icon.
