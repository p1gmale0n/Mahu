# Settings Window Integration

## Overview

Integrate the designed SwiftUI settings window from `source-assets/SettingsView.swift`, using `source-assets/settings.png` as the visual reference, into the Mahu macOS menu-bar app.

The shipped behavior should provide a real Settings window opened from the status-item menu. Settings changes apply immediately through Mahu's existing in-process runtime settings source of truth and persist immediately to `~/Library/Application Support/Mahu/config.json` as strict JSON. Save failures must be non-fatal and visible in the Settings UI.

This changes Settings UI from a deferred feature into shipped scope while preserving the existing manual config file as the persistence/backward-compatibility layer.

## Context (from discovery)

- Files/components involved:
  - `source-assets/SettingsView.swift` — existing SwiftUI design source.
  - `source-assets/settings.png` — visual reference for the settings window.
  - `Mahu/AppConfig.swift` — canonical settings schema.
  - `Mahu/ConfigStore.swift` — JSONC-tolerant load and strict JSON save.
  - `Mahu/AppCoordinatorSupport.swift` — `RuntimeSettingsStoring` and `RuntimeSettingsStore`.
  - `Mahu/AppCoordinator.swift` — applies runtime settings, launch-at-login desired-state changes, timer resets, status timer visibility, and idle-away behavior.
  - `Mahu/AppDelegate.swift` — production composition root for coordinator startup.
  - `Mahu/MahuApp.swift` — currently keeps an empty Settings scene and removes the standard app settings command.
  - `Mahu/StatusItemController.swift` — owns `NSStatusItem` and current menu actions.
  - `Mahu/BreakOverlaySupport.swift` — existing AppKit-owned `NSWindow` + SwiftUI hosting pattern.
  - `Mahu.xcodeproj/project.pbxproj` — new Swift source/test files must be manually added to target build phases.
  - Relevant tests under `MahuTests/`: runtime settings, config persistence, launch-at-login runtime sync, status-item menu, and status-item behavior tests.
- Related patterns found:
  - AppKit side effects are kept at edges; SwiftUI is used inside hosted views.
  - `RuntimeSettingsStore` is already the authoritative in-process source for settings changes.
  - `ConfigStore.save(_:)` returns `Bool` and logs non-fatal failures instead of throwing.
  - Launch at Login is represented as desired state; actual macOS registration can still be blocked by signing, approval, or Background Task Management state.
- Dependencies identified:
  - The Settings UI must not use `@AppStorage`/UserDefaults because that would create a second source of truth.
  - The status menu needs a `Settings…` item and a retained presenter/window controller.
  - `StatusItemController.swift` is already over the local 300-line readability signal, so menu changes should include a small extraction rather than simply growing the file.

## Development Approach

- **Testing approach**: Regular — implement each focused slice, then add/update tests in the same task before moving on.
- Use **Option A: AppKit-owned window + SwiftUI content**.
- Complete each task fully before moving to the next.
- Make small, focused changes.
- Every task that changes code must include new/updated tests for the code paths changed in that task.
- All tests must pass before starting the next task.
- Update this plan file when scope changes during implementation.
- Maintain backward compatibility with manual `config.json` edits and existing launch-loaded config behavior.
- Keep `config.json` saves strict JSON; do not add live config file watching.
- Keep `source-assets/settings.png` as a design reference, not a runtime app asset, unless implementation discovers a concrete runtime need.

## Testing Strategy

- Unit tests are required for view-model mapping, validation, persistence failure handling, status-menu action wiring, and window presenter lifecycle.
- Existing runtime/settings/coordinator tests should continue to prove applied runtime changes.
- UI behavior that depends on real macOS menu-bar/window behavior remains manual-only after automated tests pass.
- No project e2e framework is currently present; do not add one for this feature.

## Progress Tracking

- Mark completed items with `[x]` immediately when done.
- Add newly discovered tasks with ➕ prefix.
- Document issues/blockers with ⚠️ prefix.
- Update plan if implementation deviates from original scope.
- Keep plan in sync with actual work done.

## What Goes Where

- **Implementation Steps** checkboxes are for codebase-achievable work: code, tests, project membership, docs, and validation commands.
- **Post-Completion** has no checkboxes and is for manual UI/signing/Login Item verification.
- Checkboxes belong only in Task sections. Do not add checkboxes in Success criteria, Overview, Context, or Post-Completion.

## Implementation Steps

