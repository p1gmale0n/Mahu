# Project: Mahu

## What This App Is
- Native macOS break-reminder app: after a work timer expires, it shows a fullscreen break overlay above working windows.
- Target stack: Swift with SwiftUI/AppKit; macOS only.

## Current Repo State
- The repo now contains a checked-in Xcode macOS app project at `Mahu.xcodeproj`, app sources under `Mahu/`, unit tests under `MahuTests/`, and MVP implementation docs under `docs/`.
- Keep `README.md` current when app behavior, project structure, setup steps, or verification commands change.

## Development Workflow
- Default mode for this chat/repo is discussion and planning only; implementation is executed separately with `ralphex` (`https://github.com/umputun/ralphex`).
- Do not create, edit, or delete project files unless the user explicitly asks for repository changes in the current message.
- Prefer producing implementation plans, prompts/tasks for `ralphex`, reviews, and debugging guidance over directly coding.
- If the user explicitly asks for edits, keep changes minimal and still update `docs/decisions.md` for architectural/process decisions.

## Product Invariants
- Run as a menu-bar app with no Dock icon: set `LSUIElement = true` and control it through an `NSStatusItem`.
- Prefer a standard modern Xcode macOS app target with SwiftUI app lifecycle; use AppKit interop for status-item and overlay-window behavior.
- MVP default schedule is 20-20-20: 20 minutes of work, then a 20-second break.
- MVP status item defaults to icon-only with a menu containing `Pause Reminders` / `Resume Reminders` and `Quit`; optional config may show the same icon plus `MM:SS` for active work/rest timers, `Paused` while reminders are paused, or `Away` while session-lock suppression or enabled idle-away suppression is active.
- In optional tray timer mode, keep spacing between the icon and text readable and use stable-width digit presentation so the tray icon does not drift horizontally during countdown.
- `Away` must not require more tray text width than `Paused`; keep the controlled title slot bounded by the existing paused-state requirement.
- While reminders are paused, keep the same status icon asset but dim it visually without disabling the menu-bar control.
- When a break starts, create a borderless fullscreen `NSWindow` for every active display, not just the main display.
- While a break is active, display additions, removals, and display-frame changes must resync overlay windows without restarting the break, recapturing the previous app, or replacing the shared countdown/`Skip` state.
- Put overlay windows above normal apps, for example with `NSWindow.Level.screenSaver`.
- Bring the overlay app to the front with `makeKeyAndOrderFront(nil)` and `NSApp.activate(ignoringOtherApps: true)`.
- While a break is active, best-effort focus retention should re-show existing overlay windows and reactivate Mahu if another app becomes frontmost; do not escalate this into input capture without an explicit product change.
- Do not add system-level keyboard/mouse capture unless the product requirement changes; focus stealing plus high-level overlay is the intended behavior.
- Break screen should be dark and minimal, with a short config-backed message that defaults to `Время отвлечься`, a countdown until rest ends, and a `Skip` button.
- Break screen should use the bundled background image with a dark readability layer so title, countdown, and `Skip` remain legible across displays.
- Break screen foreground centering must be bounded by the actual overlay window size: keep `BreakOverlayView` using `GeometryReader` (or an equivalent explicit-size container) so `scaledToFill()` background imagery cannot expand layout and shift content on the built-in laptop display.
- When a visible break ends naturally, play bundled `break-completion.caf` once; pressing `Skip` must not play the completion sound.
- MVP settings should use a manually editable config file at `~/Library/Application Support/Mahu/config.json`; do not add a settings UI yet.
- Config reads should tolerate JSONC-style comments and trailing commas, while app-created or app-saved config files remain strict JSON.
- Treat launch-loaded `config.json` as the persistence/backward-compatibility layer and keep a single in-process runtime settings source of truth for coordinator and future Settings UI updates.
- `launchAtLoginEnabled` in launch-loaded `config.json` is the shipped desired-state control for Launch at Login; reconcile it once at startup through `SMAppService.mainApp`, treat approval/registration/unregistration problems as non-fatal warnings, request unregister/no-op when the desired state is `false`, and do not add a status-menu toggle before the future Settings UI.
- Live config reload remains out of scope; runtime settings changes should not be coupled to display hot-plug handling.
- Manual config edits still apply only on relaunch; do not add live config reload or file-watcher behavior.
- Short sleep/wake cycles must preserve the current work/rest phase and countdown while refreshing the awake-time baseline so sleep time is not consumed on the next tick.
- Long sleep/wake cycles of at least 300 seconds must reset active work to a fresh work interval from current runtime settings, keep paused reminders paused until resume, and close active breaks silently into fresh work without playing the completion sound.
- Session inactive/lock suppression is always-on through public `NSWorkspace` session active/inactive notifications: active work resets to fresh work, active rest closes silently into fresh work, paused reminders remain paused, locked time does not advance timers, and optional tray timer mode may show bounded `Away` during active suppression.
- Idle-away reset while macOS stays awake is config-gated: `idleAwayResetEnabled` defaults to `false`, `idleAwayResetThresholdSeconds` defaults to `300`, disabled mode must not query idle state or suppress elapsed time, and enabled mode uses the same phase semantics as long sleep while showing `Away` only during active suppression.
- If the config is missing or invalid, use 20-20-20 defaults and keep the app running.
- Keep timer, config, status item, and overlay responsibilities separated so deferred features can be added without rewriting the core timer flow.
- Treat possible App Store release as a constraint: avoid private APIs and invasive input capture.

## Deferred Features
- Settings UI.
- Manual start-break menu action.
- App Store sandbox, entitlements, signing, notarization, and release workflow.
- Multi-display/fullscreen Spaces hardening.

## UI References
- Use Intermission and Lumo as inspiration for minimalism and basic break-reminder behavior, not as complete feature parity requirements.

## Verification
- Verified local app build command: `make build` creates `build/Mahu.app` using repo-local `build/DerivedData`.
- Verified build command: `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- Verified test command: `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- Manual-only checks remain: no Dock icon, real menu-bar presence, active-break display hot-plug/resolution behavior on external displays, and fullscreen Space behavior.
- If `xcodebuild` points at `CommandLineTools` or fails before parsing the project, switch to the full Xcode developer directory and run `xcodebuild -runFirstLaunch` once before retrying.

## Implementation Gotchas
- Keep AppKit side effects at the edges: `AppCoordinator` wires flow, while `StatusItemController` and `BreakOverlayManager` own platform UI objects.
- Preserve config resilience: missing config should create defaults; malformed JSON or non-positive durations should fall back to defaults without aborting launch; unexpected filesystem failures should still log a reason before the app continues with defaults.
- `build/` is intentionally ignored; use `make build` when a local `.app` artifact is needed, but do not commit build products.
- Multi-display overlay behavior is automated only through abstraction-level tests in this environment; real display and Space behavior still requires manual validation.
- Focus retention is best-effort through public notifications only; it can bounce Mahu back after `Cmd+Tab`, but it cannot guarantee blocking system shortcuts or every fullscreen/Spaces transition.
- Do not simplify `BreakOverlayView` to a bare full-frame `ZStack` without explicit geometry bounds; that previously regressed foreground centering on the built-in display while external monitors still looked correct.
- The shared test scheme disables production coordinator startup with `MAHU_DISABLE_APP_COORDINATOR_STARTUP=1`; if hosted tests are run outside that scheme, set the same environment variable to avoid real menu-bar, timer, and config-file side effects.

## Decision History
- Write project decisions to `docs/decisions.md`; keep `AGENTS.md` as operational guidance, not a decision log.
