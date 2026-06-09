# Idle-Away Reset Configuration and Away State

## Overview

Make idle-away reset explicit, configurable, and understandable in the tray after manual verification found a severe regression: with current settings the timer can stay stuck around `10` seconds and never present the break overlay.

The current idle-away implementation treats long HID idle time as an away episode and suppresses elapsed-time consumption after the first reset in that episode. That can be correct product behavior, but without configuration and visible state it looks like a broken timer. This plan changes idle-away reset from always-on behavior into an opt-in runtime/config setting with a configurable threshold and adds an `Away` tray state when suppression is active.

Key benefits:

- legacy/missing config returns to normal timer behavior by default;
- users can opt into idle-away reset with an explicit threshold;
- enabled away suppression is visible as `Away` in optional tray timer mode;
- `Away` must not require more tray text width than the existing `Paused` state;
- sleep/wake reconciliation remains independent and unchanged.

## Context (from discovery)

- Files/components involved:
  - `Mahu/AppConfig.swift` — current config schema and backward-compatible decoding for optional fields.
  - `Mahu/AppCoordinator.swift` — current idle reconciliation entry point in `advanceTimer()`, before normal elapsed-time consumption.
  - `Mahu/IdleAwayReconciliationPolicy.swift` — `IdleAwayEpisodePolicy`, fixed `300s` threshold, `.suppressElapsedOnly`, and one-reset-per-idle-episode state.
  - `Mahu/UserIdleTimeProvider.swift` — live CoreGraphics HID idle provider and test-safe zero provider.
  - `Mahu/AppCoordinatorSupport.swift` — runtime settings protocols, timer display baseline policies, and status item seams.
  - `Mahu/StatusDisplayFormatter.swift` and `Mahu/StatusItemController.swift` — tray timer text, spacing, title-slot width, and icon anchoring behavior.
  - `MahuTests/AppCoordinatorIdleAwayResetTests.swift` and `MahuTests/AppCoordinatorIdleAwayPhaseBehaviorTests.swift` — existing idle reset/suppression coverage; some tests currently assert suppressed elapsed behavior.
  - Config tests such as `MahuTests/ConfigStoreStatusItemTimerTests.swift`, `MahuTests/ConfigStoreJSONCTests.swift`, `MahuTests/ConfigStoreJSONCEdgeCaseTests.swift`, and `MahuTests/ConfigStorePersistenceTests.swift`.
  - Tray/status tests such as `MahuTests/StatusDisplayFormatterTests.swift`, `MahuTests/StatusItemTimerDisplayTests.swift`, `MahuTests/StatusItemTimerAnchorTests.swift`, and coordinator status item tests.
  - `README.md`, `AGENTS.md`, and `docs/decisions.md` for user-visible config, project invariants, and decision history.
- Related patterns found:
  - Manual `config.json` is launch-loaded persistence only; live file reload remains out of scope.
  - `RuntimeSettingsStore` is the single in-process runtime source of truth for coordinator behavior and future Settings UI changes.
  - Existing optional fields default safely when missing.
  - Existing invalid config behavior falls back to defaults rather than aborting launch.
  - Tray timer mode is already optional through `showStatusItemTimerState`.
  - Tray title width is controlled by fixed title slot / widest-observed baseline behavior; new text states must not reintroduce icon drift.
  - `BreakTimer` must remain pure and unaware of idle, config, or tray UI state.
- Dependencies identified:
  - Existing CoreGraphics provider remains the idle source when feature is enabled.
  - No new external libraries are needed.
  - `ralphex` is installed at `/opt/homebrew/bin/ralphex`.

## Selected Approach

Chosen scope: **Config + coordinator + tray display + docs**.

Chosen defaults:

- `idleAwayResetEnabled` defaults to `false`.
- `idleAwayResetThresholdSeconds` defaults to `300`.
- Threshold must be positive; non-positive or invalid explicit config falls back to defaults according to the project’s existing config resilience rules.

Chosen tray state:

- Display `Away` while enabled idle-away suppression is active.
- `Away` is shorter than `Paused` and must not widen the controlled tray title slot beyond the existing paused-state requirement.
- `Away` is visible only when optional tray timer display is enabled; icon-only mode stays icon-only.

## Development Approach

- **Testing approach**: TDD.
- Complete each task fully before moving to the next.
- Make small, focused changes.
- Keep `AppCoordinator.swift` edits minimal because the file is already past the local readability threshold.
- Prefer new focused test files over expanding already-large test files, but update `Mahu.xcodeproj/project.pbxproj` whenever a new test/source file is added.
- **CRITICAL: every task MUST include new/updated tests** for code changes in that task:
  - tests are not optional;
  - write unit tests for new config fields and modified decoding paths;
  - write coordinator tests for disabled/enabled idle behavior and away suppression;
  - write tray/status tests for `Away` display and width constraints;
  - update existing tests that currently encode always-on idle reset assumptions.
