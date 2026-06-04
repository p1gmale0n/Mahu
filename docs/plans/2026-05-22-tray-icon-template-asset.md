# Tray Icon Template Asset

## Overview

- Replace Mahu's current SF Symbol status-item icon with a tray-optimized template icon derived from the same source artwork used for the app icon.
- Keep the MVP status item behavior unchanged: menu-bar-only app, icon-only status item, and a menu containing only `Quit`.
- Use a separate compact template asset for the menu bar because the full color app icon can become unreadable at 16-18 pt in light, dark, highlighted, or high-contrast menu bar states.
- Keep a runtime fallback to the compiled app icon if the tray asset cannot be loaded, so the app does not launch with an empty status item.

## Context (from discovery)

- Files/components involved:
  - `Mahu/StatusItemController.swift` — owns `NSStatusItem`; currently uses `NSImage(systemSymbolName: "figure.walk.circle", accessibilityDescription: "Mahu")` and sets `isTemplate = true`.
  - `MahuTests/StatusItemControllerTests.swift` — currently verifies icon-only status item behavior and `Quit` menu wiring.
  - `Mahu/Assets.xcassets/` — already compiled into the app target resources and currently contains `AppIcon.appiconset` generated from root `icon.png`.
  - `Mahu.xcodeproj/project.pbxproj` — already includes `Assets.xcassets` in the app resources and declares `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`.
  - `README.md` — documents current behavior, project structure, and manual checks.
  - `docs/decisions.md` — records the app icon asset-catalog decision and must receive the tray-icon decision.
- Related patterns found:
  - AppKit side effects stay at the edges; `StatusItemController` owns status-item UI details.
  - Existing tests inject `NSStatusItem` and application termination behavior to avoid launching a real app flow.
  - App icon artwork is source-controlled through generated asset catalog files, not runtime-generated assets.
- Dependencies identified:
  - AppKit `NSStatusItem`, `NSStatusBarButton.image`, `NSImage(named:)`, and `NSImage.isTemplate`.
  - XCTest hosted app bundle behavior for loading app resources and asset catalog images.
  - Existing `make build`, `xcodebuild build`, and `xcodebuild test` verification commands.
- External AppKit guidance:
  - Use `statusItem.button?.image`, not deprecated `NSStatusItem.image`.
  - Prefer `NSStatusItem.squareLength` for icon-only status items.
  - Menu-bar icons should generally be compact template images around 16-18 pt.
  - Full color app icons are usually too detailed for the menu bar and may fail contrast across menu bar states.
- Tooling:
  - `ralphex` is installed at `/opt/homebrew/bin/ralphex`.

## Development Approach

- **Testing approach**: TDD — write or update focused tests first in each code task, then implement the smallest code/assets needed to make those tests pass.
- Chosen approach: create a separate tray-optimized template asset from the existing `icon.png` source artwork and make `StatusItemController` prefer it over the app icon.
- Keep the implementation minimal: a small image-provider seam is acceptable for testability; avoid moving status-item responsibilities into `AppCoordinator`.
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
- Run tests after each task.
- Maintain backward compatibility: no Dock icon, no new status menu entries, no remaining-time status text, no pause/resume/manual break actions.

## Testing Strategy

- **Unit tests**: required for every task that adds or changes code.
- **Status item tests**:
  - preserve icon-only behavior: empty title, `.imageOnly`, one `Quit` menu item, shortcut `q`.
  - verify `StatusItemController` installs an image supplied by the status-icon provider.
  - verify the default provider prefers the tray template asset when available.
  - verify fallback behavior returns a resized app-icon-backed image if the tray asset is unavailable.
- **Asset smoke tests**:
  - verify the tray asset exists in the hosted app bundle / asset catalog context.
  - verify the tray image is treated as a template image and is sized for the menu bar.
- **E2E tests**: none exist. Do not introduce a UI automation framework for this small menu-bar change. Use manual verification in Post-Completion.

## Progress Tracking

- Mark completed items with `[x]` immediately when done.
- Add newly discovered tasks with ➕ prefix.
- Document issues/blockers with ⚠️ prefix.
- Update plan if implementation deviates from original scope.
- Keep plan in sync with actual work done.

## What Goes Where

- **Implementation Steps** (unchecked task checkboxes): tasks achievable within this codebase - code changes, generated assets, tests, documentation updates.
- **Post-Completion**: items requiring manual action - visual menu-bar checks in light/dark/high-contrast appearances and real app launch checks.
- **Checkbox placement**: Checkboxes belong only in Task sections. Do not put checkboxes in Success criteria, Overview, or Context.

## Implementation Steps

### Task 1: Add testable status-icon provider seam
- [x] update `MahuTests/StatusItemControllerTests.swift` to first assert `StatusItemController` installs the exact image returned by an injected status-icon provider
- [x] update the existing icon-only status item test to preserve `title == ""`, `.imageOnly`, one `Quit` item, and shortcut `q`
- [x] update `Mahu/StatusItemController.swift` with a minimal injected `statusIconProvider: () -> NSImage?` defaulting to the production provider
- [x] keep `StatusItemController` as the owner of status-item image setup; do not move this responsibility into `AppCoordinator`
- [x] run `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` - must pass before next task