### Task 1: Add Settings view-model and persistence seam

- [x] create `Mahu/SettingsViewModel.swift` as a `@MainActor` observable model backed by `RuntimeSettingsStoring`
- [x] map `AppConfig` fields to UI units used by the source design: work minutes, break seconds, idle-away minutes, menu timer, launch-at-login desired state, and overlay message
- [x] implement one immediate apply path that updates `RuntimeSettingsStore` first, then calls an injected config-save closure based on `ConfigStore.save(_:)`
- [x] preserve non-fatal save failure state for display in the Settings UI without rolling back runtime settings
- [x] write `MahuTests/SettingsViewModelTests.swift` for initial mapping, valid updates, unit conversions, normalized empty overlay message, and no-op duplicate updates
- [x] write tests for save failure behavior and unsupported-value rejection/normalization boundaries
- [x] add new source and test files to `Mahu.xcodeproj/project.pbxproj`
- [x] run focused Settings view-model tests - must pass before Task 2

### Task 2: Adapt the designed SwiftUI Settings view

- [x] add `Mahu/SettingsView.swift` adapted from `source-assets/SettingsView.swift` with the same visual structure and labels from the design
- [x] remove all `@AppStorage` usage and bind the view to `SettingsViewModel` state/actions
- [x] initial integration shipped Launch at Login as a desired-state toggle; superseded by the 2026-06-10 polish pass, which keeps the Settings row read-only while still reflecting runtime/config desired state
- [x] show non-fatal config save warnings from the view model without blocking further edits
- [x] add SwiftUI preview/test-only initializer using default or mock settings without touching disk
- [x] write tests for Settings view-model/view-facing state needed by the UI, including footer/warning state inputs
- [x] add `SettingsView.swift` to the app target in `Mahu.xcodeproj/project.pbxproj`
- [x] run focused Settings UI/model tests - must pass before Task 3

### Task 3: Add AppKit settings window presenter

- [x] create `Mahu/SettingsWindowController.swift` that owns and reuses one `NSWindow` titled `Mahu Settings`
- [x] host `SettingsView` via `NSHostingView` or `NSHostingController`, following the existing overlay AppKit/SwiftUI boundary pattern
- [x] implement `showSettingsWindow()` to bring the window forward without creating duplicate windows
- [x] keep the presenter independent from `AppCoordinator` timer logic
- [x] write `MahuTests/SettingsWindowControllerTests.swift` for window reuse, title, hosted content creation, and repeated show behavior
- [x] add new source and test files to `Mahu.xcodeproj/project.pbxproj`
- [x] run focused window presenter tests - must pass before Task 4

### Task 4: Wire Settings into the status-item menu without growing menu complexity

- [x] extract status-menu construction/action state from `StatusItemController.swift` into a small focused helper file before adding new menu behavior
- [x] add a `Settings…` status-menu item between pause/resume and quit, with a handler injected from the app composition root
- [x] preserve existing Pause/Resume and Quit behavior, key equivalents, enabled states, icon/timer rendering, and paused visual behavior
- [x] update `StatusItemControlling` and tests as needed to configure the Settings action without coupling `StatusItemController` to settings persistence
- [x] update existing status-item menu tests whose exact item lists change
- [x] write tests that selecting `Settings…` invokes the injected settings-window handler exactly once
- [x] add any new helper/test files to `Mahu.xcodeproj/project.pbxproj`
- [x] run focused status-item tests - must pass before Task 5

### Task 5: Compose shared settings dependencies at app startup

- [x] update `AppDelegate` to create one `ConfigStore`, load startup config once, and create one shared `RuntimeSettingsStore(initialSettings:)`
- [x] inject the shared runtime store into `AppCoordinator` so the coordinator and Settings UI use the same in-process source of truth
- [x] create and retain a `SettingsWindowController` using the shared runtime store and `ConfigStore.save(_:)`
- [x] create/configure `StatusItemController` with the Settings window handler and pass it into `AppCoordinator`
- [x] keep `MahuApp.swift`'s standard Settings scene disabled for now; the menu-bar status item is the primary Settings entry point for this `LSUIElement` app
- [x] write/update AppDelegate or composition tests to prove startup uses shared runtime settings where practical without launching production UI during hosted tests
- [x] run focused app-startup/composition tests - must pass before Task 6

### Task 6: Verify runtime behavior integration

