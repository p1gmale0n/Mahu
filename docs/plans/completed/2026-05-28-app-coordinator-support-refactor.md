# App Coordinator Support Refactor

Status: Completed (2026-05-28)

## Overview

- Refactor `Mahu/AppCoordinator.swift` after recent pause/resume, paused-icon, and break-completion sound work pushed the file above the local readability threshold.
- Keep this refactor behavior-neutral: no product behavior, timer semantics, overlay behavior, pause/resume behavior, or sound trigger behavior should change.
- Extract coordinator support declarations into one focused file, `Mahu/AppCoordinatorSupport.swift`, so `AppCoordinator.swift` can focus on orchestration flow.
- Preserve the current architecture: `AppCoordinator` wires flow, `BreakTimer` remains a pure state machine, `StatusItemController` owns status-item UI, `BreakOverlayManager` owns overlay windows/display/focus behavior, and `BreakCompletionSoundPlayer` owns audio playback details.

## Context (from discovery)

- Files/components involved:
  - `Mahu/AppCoordinator.swift` — currently about 312 lines and mixes coordinator logic with protocols, typealiases, live scheduler, and concrete conformance extensions.
  - `Mahu/AppCoordinatorSupport.swift` — new file to hold coordinator-facing protocols/typealiases/live scheduler/conformance extensions.
  - `Mahu/BreakTimer.swift` — pure work/rest state machine; do not move pause, overlay, or sound logic into it.
  - `Mahu/StatusItemController.swift` — owns menu/status-item UI and paused icon visual state; coordinator should continue using only `StatusItemControlling`.
  - `Mahu/BreakOverlayManager.swift` — owns overlay windows, display hot-plug/reconciliation, focus retention, previous-app restoration, and visibility callbacks.
  - `Mahu/BreakCompletionSoundPlayer.swift` — owns bundled `sound.wav` lookup/playback and exposes `BreakCompletionSoundPlaying`.
  - `MahuTests/AppCoordinatorTests.swift` — core coordinator regression tests for startup, ticks, work/rest transitions, skip, delayed ticks, and cancellation.
  - `MahuTests/AppCoordinatorBreakPresentationTests.swift` — hidden/no-display/failed-presentation timing regression tests.
  - `MahuTests/AppCoordinatorReminderPauseTests.swift` — reminder pause/resume semantics and wiring tests.
  - `MahuTests/AppCoordinatorBreakSoundTests.swift` — sound trigger and hidden-boundary regression tests.
  - `MahuTests/AppCoordinatorTestSupport.swift` — fakes for coordinator protocols; may need import/visibility compatibility after moving protocols.
  - `README.md` — current behavior and verification commands; likely no behavior-doc change needed unless project structure notes are updated.
  - `docs/decisions.md` — record the refactor decision after implementation.
  - `Makefile` — `make build` verification command.
- Related patterns found:
  - Previous large-file pressure was handled by extracting focused support files rather than adding more inline coordinator code.
  - Existing coordinator tests provide strong behavior regression coverage; structural line-count tests would be brittle and low-value.
  - `ralphex` is installed at `/opt/homebrew/bin/ralphex`.
- Dependencies identified:
  - Swift access control and `@MainActor` annotations must remain compatible after declarations move files.
  - Xcode project membership must include any new Swift file.
  - `xcodebuild test`, `xcodebuild build`, and `make build` are the required verification commands.

## Development Approach

- **Testing approach**: Regular refactor + full regression tests. This is a behavior-neutral code organization change, so do not add brittle structure-only tests.
- Chosen approach: one new support file, `Mahu/AppCoordinatorSupport.swift`, containing coordinator protocols/typealiases/live scheduler/conformance extensions.
- Complete each task fully before moving to the next.
- Make small, focused changes.
- **CRITICAL: every task MUST include new/updated tests** for code changes in that task when behavior changes.
  - This refactor should not change behavior, so existing regression tests are the proof mechanism.
  - If implementation discovers a behavior gap, add focused tests in the appropriate existing or new `AppCoordinator...Tests.swift` file before changing behavior.
- **CRITICAL: all tests must pass before starting next task** - no exceptions.
- **CRITICAL: update this plan file when scope changes during implementation**.
- Run tests after each change.
- Maintain backward compatibility: no changes to timer semantics, pause/resume semantics, overlay visibility accounting, skip behavior, sound trigger timing, menu behavior, resources, or build commands.

## Testing Strategy

- **Unit/regression tests**: rely on the existing coordinator suites:
  - `AppCoordinatorTests`
  - `AppCoordinatorBreakPresentationTests`
  - `AppCoordinatorReminderPauseTests`
  - `AppCoordinatorBreakSoundTests`
- **Structural tests**: do not add line-count or file-existence tests; they are brittle and do not prove user behavior.
- **E2E tests**: none exist. Do not introduce UI automation for this refactor.
- Final proof must include:
  - full `xcodebuild test` suite;
  - raw `xcodebuild build`;
  - `make build`.

## Progress Tracking

- Mark completed items with `[x]` immediately when done.
- Add newly discovered tasks with ➕ prefix.
- Document issues/blockers with ⚠️ prefix.
- Update plan if implementation deviates from original scope.
- Keep plan in sync with actual work done.

## What Goes Where

