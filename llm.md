# Mahu coding-agent context

This file keeps the detailed implementation context, edge cases, and manual QA checklist that used to make `README.md` hard to read.

Use `README.md` for the user-facing product page, `DEVELOPMENT.md` for developer setup/configuration, and this file when planning or reviewing implementation work.

---

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
- Status item defaults to icon-only with a menu containing `Settings…`, `Pause Reminders` / `Resume Reminders`, and `Quit`; optional config can switch it to the same icon plus `MM:SS` timer text, with `Paused` shown only while reminders are paused during work, `Away` shown only while session-lock suppression or enabled idle-away suppression is active, and timer-mode width pinned to the widest observed title so the icon does not drift horizontally across countdown updates or `MM:SS -> Paused/Away -> MM:SS` transitions.
- The status item icon uses bundled app artwork through the tray-optimized `TrayIconTemplate` asset: a transparent, glyph-only template silhouette derived from the app icon motif, with a copied/resized compiled app icon as a runtime fallback if the tray asset cannot be loaded.
- Work timer starts automatically on launch.
- Choosing `Pause Reminders` disables automatic work-timer progress during the work phase and prevents new break overlays from starting until reminders are resumed.
- While reminders are paused, Mahu keeps the same tray icon asset but visually dims the status item icon until reminders are resumed.
- Choosing `Resume Reminders` re-enables reminders and starts a fresh full work interval from Mahu's current in-process runtime settings instead of resuming a partially elapsed one.
- If reminders are paused or resumed during an active break, Mahu only changes future reminder state and menu labels; the current break countdown and `Skip` behavior continue unchanged.
- Pause state is runtime-only; Mahu always launches with reminders enabled.
- Default schedule is 20 minutes of work and 20 seconds of break.
- Short sleep preserves the current work or break countdown, while wake after at least 5 minutes of recorded sleep reconciles state: active work resets to a fresh full work interval, paused reminders stay paused until resumed, and active breaks close silently into a fresh work interval without playing the completion sound.
- Ordinary screen lock is treated as an immediate away state independent of HID idle duration and independent of `idleAwayResetEnabled`: Mahu uses isolated best-effort distributed screen-lock notifications plus current-state/startup sampling to detect the common Lock Screen path, then applies the same away semantics of fresh-work reset for active work, silent active-break close, preserved paused state, and suppressed elapsed time/completion sounds until unlock.
- `NSWorkspace` session-active notifications remain part of the lifecycle model, but they represent user-session switching or similar session-active transitions rather than the whole ordinary Lock Screen path; when they do fire, they feed the same away/active reconciliation path as screen lock.
- While the Mac stays awake, idle-away reset is disabled by default. When `idleAwayResetEnabled` is `true`, user idle time below the configured threshold preserves the current work or break countdown, while idle time at or above `idleAwayResetThresholdSeconds` is treated as away/rest time with the same phase semantics as long sleep: active work resets to a fresh full work interval from current runtime settings, repeated ticks in the same away episode suppress elapsed consumption, optional tray-timer mode shows `Away` during that suppression, paused reminders stay paused until resumed, and active breaks close silently into a fresh work interval without playing the completion sound.
- Config is loaded from `~/Library/Application Support/Mahu/config.json`.
- `launchAtLoginEnabled` defaults to `false`; on launch Mahu seeds desired state from `config.json`, and runtime/config changes still flow through the same Launch at Login sync path. The Settings window now shows that desired state as a disabled read-only row rather than editing it directly. `true` requests main-app Login Item registration through `SMAppService.mainApp`, while `false` requests unregister/removal when the Login Item is currently enabled or pending approval and otherwise no-ops. If macOS still requires approval or registration/unregistration fails, Mahu logs a non-fatal warning and keeps running.
- Missing config creates a default config file and continues running.
- Invalid JSON or unsupported config durations, including values below 1 second, values that exceed one-second `TimeInterval` precision, or non-finite values, fall back to defaults and continue running.
- On load, `config.json` also tolerates JSONC-style `//` comments, `/* ... */` block comments, and trailing commas before `}` or `]`, but Mahu still writes strict JSON when it creates or saves config files.
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
- Mahu keeps a single in-process runtime settings source of truth initialized from launch-loaded config.
- Mahu ships a `Settings…` window opened from the status menu; committed edits apply to the shared runtime settings first and then persist immediately back to `config.json` as strict JSON.
- If `config.json` contains timer values outside the Settings UI ranges, the window shows the nearest supported values, warns that the underlying raw values stay active until you edit the affected control, and then saves that control back using the supported UI range and step.
- Config-save failures from the Settings window are non-fatal: after a committed Settings change is accepted into the shared runtime store, Mahu keeps the new in-app runtime settings active and shows a warning in the Settings UI instead of rolling the change back, but system-integrated settings such as Launch at Login may already have taken effect.
- If closing `Settings…` triggers a pending draft commit and `config.json` still cannot be saved, Mahu keeps the window open so the inline warning remains visible instead of silently closing.
- Live config reload is out of scope; editing `config.json` while Mahu is running does not change timers or UI until the next launch.

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
- `docs/plans/`: current implementation plans, including in-progress work and any just-completed plan that is still being reviewed at its original path.
- `docs/plans/completed/`: archived completed implementation plans once their close-out review loop is finished, including MVP, overlay refinements, tray icon work, reminder pause/resume, paused-icon, break-completion sound, and app-coordinator support refactor history.

