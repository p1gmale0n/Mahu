# Mahu

Mahu is a native macOS break-reminder app. After a work timer expires, it shows a fullscreen break overlay above working windows so the user steps away from the screen.

## Status

- Project is in the bootstrap stage.
- There is no Xcode project, Swift package, app source, CI, or verified build/test command yet.
- Add exact setup, build, test, and release commands here as soon as the project manifest exists.

## Target Stack

- macOS only.
- Swift with SwiftUI and AppKit.
- Prefer a standard modern Xcode macOS app target with SwiftUI app lifecycle and AppKit interop where needed.
- Menu-bar app with no Dock icon: `LSUIElement = true`.

## Core Behavior

- The app is controlled through a menu-bar status item.
- Default schedule follows the 20-20-20 rule: 20 minutes of work, then a 20-second break.
- MVP status item is only an icon with a menu containing `Quit`.
- When a break starts, create a borderless fullscreen `NSWindow` on every active display.
- Overlay windows should sit above normal apps, for example with `NSWindow.Level.screenSaver`.
- The app should call `makeKeyAndOrderFront(nil)` and `NSApp.activate(ignoringOtherApps: true)` to take focus.
- Do not add system-level keyboard or mouse capture unless the product requirement changes.
- The break screen should be dark and minimal, with a short message like `Время отвлечься` and a countdown until rest ends.
- The break screen should include a `Skip` button.
- MVP settings should be edited through a simple config file, not a settings UI.
- Keep timer, config, status item, and overlay responsibilities separated so sleep/wake handling, settings UI, launch at login, and status countdown can be added later without rewriting the core timer flow.
- Design with possible App Store release in mind: avoid private APIs and avoid behavior that depends on invasive keyboard or mouse capture.

## MVP Scope

- Menu-bar-only app with `LSUIElement = true`.
- Status item icon with `Quit` menu action.
- Config-file-driven work/rest durations with 20-20-20 defaults.
- Work timer that starts automatically when the app launches.
- Fullscreen break overlay on all active displays.
- Dark minimal break UI with message, countdown, and `Skip`.

## Configuration

- Store the MVP config in the standard macOS application support location: `~/Library/Application Support/Mahu/config.json`.
- If the config file is missing, create it with 20-20-20 defaults.
- If the config file is invalid, fall back to 20-20-20 defaults and keep the app running.
- Config values should be small and explicit: work duration and break duration in seconds.

## Deferred Features

- Launch at login.
- Settings UI for work/rest durations and presets.
- Remaining-time display in the status item.
- Pause/resume and manual `Start Break Now` menu actions.
- Sleep/wake handling with correct timer reconciliation after macOS suspend.
- App Store packaging details: sandbox, entitlements, signing, notarization, and release workflow.
- Hardening behavior with multiple displays, fullscreen Spaces, Mission Control, and display hot-plugging.
- Notifications or optional pre-break warning.

## UI References

- [Intermission - Breaks for eyes](https://apps.apple.com/us/app/intermission-breaks-for-eyes/id1439431081?mt=12)
- [Lumo - Eye strain 20-20-20](https://apps.apple.com/dz/app/lumo-eye-strain-20-20-20/id6758925986)

Use these as inspiration for minimalism and basic break-reminder behavior, not as complete feature parity requirements.

## Documentation Maintenance

- Keep this README current when app behavior, project structure, setup steps, or verification commands change.
- If this README conflicts with executable project files, trust the executable source and update the README in the same change.