- **Implementation Steps** (task checkboxes): tasks achievable within this codebase - file extraction, Xcode project wiring, regression validation, and documentation/decision updates.
- **Post-Completion**: items requiring manual action - none expected for a behavior-neutral refactor beyond optional smoke use of the app.
- **Checkbox placement**: Checkboxes belong only in Task sections. Do not put checkboxes in Success criteria, Overview, or Context.

## Implementation Steps

### Task 1: Extract coordinator support declarations
- [x] create `Mahu/AppCoordinatorSupport.swift`
- [x] move `BreakTimerControlling`, `StatusItemControlling`, `BreakOverlayManaging`, `RepeatingTickScheduler`, `CurrentUptimeProvider`, and `OverlayVisibilityChangeHandler` from `Mahu/AppCoordinator.swift` to `Mahu/AppCoordinatorSupport.swift`
- [x] move `LiveRepeatingScheduler` from `Mahu/AppCoordinator.swift` to `Mahu/AppCoordinatorSupport.swift`
- [x] move the concrete conformance extensions for `BreakTimer`, `StatusItemController`, and `BreakOverlayManager` to `Mahu/AppCoordinatorSupport.swift`
- [x] keep `@MainActor` annotations, protocol method signatures, typealiases, and default scheduler behavior unchanged
- [x] add `Mahu/AppCoordinatorSupport.swift` to the Xcode app target if required by the project file
- [x] run `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` - must pass before Task 2

### Task 2: Verify `AppCoordinator.swift` remains behavior-focused
- [x] verify `Mahu/AppCoordinator.swift` no longer contains protocol/typealias/live-scheduler/conformance boilerplate
- [x] verify `Mahu/AppCoordinator.swift` still owns only the existing orchestration state and methods: `start`, tick advancement, phase handling, visibility-edge handling, skip, pause, and resume
- [x] verify no timer, overlay, pause/resume, or sound semantics changed during extraction
- [x] verify `BreakTimer.swift`, `StatusItemController.swift`, `BreakOverlayManager.swift`, and `BreakCompletionSoundPlayer.swift` responsibilities remain unchanged
- [x] run `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` - must pass before Task 3

### Task 3: Verify acceptance criteria and builds
- [x] run full unit tests with `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run raw app build with `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run local artifact build with `make build`
- [x] verify the coordinator pause/resume, hidden-break, skip, and sound tests still pass as part of the full suite
- [x] verify no new runtime resources or product behavior changes were introduced

### Task 4: Update documentation and decision record
- [x] update `docs/decisions.md` with the decision to extract coordinator support declarations into `AppCoordinatorSupport.swift` as a behavior-neutral readability refactor
- [x] update `README.md` only if the project structure section should mention the new support file; otherwise leave behavior docs unchanged
- [x] update this plan if implementation discovers a need for deeper extraction beyond support declarations
- [x] run `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` after documentation-related code/test changes, if any

## Technical Details

- New file:
  - `Mahu/AppCoordinatorSupport.swift`
- Declarations to move without semantic changes:
  - `protocol BreakTimerControlling`
  - `protocol StatusItemControlling`
  - `typealias RepeatingTickScheduler`
  - `typealias CurrentUptimeProvider`
  - `typealias OverlayVisibilityChangeHandler`
  - `@MainActor protocol BreakOverlayManaging`
  - `enum LiveRepeatingScheduler`
  - `extension BreakTimer: BreakTimerControlling`
  - `extension StatusItemController: StatusItemControlling`
  - `@MainActor extension BreakOverlayManager: BreakOverlayManaging`
- Code that should stay in `AppCoordinator.swift` for this minimal refactor:
  - dependency storage and initializer;
  - `start()`;
  - `advanceTimer()`;
  - elapsed consumption and phase boundary handling;
  - `handle(state:)`;
  - `handleOverlayVisibilityChange(_:)`;
  - `skipBreak()`;
  - `pauseReminders()` and `resumeReminders()`;
  - `deinit` cancellation.
- Do not extract elapsed-time accounting in this plan unless the minimal refactor fails to compile or leaves the file unacceptably hard to maintain. If deeper extraction becomes necessary, update the plan first.

## Success Criteria

- `AppCoordinator.swift` is smaller and focused on orchestration rather than support declarations.
- `AppCoordinatorSupport.swift` contains the coordinator-facing protocols/typealiases/scheduler/conformances.
- No product behavior changes.
- `BreakTimer` remains pure.
- `BreakOverlayManager` keeps display/window/focus ownership.
- `StatusItemController` keeps menu/status-item UI ownership.
- `BreakCompletionSoundPlayer` keeps bundled sound playback details.
- Existing coordinator and resource tests pass.
- `xcodebuild test`, `xcodebuild build`, and `make build` pass.
- `docs/decisions.md` records the refactor rationale.

## Post-Completion

*Items requiring manual intervention or external systems - no checkboxes, informational only.*

**Manual verification:**
- No dedicated manual verification is required for this behavior-neutral refactor.
- Optional smoke check: launch `build/Mahu.app` and confirm the menu, pause/resume, break overlay, and completion sound still behave as before.

**External/release follow-up:**
- If future coordinator features are added, prefer adding focused support/helper files before growing `AppCoordinator.swift` again.
- Consider a separate future refactor for elapsed-time accounting only if behavior tests remain strong and the next coordinator change touches that logic.