- **CRITICAL: all tests must pass before starting next task** - no exceptions.
- **CRITICAL: update this plan file when scope changes during implementation**.
- Run targeted tests after each task.
- Maintain backward compatibility for existing configs by defaulting missing idle-away fields to disabled behavior.

## Testing Strategy

- **Unit tests** are required for every task.
- Use injected idle providers in coordinator tests; do not depend on real HID idle time.
- Use an idle provider fake that can fail the test if it is called while idle-away reset is disabled.
- Required config coverage:
  - missing `idleAwayResetEnabled` defaults to `false`;
  - missing `idleAwayResetThresholdSeconds` defaults to `300`;
  - explicit enabled/disabled values decode correctly;
  - custom positive threshold decodes correctly;
  - non-positive threshold and invalid/null types follow existing fallback semantics;
  - saved/default config remains strict JSON and includes or safely preserves the new fields according to existing save behavior.
- Required coordinator coverage:
  - default disabled idle-away does not reset, suppress elapsed, or query live/system idle state;
  - disabled behavior lets a short work timer reach rest and show the overlay even if a fake provider would report long idle;
  - enabled behavior preserves one-reset-per-idle-episode suppression semantics;
  - enabled custom threshold is used instead of fixed `300`;
  - user activity below threshold exits `Away`, re-arms the next episode, and restores countdown display;
  - paused reminders remain visually and semantically distinct from away.
- Required tray/status coverage:
  - `Away` formats exactly as `Away`;
  - `Away` does not require more title width than `Paused`;
  - icon-only mode remains icon-only;
  - switching countdown → `Away` → countdown does not move the tray icon.
- Manual verification remains required for real macOS HID behavior.

## Progress Tracking

- Mark completed items with `[x]` immediately when done.
- Add newly discovered tasks with a `➕` prefix.
- Document issues/blockers with a `⚠️` prefix.
- Update this plan if implementation deviates from original scope.
- Keep the plan in sync with actual work done.

## What Goes Where

- **Implementation Steps**: code changes, tests, documentation/decision updates, and deterministic verification commands.
- **Post-Completion**: manual macOS idle checks, real tray UX checks, and release/signing checks.
- **Checkbox placement**: checkboxes belong only in Task sections. Do not add checkboxes to Overview, Context, Technical Details, Success Criteria, or Post-Completion.

## Implementation Steps

### Task 1: Add idle-away config schema

- [x] add failing config tests for missing `idleAwayResetEnabled` defaulting to `false` and missing `idleAwayResetThresholdSeconds` defaulting to `300`
- [x] add failing config tests for explicit `idleAwayResetEnabled: true/false` and positive custom threshold decoding
- [x] add failing config tests for non-positive threshold and invalid/null field types following existing fallback semantics
- [x] update `Mahu/AppConfig.swift` with `idleAwayResetEnabled` and `idleAwayResetThresholdSeconds` defaults, decoding, validation, and Equatable behavior as needed
- [x] update config persistence/JSONC tests so app-created or app-saved config remains strict JSON and the new fields round-trip correctly
- [x] run targeted config tests - must pass before Task 2

### Task 2: Gate idle-away reconciliation by runtime settings

- [x] add failing coordinator tests proving default disabled idle-away does not query the idle provider, does not suppress elapsed time, and allows a near-expired work timer to reach rest
- [x] add failing coordinator tests proving `idleAwayResetEnabled: true` preserves existing long-idle reset/suppression behavior
- [x] add failing coordinator tests proving `idleAwayResetThresholdSeconds` is read from current runtime settings instead of the fixed `300` value
- [x] update `AppCoordinator`/idle policy wiring to skip idle reconciliation entirely when disabled and to use runtime threshold when enabled
- [x] ensure disabling idle-away clears/re-arms any current idle episode policy state so stale suppression cannot survive a future runtime toggle
- [x] run targeted coordinator idle tests - must pass before Task 3

### Task 3: Add `Away` status display state

- [x] add failing formatter/status tests for an `Away` display state formatted exactly as `Away`
- [x] add failing tray width/anchor tests proving `Away` is not wider than `Paused` and does not expand the controlled title slot beyond the paused-state requirement
- [x] add failing tests proving icon-only mode remains icon-only when the coordinator enters away suppression
- [x] update `StatusDisplayState`, `StatusDisplayFormatter`, and `StatusItemController` seams to support `Away` without changing paused semantics
- [x] run targeted status display and tray timer tests - must pass before Task 4

### Task 4: Wire `Away` state into enabled idle suppression

