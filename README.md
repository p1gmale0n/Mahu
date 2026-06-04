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
- Status item defaults to icon-only with a menu containing `Pause Reminders` / `Resume Reminders` and `Quit`; optional config can switch it to the same icon plus `MM:SS` timer text or `Paused`.
- The status item icon uses bundled app artwork through the tray-optimized `TrayIconTemplate` asset: a transparent, glyph-only template silhouette derived from the app icon motif, with a copied/resized compiled app icon as a runtime fallback if the tray asset cannot be loaded.
- Work timer starts automatically on launch.
- Choosing `Pause Reminders` disables automatic work-timer progress during the work phase and prevents new break overlays from starting until reminders are resumed.
- While reminders are paused, Mahu keeps the same tray icon asset but visually dims the status item icon until reminders are resumed.
- Choosing `Resume Reminders` re-enables reminders and starts a fresh full work interval from the config that Mahu loaded on launch instead of resuming a partially elapsed one.
- If reminders are paused or resumed during an active break, Mahu only changes future reminder state and menu labels; the current break countdown and `Skip` behavior continue unchanged.
- Pause state is runtime-only; Mahu always launches with reminders enabled.
- Default schedule is 20 minutes of work and 20 seconds of break.
- Timers advance only while the Mac is awake; elapsed sleep time is not reconciled yet, so the current interval resumes after wake.
- Config is loaded from `~/Library/Application Support/Mahu/config.json`.
- Missing config creates a default config file and continues running.
- Invalid JSON or unsupported config durations, including values below 1 second, values that exceed one-second `TimeInterval` precision, or non-finite values, fall back to defaults and continue running.
- Break overlay explicitly loads bundled `background.png` from the app bundle, applies a dark readability treatment, shows a config-backed message that defaults to `Время отвлечься`, displays a countdown, and includes `Skip`.
- `Skip` closes the current break overlay and immediately starts the next work interval.
- Break overlay opens one borderless fullscreen window per active display.
- If Mahu starts a break while no active displays are available, it retries presentation without consuming break time; if an active break temporarily loses every display, Mahu closes the hidden overlay windows, preserves the same countdown/`Skip` state, and resumes the break without consuming rest time once a display returns.
- Overlay windows are raised above normal apps and the app is activated when the break starts.
- While a break is active, display additions, removals, and display-frame changes resync overlay windows without restarting the break or replacing the shared countdown/`Skip` state.
- While a break is active, Mahu best-effort reasserts its own focus and re-shows existing overlay windows if another app becomes active behind the overlay.
- When a break ends or `Skip` is pressed, Mahu restores the previously frontmost app when possible.
- When a visible break ends naturally, Mahu plays bundled `break-completion.caf` once through an AVFoundation-backed player so the user can return attention without watching the screen.
- Pressing `Skip` closes the break without playing the completion sound.
- Live config reload is out of scope; runtime settings changes still require editing the config file before launch or between runs.

## Project Structure

- `Mahu/`: app sources, including `AppCoordinator.swift` for orchestration flow and `AppCoordinatorSupport.swift` for coordinator-facing support declarations.
- `Mahu/Assets.xcassets/`: app asset catalog, including the macOS `AppIcon` generated from `icon.png`.
- `Mahu/Assets.xcassets/TrayIconTemplate.imageset/`: tray-optimized transparent template glyph artwork derived from the same source motif as the app icon.
- `Mahu/Resources/`: bundled app resources, including `background.png` for the overlay and `break-completion.caf` for natural break completion.
- `source-assets/`: source/staging artwork and audio assets used to produce bundled app resources.
- `Mahu/PrivacyInfo.xcprivacy`: privacy manifest for required-reason APIs used by the app target.
- `MahuTests/`: unit tests for config, timer, coordinator, status item, and overlay logic.
- `Mahu.xcodeproj/`: Xcode project and shared scheme.
- `Makefile`: local build shortcut that creates `build/Mahu.app`.
- `docs/decisions.md`: architectural and process decisions.
- `docs/plans/`: active implementation plans that are still in progress.
- `docs/plans/completed/`: archived completed implementation plans, including MVP, overlay refinements, tray icon work, reminder pause/resume, paused-icon, break-completion sound, and app-coordinator support refactor history.

## Configuration

Config path:
`~/Library/Application Support/Mahu/config.json`

Example:

```json
{
  "workDurationSeconds": 1200,
  "breakDurationSeconds": 20,
  "showStatusItemTimerState": false,
  "breakOverlayMessageText": "Время отвлечься"
}
```

Notes:

- `1200` seconds = 20 minutes.
- `showStatusItemTimerState` defaults to `false`; set it to `true` to show the tray icon plus active work/rest `MM:SS`, with `Paused` shown while reminders are paused.
- `breakOverlayMessageText` defaults to `Время отвлечься`; omit it to keep backward-compatible behavior, or set it to any non-empty Unicode string to change the break title.
- Empty or whitespace-only `breakOverlayMessageText` values normalize back to the default title, while `null` or non-string values make Mahu fall back to the full default config like other malformed config edits.
- Config durations must be finite values from 1 second up to 9,007,199,254,740,992 seconds; zero, negative, subsecond, larger, or non-finite values are treated as invalid and fall back to defaults so the timer keeps one-second precision.
- Mahu reads `config.json` only when the configured path is a regular file or a symlink resolving to one. Directories, pipes, broken symlinks, unreadable targets, and files larger than 64 KiB are ignored, and Mahu falls back to the default schedule.
- Use shorter values locally if you want to manually exercise the overlay flow faster.

