# Mahu

Mahu is a native macOS break-reminder app. It runs as a menu-bar-only app, starts a work timer on launch, and shows a fullscreen break overlay on every active display when it is time to step away from the screen.

## Status

- MVP app sources and tests exist.
- The project uses a checked-in Xcode macOS app project: `Mahu.xcodeproj`.
- Verified build and test commands are documented below.

## Tech Stack

- macOS only.
- Swift.
- SwiftUI for the app and overlay UI.
- AppKit interop for `NSStatusItem`, `NSWindow`, and app activation.
- XCTest for unit tests.

## System Requirements

- Requires macOS 14.0 or newer.

## Current Behavior

- Menu-bar-only app with `LSUIElement = true`.
- Icon-only status item with a menu containing `Quit`.
- Work timer starts automatically on launch.
- Default schedule is 20 minutes of work and 20 seconds of break.
- Timers advance only while the Mac is awake; elapsed sleep time is not reconciled yet, so the current interval resumes after wake.
- Config is loaded from `~/Library/Application Support/Mahu/config.json`.
- Missing config creates a default config file and continues running.
- Invalid JSON or unsupported config durations, including values below 1 second, fall back to defaults and continue running.
- Break overlay is dark and minimal, shows `Время отвлечься`, displays a countdown, and includes `Skip`.
- `Skip` closes the current break overlay and immediately starts the next work interval.
- Break overlay opens one borderless fullscreen window per active display.
- Overlay windows are raised above normal apps and the app is activated when the break starts.
- While a break is active, Mahu best-effort reasserts its own focus and re-shows existing overlay windows if another app becomes active behind the overlay.
- When a break ends or `Skip` is pressed, Mahu restores the previously frontmost app when possible.

## Project Structure

- `Mahu/`: app sources.
- `MahuTests/`: unit tests for config, timer, coordinator, status item, and overlay logic.
- `Mahu.xcodeproj/`: Xcode project and shared scheme.
- `Makefile`: local build shortcut that creates `build/Mahu.app`.
- `docs/decisions.md`: architectural and process decisions.
- `docs/plans/completed/2026-05-20-mahu-mvp.md`: completed MVP execution plan and checkbox progress.
- `docs/plans/2026-05-21-overlay-focus-hardening.md`: overlay focus-hardening implementation log; manual hardware verification remains open there.

## Configuration

Config path:
`~/Library/Application Support/Mahu/config.json`

Example:

```json
{
  "workDurationSeconds": 1200,
  "breakDurationSeconds": 20
}
```

Notes:

- `1200` seconds = 20 minutes.
- Config durations must be finite values of at least 1 second; zero, negative, or subsecond values are treated as invalid and fall back to defaults.
- Use shorter values locally if you want to manually exercise the overlay flow faster.

## Setup

- Open the project in Xcode: `open "Mahu.xcodeproj"`

## Verification Commands

Build local app artifact:

```sh
make build
```

This creates `build/Mahu.app` and keeps Xcode intermediate files under `build/DerivedData`.

Raw Xcode build:

```sh
xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO
```

Test:

```sh
xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO
```

## Deferred Features

- Launch at login.
- Settings UI.
- Remaining-time display in the status item.
- Pause/resume and manual start-break menu actions.
- Sleep/wake timer reconciliation.
- App Store sandbox, entitlements, signing, notarization, and release workflow.
- Multi-display and fullscreen Spaces hardening.

## Manual Checks

- Confirm the app has no Dock icon.
- Confirm the status item appears and `Quit` exits the app.
- Temporarily shorten config durations and confirm the overlay appears.
- Press `Cmd+Tab` during an active break and confirm Mahu quickly returns to the front.
- Type after attempting `Cmd+Tab` and confirm input does not reach a hidden app behind the overlay.
- Let a break end naturally and also press `Skip`, then confirm focus returns to the app that was frontmost before Mahu activated the overlay.
- Test with an external display if available.
- Test with a fullscreen app or Space and document any limitations separately.

## UI References

- [Intermission - Breaks for eyes](https://apps.apple.com/us/app/intermission-breaks-for-eyes/id1439431081?mt=12)
- [Lumo - Eye strain 20-20-20](https://apps.apple.com/dz/app/lumo-eye-strain-20-20-20/id6758925986)

Use these as inspiration for minimalism and basic break-reminder behavior, not as complete feature parity requirements.

## Documentation Maintenance

- Keep this README current when app behavior, project structure, setup steps, or verification commands change.
- If this README conflicts with executable project files, trust the executable source and update the README in the same change.
