# Break Completion Sound

Status: Completed (2026-05-28)

Superseded on 2026-05-29 by `docs/plans/completed/2026-05-29-avfoundation-caf-break-completion-sound.md`.
Historical context only: the shipped runtime contract is now `break-completion.caf` played through `AVAudioPlayer`.

## Overview

- Bundle the user-provided `images/sound.wav` into the Mahu app and play it when a break ends naturally.
- The sound tells users they can return attention even if they are not watching the screen.
- The sound should play only on natural break completion (`rest -> work`), not when the user presses `Skip`.
- Keep `BreakTimer` as a pure state machine and keep audio playback behind a small app-edge seam.
- Playback failures or missing audio resources must not crash the app or block timer/overlay cleanup.

## Context (from discovery)

- Files/components involved:
  - `images/sound.wav` — user-provided source/staging sound file. Copy this into app resources; do not delete the source file.
  - `Mahu/Resources/sound.wav` — target bundled runtime resource to add.
  - `Mahu.xcodeproj/project.pbxproj` — must include `sound.wav` in the resources build phase, following the existing `background.png` pattern.
  - `Mahu/AppCoordinator.swift` — owns work/rest transitions and is the right place to trigger a sound on natural break completion.
  - `Mahu/BreakTimer.swift` — pure timer state machine; do not add audio or bundle logic here.
  - `Mahu/BreakOverlayManager.swift` / overlay skip flow — `Skip` already closes the break and calls coordinator skip handling; sound must not play on this path.
  - `Mahu/BreakCompletionSoundPlayer.swift` — proposed new production file for `NSSound`-based playback and bundle lookup.
  - `MahuTests/AppCoordinatorTestSupport.swift` — likely place for a fake sound player spy.
  - `MahuTests/AppCoordinatorBreakSoundTests.swift` — proposed new focused test file so existing coordinator tests do not grow too large.
  - `MahuTests/SmokeTests.swift` — already verifies bundled `background.png`; extend with `sound.wav` bundle/resource checks.
  - `Makefile` — currently verifies `background.png` in built/copied app bundles; add analogous `sound.wav` checks.
  - `README.md` — document sound behavior, resource presence, verification, and manual checks.
  - `docs/decisions.md` — record the decision to play bundled audio only on natural break completion.
- Related patterns found:
  - AppKit/side-effect behavior stays at the edges; coordinator wires effects while core timer logic remains isolated.
  - Existing bundled resource pattern uses `Mahu/Resources/background.png` plus Xcode resource build-phase membership and `make build` file checks.
  - Existing tests use protocols/fakes around coordinator side effects rather than exercising real windows or real audio output.
  - `AppCoordinator.swift` is near the local 300-line refactor signal, so new live audio code should live in a separate file.
  - `ralphex` is installed at `/opt/homebrew/bin/ralphex`.
- Dependencies identified:
  - Use `NSSound` for the initial macOS-native implementation.
  - `NSSound` instances must be retained by the live sound player to avoid playback being cut off.
  - `xcodebuild test`, `xcodebuild build`, and `make build` are the required automated verification commands.

## Development Approach

- **Testing approach**: TDD — first add failing tests for resource bundling and coordinator playback semantics, then implement in small increments.
- Chosen approach: use `NSSound` in a small `BreakCompletionSoundPlayer` edge object, injected into `AppCoordinator` through a protocol.
- Copy `images/sound.wav` to `Mahu/Resources/sound.wav`; keep the original `images/sound.wav` in place.
- Complete each task fully before moving to the next.
- Make small, focused changes.
- **CRITICAL: every task MUST include new/updated tests** for code changes in that task.
  - tests are not optional - they are a required part of the checklist
  - write unit tests for new functions/methods
  - write unit tests for modified functions/methods
  - add new test cases for new code paths
  - update existing test cases if behavior changes
  - tests cover both success and error scenarios
- **CRITICAL: all tests must pass before starting next task** - no exceptions.
- **CRITICAL: update this plan file when scope changes during implementation**.
- Run tests after each change.
- Maintain backward compatibility: no sound on `Skip`, no sound on work-start, no audio logic in `BreakTimer`, no private APIs, no settings UI.

## Testing Strategy

- **Unit tests**: required for every task.
- Add resource tests in `SmokeTests` for:
  - `Bundle.main.url(forResource: "sound", withExtension: "wav")` exists.
  - the resolved resource is inside the app bundle resources.
  - the file is non-empty.
- Add coordinator tests for:
  - natural break completion calls the fake sound player exactly once.
  - `Skip` hides the overlay but does not call the sound player.
  - work-to-break transition does not play sound.
  - failed/invisible break presentation retry does not play sound.
  - pause/resume reminder toggles do not play sound.
- Add sound-player tests only if implementation exposes testable pure seams; avoid trying to assert real speaker output.
- **E2E tests**: none exist. Do not introduce UI/audio automation. Use manual checks in Post-Completion.

## Progress Tracking

- Mark completed items with `[x]` immediately when done.
- Add newly discovered tasks with ➕ prefix.
- Document issues/blockers with ⚠️ prefix.
- Update plan if implementation deviates from original scope.
- Keep plan in sync with actual work done.

## What Goes Where

- **Implementation Steps** (`[ ]` checkboxes): tasks achievable within this codebase - resources, Xcode project wiring, code, tests, documentation, and automated verification.
- **Post-Completion**: items requiring manual action - live audio output and user/system audio-state checks.
- **Checkbox placement**: Checkboxes belong only in Task sections. Do not put checkboxes in Success criteria, Overview, or Context.

## Implementation Steps

