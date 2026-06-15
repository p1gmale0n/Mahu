# Mahu development

This file contains developer-facing setup, configuration, verification, and project-structure notes for Mahu.

Use `README.md` for the user-facing product page. Use `llm.md` for exhaustive coding-agent context and manual QA details.

Mahu is a native macOS break-reminder app. It lives in the menu bar, runs a work timer, and shows a fullscreen break overlay when it is time to look away from the screen.

Default rhythm: **20 minutes of work → 20 seconds of break**.

## What it does

- Runs as a **menu-bar-only** app with no Dock icon.
- Shows a status menu with:
  - `Settings…`
  - `Pause Reminders` / `Resume Reminders`
  - `Quit`
- Shows a fullscreen break overlay on every active display.
- Lets you skip the current break.
- Plays a completion sound when a visible break ends naturally.
- Handles sleep, wake, screen lock, and optional idle-away suppression without consuming hidden timer time.
- Stores settings in a manually editable config file:

```text
~/Library/Application Support/Mahu/config.json
```

## Requirements

- macOS 14.0 or newer
- Full Xcode installation with macOS SDK

## Build and test

Build a local app bundle:

```sh
make build
```

This creates:

```text
build/Mahu.app
```

Run tests:

```sh
xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO
```

Raw Xcode build:

```sh
xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO
```

Open in Xcode:

```sh
open "Mahu.xcodeproj"
```

If `xcodebuild` points at CommandLineTools or fails before parsing the project, switch to the full Xcode developer directory and run `xcodebuild -runFirstLaunch` once.

## Configuration

Mahu creates a default config file on first launch if one does not exist.

Example:

```json
{
  "workDurationSeconds": 1200,
  "breakDurationSeconds": 20,
  "showStatusItemTimerState": false,
  "idleAwayResetEnabled": false,
  "idleAwayResetThresholdSeconds": 300,
  "breakOverlayMessageText": "Время отвлечься",
  "launchAtLoginEnabled": false
}
```

Useful fields:

| Field | Default | Meaning |
| --- | --- | --- |
| `workDurationSeconds` | `1200` | Work interval length. |
| `breakDurationSeconds` | `20` | Break interval length. |
| `showStatusItemTimerState` | `false` | Show `MM:SS`, `Paused`, or `Away` next to the tray icon. |
| `idleAwayResetEnabled` | `false` | Reset after long user idle time while macOS stays awake. |
| `idleAwayResetThresholdSeconds` | `300` | Idle threshold used when idle-away reset is enabled. |
| `breakOverlayMessageText` | `Время отвлечься` | Text shown on future break overlays. |
| `launchAtLoginEnabled` | `false` | Desired Launch at Login state. Actual registration can still require macOS approval/signing support. |

Manual edits may use JSONC-style comments and trailing commas when Mahu reads the file. Mahu-created and Settings-saved files are written back as strict JSON.

Config changes made while Mahu is already running are not live-reloaded. Relaunch Mahu after manual edits.

## Settings window

Open `Settings…` from the status menu.

The Settings window edits the shared in-process runtime settings first and then saves strict JSON back to `config.json`. If saving fails, Mahu keeps the accepted in-app runtime change active and shows a warning instead of crashing or silently rolling back.

The Launch at Login row is intentionally read-only: it reflects the desired state from config/runtime, but local unsigned builds may not be able to guarantee system registration.

## Project structure

```text
Mahu/                     App source files
Mahu/Resources/           Bundled background and completion sound
Mahu/Assets.xcassets/     App and tray icon assets
MahuTests/                XCTest suite
Mahu.xcodeproj/           Xcode project and shared scheme
source-assets/            Source/staging design assets
build/                    Local build output, ignored by git
docs/decisions.md         Architectural and process decisions
docs/plans/               Implementation plans and completed plan archive
DEVELOPMENT.md            Developer setup, config, and verification notes
llm.md                    Detailed coding-agent context and exhaustive manual QA checklist
```

## Manual smoke checks

After building/running the app, verify at least:

- The app has no Dock icon.
- The menu bar item appears and opens the expected menu.
- `Settings…` opens and changes apply without relaunch.
- Pause/resume changes the menu label and reminder behavior.
- A shortened timer shows the break overlay on all active displays.
- `Skip` closes the overlay without playing the completion sound.
- A naturally completed visible break plays `break-completion.caf` once.
- Lock/sleep/long-idle behavior does not trigger hidden stale overlays or sounds.

The complete coding-agent and manual QA checklist lives in [`llm.md`](llm.md).

## Documentation

- Keep `README.md` focused on user-facing product value and high-level status.
- Keep `DEVELOPMENT.md` focused on developer setup, configuration, project structure, and short verification notes.
- Put detailed implementation invariants, edge cases, and exhaustive manual checks in [`llm.md`](llm.md).
- If documentation conflicts with executable source, trust the source and update the docs in the same change.

## UI references

- [Intermission - Breaks for eyes](https://apps.apple.com/us/app/intermission-breaks-for-eyes/id1439431081?mt=12)
- [Lumo - Eye strain 20-20-20](https://apps.apple.com/dz/app/lumo-eye-strain-20-20-20/id6758925986)

These are inspiration for minimal break-reminder behavior, not feature-parity targets.
