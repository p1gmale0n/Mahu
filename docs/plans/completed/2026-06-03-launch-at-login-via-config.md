# Launch at Login via Config

## Status

Completed on 2026-06-03. Pending archive after external review.
This change set addresses Tasks 1-7 in this plan.
Post-review hardening already landed on top of the original tasks: runtime changes to `launchAtLoginEnabled` now resync through the dedicated store/controller seam, and config persistence now requires a direct `~/Library/Application Support/Mahu` directory path while still keeping launch-time reads compatible with a final-file `config.json` symlink.

## Overview

Add launch-at-login support for Mahu through the existing manually editable config-file workflow.

The feature solves the “set it and forget it” gap for a break-reminder utility: when the user opts in through `~/Library/Application Support/Mahu/config.json`, Mahu should register the main app as a macOS Login Item so reminders start automatically after the user logs in.

This plan intentionally does **not** add a status-menu item or Settings UI yet. It introduces a small launch-at-login settings layer that can later be reused by a Settings window without rewriting the ServiceManagement integration.

## Context (from discovery)

- Files/components involved:
  - `Mahu/AppConfig.swift` — config model and default/backward-compatible decoding.
  - `Mahu/ConfigStore.swift` — disk persistence for `config.json`.
  - `Mahu/AppCoordinator.swift` — startup orchestration; already large, so only minimal wiring belongs here.
  - `Mahu/AppCoordinatorSupport.swift` — runtime settings seams; near local size limit, avoid growing it with launch-at-login logic.
  - New focused launch-at-login files under `Mahu/` for settings store, policy/controller, and ServiceManagement adapter.
  - New focused tests under `MahuTests/`, instead of expanding already large coordinator/status-item test files.
  - `README.md`, `AGENTS.md`, `docs/decisions.md` for shipped behavior and architectural decision updates.
- Related patterns found:
  - Manual config is launch-loaded; live config reload remains out of scope.
  - Runtime settings are kept in-process for future UI work instead of repeatedly reading JSON.
  - AppKit/system side effects are kept at the edges behind small protocols/fakes.
  - `AppCoordinator` wires subsystems but should not contain platform-specific ServiceManagement logic.
- Dependencies identified:
  - Apple `ServiceManagement.framework`, specifically `SMAppService.mainApp` for macOS 13+ main-app launch-at-login support.
  - Mahu currently targets macOS 14, so `SMAppService.mainApp` is available.
  - Real Login Item behavior must be manually validated with a signed app bundle; `CODE_SIGNING_ALLOWED=NO` is sufficient only for tests/build parsing.
- External context:
  - `.tmp/external-context/apple-servicemanagement/launch-at-login-smappservice-macos14.md`
  - Official docs referenced there: `SMAppService`, `SMAppService.mainApp`, `register()`, and `status`.

## Development Approach

- **Testing approach**: TDD.
- Complete each task fully before moving to the next.
- Make small, focused changes.
- Every task that changes code must include new or updated tests in the same task.
- Tests are required for new functions, modified functions, success paths, and failure/edge paths.
- All relevant tests must pass before starting the next task.
- Update this plan file if scope changes during implementation.
- Maintain backward compatibility with older `config.json` files that do not include the new field.
- Keep launch-at-login UI out of scope until the Settings UI plan.

## Testing Strategy

- **Unit tests** are required for every task.
- Config tests must cover missing/default values, valid booleans, invalid types, encoding, and load/save round trips.
- Launch-at-login tests must use fakes; unit tests must not call real `SMAppService.mainApp`.
- Coordinator tests must prove startup sync is non-fatal when registration/unregistration fails.
- No UI-based E2E suite exists in this project; real Login Item behavior remains manual-only.

## Progress Tracking

- Mark completed implementation items with `[x]` immediately when done.
- Add newly discovered tasks with a `➕` prefix.
- Document issues/blockers with a `⚠️` prefix.
- Update this plan if implementation deviates from the original scope.
- Keep the plan in sync with actual work done.