## Setup

- Open the project in Xcode: `open "Mahu.xcodeproj"`
- Requires the full Xcode developer directory with the macOS SDK. If `xcodebuild` points to CommandLineTools or fails before parsing the project, switch to the Xcode developer directory and run `xcodebuild -runFirstLaunch` once.

## Verification Commands

Build local app artifact:

```sh
make build
```

This creates `build/Mahu.app` and keeps Xcode intermediate files under `build/DerivedData`.
It also fails if the built or copied app bundle is missing `background.png` or `break-completion.caf`.

Raw Xcode build:

```sh
xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO
```

Test:

```sh
xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO
```

The shared `Mahu` test scheme sets `MAHU_DISABLE_APP_COORDINATOR_STARTUP=1`. If you run hosted XCTest outside that shared scheme, set the same environment variable to avoid launching the production coordinator during tests.

## Deferred Features

- Launch at login.
- Settings UI.
- Manual start-break menu action.
- Sleep/wake timer reconciliation.
- App Store sandbox, entitlements, signing, notarization, and release workflow.
- Multi-display and fullscreen Spaces hardening.

## Manual Checks

- Confirm the app has no Dock icon.
- With default or missing `showStatusItemTimerState`, confirm the status item stays icon-only and initially shows `Pause Reminders` plus `Quit`.
- With `"showStatusItemTimerState": true`, confirm the menu bar shows the same tray icon plus `MM:SS` during work and break countdowns.
- With `"showStatusItemTimerState": true`, confirm native `NSStatusItem` width, truncation, and spacing remain acceptable in live menu-bar rendering; XCTest verifies controller state but not the real system layout.
- Choose `Pause Reminders`, then confirm the menu changes to `Resume Reminders`, the tray icon visibly dims without looking disabled, and no break overlay appears once the previously running work interval would have elapsed.
- With `"showStatusItemTimerState": true`, choose `Pause Reminders` and confirm the status item shows `Paused` while keeping the same dimmed tray icon.
- Choose `Resume Reminders`, then confirm the tray icon returns to normal brightness and the next break appears only after a full fresh work interval from the config loaded when Mahu launched.
- With `"showStatusItemTimerState": true`, choose `Resume Reminders` and confirm the status item returns to a fresh full work-interval countdown.
- During an active break, toggle `Pause Reminders` and `Resume Reminders`, then confirm the existing countdown and `Skip` behavior stay unchanged.
- Confirm `Quit` still exits the app.
- Confirm the status item visually uses the transparent tray glyph rather than the old SF Symbol or a visible square app-icon raster.
- Check the tray icon in light mode, dark mode, and the highlighted menu-bar state; this readability proof is still manual-only. If the tray asset is unavailable during local debugging, confirm Mahu still shows a non-empty fallback icon.
- Temporarily shorten config durations and confirm the overlay appears.
- With the default or missing `breakOverlayMessageText`, confirm `Время отвлечься`, the countdown, and `Skip` stay horizontally and vertically centered on the built-in display.
- With a custom Unicode `breakOverlayMessageText` such as `休憩しましょう — отдохни 🌿`, confirm the overlay renders that exact text and keeps the title, countdown, and `Skip` readable.
- With an empty or whitespace-only `breakOverlayMessageText`, confirm the overlay falls back to `Время отвлечься` while keeping the title, countdown, and `Skip` centered.
- Confirm the overlay background comes from the bundled `background.png`, not a repository-root or user-supplied file.
- If an external display is available, confirm background cropping does not shift the foreground controls there either.
- Press `Cmd+Tab` during an active break and confirm Mahu quickly returns to the front.
- Type immediately after attempting `Cmd+Tab` only to characterize the current bounce-back timing; the public-API approach does not guarantee that zero keystrokes leak before Mahu reactivates.
- Let a break end naturally and also press `Skip`, then confirm focus returns to the app that was frontmost before Mahu activated the overlay.
- Start a break on the built-in display, then connect an external monitor and confirm an overlay appears on the new display without restarting the break.
- Start a break with an external monitor connected, then disconnect it and confirm stale overlay windows close while the remaining display keeps the same countdown and `Skip` state.
- Change display resolution or scaling during an active break and confirm overlay windows resync.
- Start a break with a custom `breakOverlayMessageText`, then connect, disconnect, or resize a display and confirm the same custom title persists with the same countdown and `Skip` state.
- Trigger a transient display or fullscreen-Space transition during a break and confirm Mahu keeps the break active across empty-display snapshots; note any cases where AppKit still hides the overlay despite active displays.
- Test with a fullscreen app or Space and document any limitations separately.
- Let a break end naturally and confirm the bundled `break-completion.caf` completion sound plays once.
- Start another break, press `Skip`, and confirm no completion sound plays.
- Confirm pause/resume reminder toggles do not play the completion sound.
- Confirm the app still completes/restores focus normally when system audio output is muted or unavailable.

## UI References

- [Intermission - Breaks for eyes](https://apps.apple.com/us/app/intermission-breaks-for-eyes/id1439431081?mt=12)
- [Lumo - Eye strain 20-20-20](https://apps.apple.com/dz/app/lumo-eye-strain-20-20-20/id6758925986)

Use these as inspiration for minimalism and basic break-reminder behavior, not as complete feature parity requirements.

## Documentation Maintenance

- Keep this README current when app behavior, project structure, setup steps, or verification commands change.
- If this README conflicts with executable project files, trust the executable source and update the README in the same change.