- [x] add failing coordinator tests proving countdown → `Away` while enabled long idle remains above threshold after the first reset
- [x] add failing coordinator tests proving user activity below threshold exits `Away`, re-arms idle reset, and restores the normal countdown display
- [x] add failing coordinator tests proving `Paused` remains distinct from `Away` and paused reminders do not show away text
- [x] update `AppCoordinator` and `IdleAwayEpisodePolicy` so `.suppressElapsedOnly` (or its replacement) reports an explicit away-display condition to the status item without consuming elapsed time
- [x] ensure disabled idle-away never emits `Away`, even if the idle provider would report long idle
- [x] run targeted idle-away + status item coordinator tests - must pass before Task 5

### Task 5: Update documentation and decision history

- [x] update `README.md` with `idleAwayResetEnabled`, `idleAwayResetThresholdSeconds`, defaults, example config, `Away` tray behavior, and enabled/disabled manual checks
- [x] update `AGENTS.md` so idle-away reset is described as config-gated instead of always-on, and record the `Away` tray text constraint
- [x] append a `docs/decisions.md` entry for making idle-away reset opt-in/configurable and for using `Away` as bounded tray text
- [x] update any stale completed-plan cross-references or handoff notes only if needed to avoid misleading future agents
- [x] run `git diff --check` - must pass before Task 6

### Task 6: Verify acceptance criteria

- [ ] verify missing/legacy config defaults to `idleAwayResetEnabled == false`
- [ ] verify disabled idle-away cannot freeze the timer at `10s` and can still reach the break overlay
- [ ] verify enabled idle-away uses configured threshold and shows `Away` while suppressing elapsed time
- [ ] verify `Away` does not require more tray width than `Paused` and does not break icon anchoring
- [ ] verify sleep/wake reconciliation still uses the existing long-sleep semantics independently of idle-away settings
- [ ] verify no live config reload or file watcher was introduced
- [ ] run full unit test suite with `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [ ] run build with `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [ ] run `make build`
- [ ] run `git diff --check`

## Technical Details

### Config keys

```json
{
  "idleAwayResetEnabled": false,
  "idleAwayResetThresholdSeconds": 300
}
```

Semantics:

- `idleAwayResetEnabled` defaults to `false` for missing/legacy config.
- `idleAwayResetThresholdSeconds` defaults to `300`.
- Threshold must be positive.
- Manual config edits still apply only on relaunch.
- Future Settings UI/runtime updates should change `RuntimeSettingsStore` directly, not reload disk config.

### Coordinator behavior

When disabled:

- do not run idle-away reconciliation;
- do not query the live/system idle provider;
- do not suppress elapsed time;
- keep normal work/rest countdown behavior.

When enabled:

- compare safe current idle duration against `idleAwayResetThresholdSeconds` from runtime settings;
- active work + long idle resets to a fresh work interval from current runtime settings;
- repeated ticks in the same away episode suppress elapsed time instead of repeatedly replacing the timer;
- while suppression is active, tray timer mode shows `Away`;
- user activity below the threshold exits `Away`, re-arms future idle reset, and resumes normal countdown behavior;
- paused reminders remain paused and should not be conflated with away.

### Tray state

`Away` is the selected label because it is shorter than `Paused`, clear enough for a menu-bar app, and avoids increasing the controlled status-item title slot beyond the existing paused-state requirement.

### Out of scope

- live config reload/file watcher;
- Settings UI;
- event taps/global hooks/Accessibility/Input Monitoring;
- changing long sleep/wake semantics;
- replacing native `NSStatusItem` with a custom view;
- making `BreakTimer` aware of idle or UI state.

## Post-Completion

*Items requiring manual intervention or external systems - no checkboxes, informational only.*

**Manual verification**:

- With missing/default config, set a short work duration and confirm the timer reaches rest/break overlay instead of freezing at `10s`.
- With `idleAwayResetEnabled: false`, leave the Mac untouched for more than the threshold and confirm the timer still behaves like the pre-idle-away app.
- With `idleAwayResetEnabled: true` and a short threshold, confirm the tray shows `Away` while the app is suppressing elapsed time.
- Confirm `Away` fits within the same tray footprint as `Paused` and does not move the tray icon.
- Confirm user input exits `Away` and returns to countdown display.
- Confirm paused reminders still show `Paused`, not `Away`.
- Repeat with external keyboard/mouse and external display, because CoreGraphics HID idle behavior can vary by device/session.

**Future follow-up**:

- If users want this feature commonly, consider enabling it by default only after real-device manual checks prove the `Away` UX is reliable.
- If `Away` needs stronger visibility in icon-only mode, plan a separate UI change rather than expanding this fix plan.