## What Goes Where

- **Implementation Steps**: code changes, tests, project-file wiring, documentation updates, and deterministic verification commands.
- **Post-Completion**: manual Login Item checks, signed/notarized app checks, reboot/login validation, and Settings UI follow-up.
- **Checkbox placement**: checkboxes belong only in Task sections. Do not add checkboxes to Overview, Context, Technical Details, or Post-Completion.

## Implementation Steps

### Task 1: Extend the config contract for launch-at-login intent

- [x] write failing tests for `AppConfig` defaulting `launchAtLoginEnabled` to `false` when the field is missing
- [x] write failing tests for decoding valid `launchAtLoginEnabled` boolean values and rejecting invalid/null values through the existing whole-config fallback behavior
- [x] add `launchAtLoginEnabled: Bool` to `AppConfig` with default `false` and backward-compatible decoding/encoding
- [x] write or update `ConfigStore` persistence tests proving save/load round-trip preserves `launchAtLoginEnabled`
- [x] run targeted config tests - must pass before Task 2

### Task 2: Add a dedicated launch-at-login desired-state store

- [x] write failing tests for a new `LaunchAtLoginSettingsStore` initialized from config-backed desired state
- [x] write failing tests for store updates, no-op repeated updates, and observer/callback behavior needed by future Settings UI
- [x] implement `LaunchAtLoginSettingsStoring` and `LaunchAtLoginSettingsStore` in a focused new source file, keeping it filesystem-free
- [x] ensure the store represents desired state only, not actual macOS Login Item status
- [x] run targeted launch-at-login store tests - must pass before Task 3

### Task 3: Add ServiceManagement adapter and sync policy

- [x] write failing tests for desired `true` with actual disabled status registering once
- [x] write failing tests for desired `true` with actual enabled or requires-approval status not repeatedly registering
- [x] write failing tests for desired `false` with actual enabled or requires-approval status unregistering, and desired `false` with disabled status no-oping
- [x] write failing tests proving register/unregister errors and unavailable/not-found status are non-fatal and report a warning result
- [x] implement app-level `LaunchAtLoginStatus`, `LaunchAtLoginManaging`, and `ServiceManagementLaunchAtLoginManager` around `SMAppService.mainApp`
- [x] implement a `LaunchAtLoginController` or equivalent policy object that syncs desired store state to actual manager status without exposing ServiceManagement enums to coordinator/config code
- [x] run targeted launch-at-login policy/adapter tests - must pass before Task 4

### Task 4: Wire startup reconciliation through AppCoordinator

- [x] write failing coordinator tests proving startup seeds launch-at-login desired state from `AppConfig.launchAtLoginEnabled`
- [x] write failing coordinator tests proving startup sync calls register/unregister according to config-backed desired state
- [x] write failing coordinator tests proving sync failures do not prevent normal coordinator startup, status item installation, or timer startup
- [x] inject launch-at-login settings/controller seams into `AppCoordinator` with minimal wiring and no direct `SMAppService` usage
- [x] keep `AppCoordinator.swift` edits small; move helper types into focused launch-at-login files instead of growing coordinator support files
- [x] run targeted coordinator launch-at-login tests - must pass before Task 5

### Task 5: Wire new source/test files into the Xcode project

- [x] add new launch-at-login source files to the `Mahu` target in `Mahu.xcodeproj/project.pbxproj`
- [x] add new focused XCTest files to the `MahuTests` target in `Mahu.xcodeproj/project.pbxproj`
- [x] verify existing hosted test startup guard still prevents production coordinator side effects in tests
- [x] run `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` - must pass before Task 6

### Task 6: Update product and agent documentation