## Configuration

Config path:
`~/Library/Application Support/Mahu/config.json`

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

Manual-edit example with tolerated JSONC-style syntax on load:

```jsonc
{
  "workDurationSeconds": 1200,
  "breakDurationSeconds": 20,
  // Enable menu-bar countdown text.
  "showStatusItemTimerState": true,
  // Opt into idle-away reset with a custom threshold.
  "idleAwayResetEnabled": true,
  "idleAwayResetThresholdSeconds": 180,
}
```

Notes:

- `1200` seconds = 20 minutes.
- `showStatusItemTimerState` defaults to `false`; set it to `true` to show the tray icon plus active work/rest `MM:SS`. If reminders are paused during work, the title changes to `Paused`; if screen-lock/session-away suppression or enabled idle-away suppression is active, the title changes to `Away`; if pause happens during an active break, Mahu keeps the live break countdown visible while dimming the icon and changing the menu item to `Resume Reminders`. Timer mode keeps the widest observed title width so the icon does not drift horizontally across countdown changes or `MM:SS -> Paused/Away -> MM:SS` transitions, and `Away` is intentionally bounded so it does not require more width than `Paused`.
- `idleAwayResetEnabled` defaults to `false`; leave it missing or set it to `false` to preserve normal timer behavior even after long idle periods while the Mac stays awake.
- Screen-lock suppression is always on and does not add a config key; ordinary Lock Screen uses an isolated best-effort observer for distributed lock/unlock notifications plus current-state/startup sampling, while `NSWorkspace` session active/inactive notifications remain the session-switch path and HID idle duration remains reserved for the optional idle-away feature.
- `idleAwayResetThresholdSeconds` defaults to `300`; set it to any positive finite number of seconds if you enable idle-away reset and want a threshold other than 5 minutes. Mahu evaluates the threshold on its normal 1-second timer tick, so subsecond values still take effect on the next tick after the idle duration crosses the configured value.
- `breakOverlayMessageText` defaults to `Время отвлечься`; omit it to keep backward-compatible behavior, or set it to any non-empty Unicode string that still allows the full strict-JSON config file to stay within the supported 64 KiB limit.
- `launchAtLoginEnabled` defaults to `false`; set it in `config.json` to request Launch at Login for the main app on the next launch/runtime update, or leave/set it to `false` to request unregister/removal when a Login Item is currently present. The Settings window reflects this desired state but does not edit it directly.
- Empty or whitespace-only `breakOverlayMessageText` values normalize back to the default title, while `null` or non-string values make Mahu fall back to the full default config like other malformed config edits.
- Non-positive, `null`, non-numeric, or non-finite `idleAwayResetThresholdSeconds` values are treated as invalid and fall back to the safe default config behavior rather than creating a partial override.
- `config.json` is read at launch to seed Mahu's runtime settings and launch-at-login desired state. Editing the file while the app is already running does not apply changes immediately because Mahu intentionally has no file watcher or implicit reload loop; relaunch Mahu after manual config changes.
- Manual edits may include JSONC-style comments and trailing commas on read, but Mahu-created files and Settings-window saves remain strict JSON and remove those comments/trailing commas on write.
- The Settings window updates the shared in-process runtime settings source immediately; manual JSON edits remain the persistence/backward-compatibility layer, not a live control surface.
- In the Settings window, Work Duration, Break Duration, idle-away settings, and tray-timer visibility commit immediately when you change the control. Numeric draft text stays local while you type; on Return, focus loss, or window close, invalid text is discarded and the field snaps back to the last committed value, while valid text clamps or rounds into the supported range and step.
- `Break overlay message` uses a text-field draft and commits on Return, focus loss, or window close; once committed, it updates runtime/config immediately and affects only future break overlays. If a draft message would make the strict-JSON config exceed the supported size limit, Mahu keeps the previous saved message active and shows the warning inline instead.
- The Settings window edits work duration in whole minutes from `1...180`, break duration in 5-second steps from `5...600`, and idle-away threshold in whole minutes from `1...240`. If an existing config value sits outside those UI bounds or between the supported break-duration steps, the Settings window shows the nearest supported UI value for that control but preserves the raw config value until you edit that specific control; after you do, the saved value follows the supported UI range and step.
- Launch at Login in the Settings window is a read-only desired-state display: unsigned, ad-hoc, or otherwise unapproved builds may fail to register even when `config.json` requests it, and Mahu surfaces that as a non-fatal warning rather than guaranteed success.
- Config durations must be finite values from 1 second up to 9,007,199,254,740,992 seconds; zero, negative, subsecond, larger, or non-finite values are treated as invalid and fall back to defaults so the timer keeps one-second precision.
- Mahu reads `config.json` only when the managed `~/Library/Application Support/Mahu` path itself is a real directory and the configured `config.json` path is a regular file or a symlink resolving to one. Directories, pipes, broken symlinks, symlinked `Mahu` directories, unreadable targets, and files larger than 64 KiB are ignored, and Mahu falls back to the default schedule.
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