### Task 2: Add tray template asset generated from existing artwork
- [x] add a focused test in `MahuTests/StatusItemControllerTests.swift` or a small companion test file proving the production provider can load a tray template asset
- [x] generate a compact monochrome/template-friendly tray icon from root `icon.png` using the same visual source as `AppIcon`
- [x] store the tray icon under `Mahu/Assets.xcassets/` as a named image set, for example `TrayIconTemplate.imageset`, with asset metadata committed to source control
- [x] ensure the asset is template/tintable in code via `isTemplate = true` even if the asset name also ends with `Template`
- [x] run `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` - must pass before next task

### Task 3: Prefer tray asset with app icon fallback
- [x] write or update tests for the production provider selection order: tray template asset first, app icon fallback second
- [x] implement production provider logic in `Mahu/StatusItemController.swift` or a small focused helper owned by the status-item layer
- [x] resize/copy the loaded image to a menu-bar-friendly size, around 18x18 pt, without mutating shared `NSImage` cache instances directly
- [x] preserve fallback to the compiled app icon if the tray asset cannot be loaded; the fallback may be less visually ideal but must prevent an empty status item
- [x] run `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` - must pass before next task

### Task 4: Verify acceptance criteria
- [x] verify `Mahu/StatusItemController.swift` no longer uses `NSImage(systemSymbolName: "figure.walk.circle", accessibilityDescription: "Mahu")`
- [x] verify the status item remains icon-only and its menu still contains only `Quit`
- [x] verify `LSUIElement = true` remains unchanged in `Mahu/Info.plist`
- [x] run full unit test suite with `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run raw app build with `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run local artifact build with `make build`

### Task 5: Update documentation and decision record
- [x] update `README.md` to mention that the icon-only status item uses bundled app artwork via a tray-optimized template asset if this user-visible behavior should be documented
- [x] update `docs/decisions.md` with the decision to use a separate tray template asset derived from the same source artwork, plus the app icon fallback rationale
- [x] update this plan if implementation discovers a better asset name, size, or fallback behavior
- [x] run the documented verification commands one final time if docs changed after validation

## Technical Details

- Suggested asset name: `TrayIconTemplate`.
- Suggested asset location: `Mahu/Assets.xcassets/TrayIconTemplate.imageset/`.
- Suggested status icon size: `NSSize(width: 18, height: 18)`; keep this local to the status-icon provider so it can be adjusted without touching coordinator logic.
- Suggested provider shape:
  - `StatusItemController` receives `statusIconProvider: () -> NSImage?` for tests.
  - Production provider tries `NSImage(named: "TrayIconTemplate")` first.
  - If missing, production provider falls back to `NSImage(named: NSImage.applicationIconName)` or `NSApp.applicationIconImage`.
  - The provider should copy the image before setting `size` or `isTemplate`, because `NSImage(named:)` may return a cached shared instance.
- Template behavior:
  - Primary tray asset: `isTemplate = true`.
  - Fallback app icon: resize it and keep behavior explicit. The current implementation keeps the fallback as an 18x18 template copy too, so the status item never switches back to a color icon at runtime.
- Do not add new menu items, status text, launch-at-login behavior, settings UI, pause/resume, or manual start-break actions.

## Success Criteria

- Status item no longer uses the SF Symbol `figure.walk.circle`.
- Status item uses a tray-optimized template asset derived from the same source artwork as the app icon.
- If the tray asset cannot be loaded, the app falls back to the compiled app icon instead of showing an empty status item.
- Status item remains icon-only.
- Menu contains only `Quit`, shortcut `q` is preserved, and `Quit` still terminates the app.
- `LSUIElement = true` remains unchanged; the app still has no Dock icon.
- Unit tests are updated and pass.
- `xcodebuild test`, `xcodebuild build`, and `make build` pass.
- `README.md` and `docs/decisions.md` reflect the new tray icon decision if the implementation changes user-visible behavior.

## Post-Completion

*Items requiring manual intervention or external systems - no checkboxes, informational only.*

**Manual verification:**
- Launch `build/Mahu.app` and confirm the status item appears in the menu bar.
- Confirm the status item visually uses the new tray artwork rather than the old SF Symbol.
- Confirm the app has no Dock icon.
- Confirm the menu contains only `Quit` and `Quit` exits the app.
- Check the tray icon in light mode, dark mode, highlighted menu state, high contrast / increased contrast if available, and on Retina and non-Retina displays if available.
- If the icon is too detailed or unclear at menu-bar size, refine the template asset shape rather than switching back to the full color app icon.

**External/release follow-up:**
- Revisit final tray icon polish during signing/notarization/App Store release preparation.
- If future settings or status countdown features are added, ensure they do not make the status item visually crowded.