- [x] update `README.md` with the new `launchAtLoginEnabled` config key, default `false`, and restart-required behavior for manual config edits
- [x] update `README.md` manual checks for signed app Login Item behavior, System Settings state, and login/reboot validation
- [x] update `AGENTS.md` to move Launch at Login out of Deferred Features and record config-backed startup reconciliation as a product invariant
- [x] update `docs/decisions.md` if implementation choices differ from the decision recorded when this plan was created
- [x] run documentation-focused checks available in this repo, including `git diff --check` - must pass before Task 7

### Task 7: Verify acceptance criteria

- [x] verify old config files without `launchAtLoginEnabled` still load with defaults
- [x] verify `launchAtLoginEnabled: true` requests macOS main-app login registration at startup through the injected seam
- [x] verify `launchAtLoginEnabled: false` requests unregister/no-op behavior at startup through the injected seam
- [x] verify `.requiresApproval`, `.notFound`/unavailable, and thrown ServiceManagement errors keep Mahu running and log/report non-fatal warnings
- [x] verify no status-menu item or other user-facing UI was added for this feature
- [x] run full unit test suite with `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run build with `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run `make build`
- [x] run `git diff --check`

## Technical Details

### Config field

Add this optional/manual config field:

```json
{
  "workDurationSeconds": 1200,
  "breakDurationSeconds": 20,
  "showStatusItemTimerState": false,
  "breakOverlayMessageText": "Время отвлечься",
  "launchAtLoginEnabled": false
}
```

Rules:

- Missing `launchAtLoginEnabled` defaults to `false`.
- Valid booleans are accepted.
- Invalid type or `null` should follow the existing malformed-config fallback behavior.
- Manual config edits are launch-loaded only; changing this field while Mahu is running does not live-reload.

### Desired state vs actual state

- `LaunchAtLoginSettingsStore` stores desired state: what the user/config wants.
- `SMAppService.mainApp.status` represents actual macOS state.
- macOS may report `requiresApproval`, `notRegistered`, `enabled`, or `notFound` independent of config.
- If config says enabled but macOS requires approval or registration fails, Mahu logs a warning and continues running. It does not rewrite config to `false`.
- If config says disabled, Mahu requests unregister/no-op on the next launch instead of silently leaving a previously enabled Login Item behind.

### ServiceManagement flow

- Use `SMAppService.mainApp` for the main application; do not create a helper login-item bundle.
- Do not call `register()` every launch when status is already `enabled` or `requiresApproval`.
- Do call `register()` when desired is enabled and actual state is disabled/not registered.
- Do call `unregister()` when desired is disabled and actual state is enabled or requires approval.
- Treat errors as non-fatal startup diagnostics.

### Future Settings UI compatibility

The future Settings UI should reuse the same launch-at-login settings store and controller:

1. update desired state in `LaunchAtLoginSettingsStore`,
2. request sync through the launch-at-login controller,
3. persist the accepted desired value through `ConfigStore.save` when the managed Mahu Application Support directory and final `config.json` path are direct write-safe paths,
4. keep displaying actual state separately when macOS requires approval or denies registration.

## Post-Completion

*Items requiring manual intervention or external systems - no checkboxes, informational only.*

**Manual verification**:

- Build or archive a properly signed local `.app`; debug/ad-hoc behavior may differ.
- Set `"launchAtLoginEnabled": true` in `~/Library/Application Support/Mahu/config.json`, launch Mahu, and verify the app appears in System Settings → General → Login Items.
- Quit Mahu, log out/in or reboot, and verify Mahu starts as a menu-bar-only app with no Dock icon.
- Set `"launchAtLoginEnabled": false`, relaunch Mahu, and verify the Login Item is removed or disabled.
- Test the `.requiresApproval` path if macOS surfaces a pending approval state in System Settings.

**External/future updates**:

- Public release work still needs a non-placeholder bundle identifier, signing, notarization, and packaging plan.
- Future Settings UI should expose this desired state and actual approval status without adding a status-menu item retroactively.