- Manual start-break menu action.
- App Store sandbox, entitlements, signing, notarization, and release workflow.
- Multi-display and fullscreen Spaces hardening.

## Manual Checks

- Confirm the app has no Dock icon.
- Confirm the status menu contains `Settings…`, `Pause Reminders` or `Resume Reminders`, and `Quit`.
- Open `Settings…` and confirm the window layout roughly matches `source-assets/settings.png` while using the shipped controls and copy.
- Open `Settings…` on a normal display and confirm the fixed-size window cannot be resized and already shows the full form without scrolling.
- Change a setting in the Settings window and confirm it applies immediately without relaunch.
- In `Settings…`, manually type Work Duration and Break Duration values, press Return or move focus away, and confirm the values commit, clamp, and round the same way as the stepper controls.
- In `Settings…`, type invalid numeric text such as letters into a timer or idle-away field, then press Return, move focus away, or close the window and confirm the field snaps back to the last committed value instead of persisting the invalid draft.
- In `Settings…`, confirm the Launch at Login row reflects the current desired state but is disabled/read-only and cannot be changed directly from the window.
- In `Settings…`, confirm the idle-away threshold stays visible at the far right immediately before the toggle even when idle-away reset is off, and that editing is disabled rather than hidden when the toggle is off.
- In `Settings…`, confirm the break overlay message field is obviously editable, shows the current saved value directly, and does not display the old English `Time to look away` placeholder.
- In `Settings…`, type a new break overlay message, press Return or close the window, and confirm the next break uses the new text while an already visible break keeps its current title.
- Force or simulate a config-save failure only if practical and confirm Mahu keeps the changed runtime behavior while the Settings window shows a non-fatal warning; if the failure happens during a close-triggered draft commit, confirm the window stays open so the warning remains visible, and if the same failure is triggered by `Quit` while Settings is miniaturized, confirm Mahu restores the window instead of silently exiting.
- With default or missing `showStatusItemTimerState`, confirm the status item stays icon-only.
- With `"showStatusItemTimerState": true`, confirm the menu bar shows the same tray icon plus `MM:SS` during work and break countdowns.
- With `"showStatusItemTimerState": true`, confirm native `NSStatusItem` width, truncation, and spacing remain acceptable in live menu-bar rendering, including countdown digit-boundary changes such as `100:00 -> 99:59` and work-phase `MM:SS -> Paused -> MM:SS` transitions; XCTest verifies controller state but not the real system layout.
- Choose `Pause Reminders`, then confirm the menu changes to `Resume Reminders`, the tray icon visibly dims without looking disabled, and no break overlay appears once the previously running work interval would have elapsed.
- With `"showStatusItemTimerState": true`, choose `Pause Reminders` during work and confirm the status item shows `Paused` while keeping the same dimmed tray icon.
- Choose `Resume Reminders`, then confirm the tray icon returns to normal brightness and the next break appears only after a full fresh work interval from Mahu's current runtime settings.
- With `"showStatusItemTimerState": true`, choose `Resume Reminders` and confirm the status item returns to a fresh full work-interval countdown.
- During an active break, toggle `Pause Reminders` and `Resume Reminders`, then confirm the existing countdown and `Skip` behavior stay unchanged, the status item keeps showing the live break `MM:SS` countdown, and the menu item still flips between `Pause Reminders` and `Resume Reminders`.
- Wait until the work timer is near expiration, sleep the Mac longer than 5 minutes, wake it, and confirm Mahu starts a fresh full work interval instead of showing an immediate break.
- Repeat with a sleep shorter than 5 minutes and confirm the current work or break countdown resumes from the previous remaining time.
- Pause reminders, sleep the Mac longer than 5 minutes, wake it, and confirm Mahu stays paused, does not show a break, and still starts a fresh full work interval only after `Resume Reminders`.
- Start an active break, sleep the Mac longer than 5 minutes, wake it, and confirm Mahu closes the stale break, starts a fresh work interval, and does not play `break-completion.caf`.
- Use Apple Menu -> Lock Screen before a near-expired work timer would reach a break and confirm Mahu does not show a break overlay or play `break-completion.caf` while the screen is locked.
- Repeat the same check with Control-Command-Q.
- If you can trigger a real user-session switch on the machine, confirm that path also enters the same away suppression behavior; ordinary Lock Screen should not depend on `NSWorkspace` session-switch notifications firing.
- Unlock and confirm Mahu returns from `Away` to a fresh full work countdown, or remains `Paused` if reminders were already paused before locking.
- Start an active break, lock the screen, and confirm Mahu closes the break silently into a fresh work interval with no completion sound on unlock.
- With `"showStatusItemTimerState": true`, confirm session-lock `Away` fits within the same tray footprint as `Paused` and does not move the tray icon.
- With missing config or `"idleAwayResetEnabled": false`, wait until the work timer is near expiration, stay idle longer than 5 minutes, and confirm Mahu still reaches the break overlay instead of freezing near `10s` or resetting silently.
- With `"idleAwayResetEnabled": true`, stay idle longer than `idleAwayResetThresholdSeconds` and confirm Mahu returns to a fresh full work interval instead of immediately showing a stale break.
- With `"idleAwayResetEnabled": true`, repeat the idle check with less than `idleAwayResetThresholdSeconds` of idle time and confirm Mahu preserves the current work or break countdown.
- With `"idleAwayResetEnabled": true` and `"showStatusItemTimerState": true`, confirm the status item shows `Away` only while elapsed time is being suppressed, then returns to the countdown after user activity.
- With `"idleAwayResetEnabled": true` and `"showStatusItemTimerState": true`, confirm `Away` fits within the same tray footprint as `Paused` and does not move the tray icon.
- Pause reminders, stay idle for more than 5 minutes without sleeping the Mac, and confirm Mahu stays paused, does not show a break, and still starts a fresh full work interval only after `Resume Reminders`.
- Start an active break, stay idle for more than 5 minutes without sleeping the Mac, and confirm Mahu closes the stale break silently and does not play `break-completion.caf`.
- Build or archive a properly signed local `.app`, set `"launchAtLoginEnabled": true`, relaunch Mahu, and confirm the app appears in System Settings -> General -> Login Items.
- Quit Mahu, log out/in or reboot, and confirm Mahu starts automatically as a menu-bar-only app with no Dock icon.
- Set `"launchAtLoginEnabled": false`, relaunch Mahu, and confirm the Login Item is removed or disabled in System Settings.
- If macOS shows a pending approval state for the Login Item, confirm Mahu keeps running normally and does not add a menu-bar control for resolving that state.
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