- [x] verify duration changes still follow existing runtime policy: active work restarts on work-duration changes, break-duration changes apply at the next break/rest boundary as currently defined
- [x] verify show-menu-timer changes update the status item through existing `AppCoordinator` runtime settings observation
- [x] verify idle-away enabled/threshold changes update runtime behavior without adding config file watching
- [x] verify launch-at-login desired-state changes still trigger the existing runtime sync path, while keeping signing/approval failures non-fatal warnings
- [x] verify break overlay message changes apply to future break presentations without mutating an already visible overlay
- [x] update or add focused coordinator/runtime tests only where existing coverage does not already prove the Settings-driven path
- [x] run focused runtime settings and launch-at-login runtime tests - must pass before Task 7

### Task 7: Update documentation and decision history

- [x] update `README.md` to document the Settings window, status-menu entry, immediate runtime application, strict JSON persistence, and save-failure caveat
- [x] update `AGENTS.md` to remove Settings UI from Deferred Features and record the shipped Settings UI invariants
- [x] update `docs/decisions.md` with the Settings UI architecture decision if not already present
- [x] keep Launch at Login documentation explicit that the toggle is desired state and real registration still requires a suitable signed app/macOS approval
- [x] run docs diff review and ensure wording does not imply live config reload or guaranteed Login Item registration on unsigned builds

### Task 8: Final validation

- [x] run full unit test suite with `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run build with `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run `make build`
- [x] run `git diff --check`
- [x] inspect `git status --short --branch --untracked-files=all` and confirm only intended files changed
- [x] verify all implementation-plan checkboxes are complete before handoff

## Technical Details

- Settings model mapping:
  - `workDurationSeconds` ↔ work duration Stepper in minutes, range `1...180`.
  - `breakDurationSeconds` ↔ break duration Stepper in seconds, range `5...600`, step `5` per source design.
  - `showStatusItemTimerState` ↔ `Show timer in menu bar` toggle.
  - `launchAtLoginEnabled` ↔ `Launch at login` desired-state setting, shown as a read-only row in the polished shipped Settings window.
  - `idleAwayResetEnabled` ↔ `Also reset timer when inactive for` toggle.
  - `idleAwayResetThresholdSeconds` ↔ idle threshold Stepper in minutes, range `1...240`.
  - `breakOverlayMessageText` ↔ text field, normalized through `AppConfig.normalizedBreakOverlayMessageText(_:)`.
- Persistence flow:
  - UI edit updates `SettingsViewModel`.
  - `SettingsViewModel` creates a new `AppConfig`.
  - `RuntimeSettingsStore.update(_:)` is called first.
  - `ConfigStore.save(_:)` is called immediately after runtime update.
  - If save fails, keep runtime settings and expose warning state in the Settings UI.
- Window flow:
  - Status menu invokes injected settings handler.
  - `SettingsWindowController` shows/reuses one AppKit `NSWindow` containing SwiftUI `SettingsView`.
  - `AppCoordinator` remains focused on timer/status/overlay lifecycle.
- Launch at Login flow:
  - Initial integration changed `launchAtLoginEnabled` from Settings UI; superseded by the 2026-06-10 polish pass, where the Settings row became read-only and runtime desired-state changes now come from config/programmatic updates.
  - Existing `AppCoordinator` runtime observer propagates changes through `LaunchAtLoginSettingsStore` and `LaunchAtLoginController`.
  - UI/docs must not claim registration success on unsigned, ad-hoc, or self-signed local builds.

## Post-Completion

*Items requiring manual intervention or external systems - no checkboxes, informational only.*

**Manual verification:**

- Open Mahu from a local build and confirm the status menu contains `Settings…`, Pause/Resume, and Quit.
- Open Settings from the menu and compare layout against `source-assets/settings.png`.
- Change work duration during active work and confirm the runtime timer behavior matches existing policy.
- Change break duration and confirm it applies at the expected next break/rest boundary.
- Toggle menu-bar timer state and confirm tray text appears/disappears without icon drift.
- Change break overlay message, wait for a new break, and confirm the new message appears.
- Toggle idle-away reset and threshold, then manually verify away behavior if practical.
- Toggle Launch at Login only on a properly Apple-signed app; unsigned/self-signed builds may still report unavailable.

**External follow-up:**

- If Apple Personal Team signing is restored later, repeat Launch at Login manual verification with a signed app and unique bundle identifier.
- Consider a follow-up plan if users want standard `Cmd+,` Settings scene support in addition to the status-menu entry.