### Task 1: Add `sound.wav` as a bundled app resource
- [x] copy `images/sound.wav` to `Mahu/Resources/sound.wav` without deleting `images/sound.wav`
- [x] add `Mahu/Resources/sound.wav` to `Mahu.xcodeproj/project.pbxproj` as an app bundle resource beside `background.png`
- [x] update `Makefile` to verify `sound.wav` exists in both the built app and copied `build/Mahu.app`
- [x] add or update `MahuTests/SmokeTests.swift` to verify `sound.wav` resolves from `Bundle.main`, lives inside bundle resources, and is non-empty
- [x] run `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` and confirm the resource test fails before resource wiring is complete, then passes after wiring

### Task 2: Add break completion sound playback seam
- [x] create `Mahu/BreakCompletionSoundPlayer.swift` with a small `BreakCompletionSoundPlaying` protocol
- [x] implement a live `NSSound`-based player that loads `sound.wav` from an injected bundle, retains the sound object, and plays it on demand
- [x] make missing, empty, undecodable, or unplayable sound resources fail gracefully without crashing the app
- [x] add focused tests or seam-level checks for missing-resource behavior if feasible without real audio output
- [x] run `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` - must pass before Task 3

### Task 3: Define coordinator sound semantics in tests
- [x] extend `MahuTests/AppCoordinatorTestSupport.swift` with a fake `BreakCompletionSoundPlaying` spy
- [x] add `MahuTests/AppCoordinatorBreakSoundTests.swift` proving natural `rest -> work` completion plays sound exactly once
- [x] add a test proving `Skip` hides the break overlay but does not play sound
- [x] add tests proving `work -> rest`, failed break presentation retry, and pause/resume toggles do not play sound
- [x] run `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` and confirm the new coordinator tests fail before Task 4

### Task 4: Wire sound playback into `AppCoordinator`
- [x] inject a `BreakCompletionSoundPlaying` dependency into `AppCoordinator`, defaulting to the live `BreakCompletionSoundPlayer`
- [x] play sound only when a visible break naturally completes and the timer transitions from `.rest` to `.work`
- [x] ensure `skipBreak()` does not trigger break-completion sound
- [x] ensure failed overlay presentation/retry, pause/resume, app launch, and `work -> rest` do not trigger sound
- [x] keep audio playback out of `BreakTimer` and avoid adding direct audio code to overlay view/model types
- [x] run `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` - must pass before Task 5

### Task 5: Verify acceptance criteria and builds
- [x] verify `Mahu.app/Contents/Resources/sound.wav` exists in the raw Xcode built app
- [x] verify `build/Mahu.app/Contents/Resources/sound.wav` exists after `make build`
- [x] verify natural break completion plays the fake sound player once in automated tests
- [x] verify `Skip` does not play the fake sound player in automated tests
- [x] run full unit tests with `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run raw app build with `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [x] run local artifact build with `make build`

### Task 6: Update documentation and decision record
- [x] update `README.md` Current Behavior to document that Mahu plays `sound.wav` when a break ends naturally
- [x] update `README.md` Project Structure and Verification/Manual Checks for the bundled `sound.wav` resource and natural-break sound behavior
- [x] update `docs/decisions.md` with the decision to play bundled `NSSound` audio only on natural break completion and not on `Skip`
- [x] update this plan if implementation discovers a better seam or if `NSSound` cannot reliably retain/play the bundled file (no plan change was needed; the existing retained `NSSound` seam stayed correct)
- [x] run `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` after documentation-related code/test changes, if any

## Technical Details

- Resource location:
  - Source/staging file: `images/sound.wav`.
  - Runtime bundled file: `Mahu/Resources/sound.wav`.
  - Built app path: `Mahu.app/Contents/Resources/sound.wav`.
- Playback timing:
  - Play once when a break reaches zero naturally and the coordinator handles the resulting `.work` state after a visible break.
  - Do not play on `Skip`, app launch, pause/resume, failed presentation retry, or `work -> rest` transition.
- Suggested production shape:
  - `protocol BreakCompletionSoundPlaying { func playBreakCompletionSound() }`
  - `final class BreakCompletionSoundPlayer: BreakCompletionSoundPlaying`
  - initializer accepts `bundle: Bundle = .main`.
  - live player resolves `sound.wav`, creates/retains `NSSound`, and calls `play()`.
- Failure handling:
  - Missing or unplayable sound should not crash and should not block overlay teardown or timer state changes.
  - Prefer warning/logging if a project logging pattern is already present; otherwise fail silently in the live audio edge and rely on resource tests/build checks.
- Architecture constraints:
  - `BreakTimer` remains pure.
  - `AppCoordinator` only triggers the sound player through a protocol.
  - Real audio output is not asserted in automated tests.

## Success Criteria

- `sound.wav` is bundled into the app resources.
- Natural break completion plays the break-completion sound once.
- `Skip` does not play the sound.
- Work-to-break transition does not play the sound.
- Pause/resume reminders do not play the sound.
- Missing/unplayable audio resource does not crash the app.
- `make build` fails if the final copied app lacks `sound.wav`.
- `xcodebuild test`, `xcodebuild build`, and `make build` pass.
- `README.md` and `docs/decisions.md` document the behavior and rationale.

## Post-Completion

*Items requiring manual intervention or external systems - no checkboxes, informational only.*

**Manual verification:**
- Launch `build/Mahu.app` and confirm the app has no Dock icon.
- Use a short config, wait for a break to end naturally, and confirm the sound plays once.
- Start another break and press `Skip`; confirm no completion sound plays.
- Confirm pause/resume menu actions do not play the sound.
- Confirm the app continues working if system output is muted or unavailable; users may not hear the sound in that environment.
- Confirm the sound is acceptable in volume/duration and does not feel disruptive.

**External/release follow-up:**
- Revisit volume, user configurability, mute settings, and localization during a future settings UI feature.
- During sandbox/signing work, verify bundled-resource audio playback still works in the signed app.
