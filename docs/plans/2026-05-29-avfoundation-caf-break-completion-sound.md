# AVFoundation CAF Break Completion Sound

## Overview

Switch Mahu's break completion audio from the current bundled WAV resource played via `NSSound` to a bundled CAF resource played via AVFoundation `AVAudioPlayer`.

The new source audio is `source-assets/11labs-sound-sample.caf`. The app runtime resource should be a clear, stable bundle file named `Mahu/Resources/break-completion.caf`; the old runtime `Mahu/Resources/sound.wav` should be removed from the app target and repository runtime resources.

The existing product behavior must remain unchanged: when a visible break ends naturally, Mahu plays the completion sound once; pressing `Skip`, pause/resume reminder actions, work-to-break transitions, and failed overlay presentation/retry paths must not play the sound. Audio resource or playback failures must remain non-fatal.

## Context (from discovery)

- Files/components involved:
  - `source-assets/11labs-sound-sample.caf`: new source audio file.
  - `Mahu/Resources/sound.wav`: current runtime audio resource to replace and remove.
  - `Mahu/Resources/break-completion.caf`: planned runtime audio resource.
  - `Mahu/BreakCompletionSoundPlayer.swift`: current playback implementation uses `NSSound` and looks up `sound.wav`.
  - `Mahu/AppCoordinator.swift`: owns completion-sound trigger semantics through `BreakCompletionSoundPlaying`; should not need behavior changes.
  - `Mahu.xcodeproj/project.pbxproj`: currently includes `sound.wav` in the resources build phase; must be updated for `break-completion.caf`.
  - `Makefile`: currently checks for bundled/copied `sound.wav`; must check `break-completion.caf`.
  - `MahuTests/SmokeTests.swift`: currently verifies `sound.wav` exists in the hosted app bundle.
  - `MahuTests/BreakCompletionSoundPlayerTests.swift`: validates missing/empty/decode/playback failure handling and active sound retention.
  - `MahuTests/AppCoordinatorBreakSoundTests.swift`: validates natural completion vs skip/pause/retry trigger semantics; should stay green with the same protocol contract.
  - `README.md`: documents runtime resources and manual sound checks.
  - `docs/decisions.md`: decision log for CAF + AVFoundation and runtime-resource naming.
- Related patterns found:
  - Audio playback is an edge effect behind `BreakCompletionSoundPlaying`; `BreakTimer` must remain pure.
  - Runtime sound lookup failures are warning-level and non-fatal.
  - Tests should prove resource bundling and trigger semantics, but not assert real speaker output.
  - `make build` creates `build/Mahu.app` and verifies required resources are present.
- Dependencies identified:
  - AVFoundation / AVFAudio `AVAudioPlayer` for local bundled audio playback.
  - Xcode app target resource membership for the new `.caf` file.
  - Current external docs cache: `.tmp/external-context/avfoundation/avaudioplayer-caf-macos.md`.

## Development Approach

- **Testing approach**: TDD.
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
- Maintain backward compatibility at the app-flow level: keep the `BreakCompletionSoundPlaying` coordinator contract unless implementation evidence requires a narrower seam.

## Testing Strategy

- **Unit tests**: required for every task that changes code.
- **Resource tests**: update hosted app smoke tests to prove `break-completion.caf` is bundled and non-empty, and that `sound.wav` is no longer the runtime completion resource.
- **Playback tests**: update `BreakCompletionSoundPlayerTests` to exercise the AVFoundation-backed seam without requiring audible output.
- **Coordinator trigger tests**: keep `AppCoordinatorBreakSoundTests` passing to prove sound trigger semantics remain unchanged.
- **E2E tests**: the project has no UI E2E suite. Manual audio confirmation remains post-completion.

## Progress Tracking

- Mark completed items with `[x]` immediately when done.
- Add newly discovered tasks with ➕ prefix.
- Document issues/blockers with ⚠️ prefix.
- Update plan if implementation deviates from original scope.
- Keep plan in sync with actual work done.

## What Goes Where

- **Implementation Steps** (`[ ]` checkboxes): tasks achievable within this codebase - code changes, tests, documentation updates.
- **Post-Completion** (no checkboxes): items requiring external action - manual testing, audio-device checks, release verification.
- **Checkbox placement**: Checkboxes belong only in Task sections (`### Task N:` or `### Iteration N:`). Do not put checkboxes in Success criteria, Overview, or Context — they cause extra loop iterations.

## Implementation Steps

### Task 1: Lock the CAF resource contract with tests

- [x] update `MahuTests/SmokeTests.swift` to expect bundled `break-completion.caf` instead of `sound.wav`
- [x] add or update smoke-test assertions that the bundled CAF resource is non-empty and has the expected filename
- [x] add a smoke-test guard that the old `sound.wav` is not treated as the runtime completion resource, if practical without making the test brittle
- [x] run the focused smoke/resource tests and confirm they fail for the expected missing-CAF reason before implementation
- [x] update this plan with any resource-test scope adjustment discovered during the failing-test pass

Scope note after failing-test pass: the legacy-runtime guard is stable enough as a hosted-bundle lookup assertion for `sound.wav`; broader stale-reference cleanup remains deferred to Task 6.

### Task 2: Replace the runtime audio resource and build wiring

- [x] copy `source-assets/11labs-sound-sample.caf` to `Mahu/Resources/break-completion.caf`
- [x] remove `Mahu/Resources/sound.wav` from runtime resources
- [x] update `Mahu.xcodeproj/project.pbxproj` to remove `sound.wav` from the resources build phase and add `break-completion.caf`
- [x] update `Makefile` resource checks from `sound.wav` to `break-completion.caf`
- [x] run the focused smoke/resource tests - must pass before Task 3
- [x] run `make build` - must pass before Task 3

### Task 3: Convert playback implementation to AVFoundation

- [x] update `Mahu/BreakCompletionSoundPlayer.swift` to import AVFoundation and load `break-completion.caf`
- [x] replace the `NSSound` playback path with an `AVAudioPlayer`-backed path using local bundle URLs
- [x] preserve non-fatal warning behavior for missing resource, empty resource, init/decode failure, prepare failure, and play failure
- [x] retain the active `AVAudioPlayer` strongly while playback starts
- [x] update `MahuTests/BreakCompletionSoundPlayerTests.swift` for the AVFoundation-compatible seam and failure paths
- [x] write/update tests for successful player creation/playback start and active-player retention
- [x] write/update tests for missing, empty, decode/init failure, prepare failure, and play failure cases
- [x] run `MahuTests/BreakCompletionSoundPlayerTests` - must pass before Task 4

### Task 4: Preserve app-flow sound semantics

- [x] run existing `MahuTests/AppCoordinatorBreakSoundTests.swift` to confirm coordinator trigger behavior is unchanged
- [x] update coordinator sound tests only if the `BreakCompletionSoundPlaying` seam must change for AVFoundation (not needed; seam unchanged)
- [x] verify natural visible break completion still records exactly one sound trigger in tests
- [x] verify `Skip`, pause/resume, work-to-break transition, and failed overlay retry paths still record no sound trigger in tests
- [x] run `MahuTests/AppCoordinatorBreakSoundTests` - must pass before Task 5

### Task 5: Update documentation and decision history

- [x] update `README.md` to document `break-completion.caf` as the bundled completion sound resource
- [x] update README verification text so `make build` resource checks refer to `break-completion.caf`
- [x] update README manual checks to refer to the completion sound without stale `sound.wav` wording
- [x] append `docs/decisions.md` with the CAF + AVFoundation decision, including why `break-completion.caf` is used as the runtime filename
- [x] run documentation-adjacent checks available in the project, or note if there are none (`rtk grep -n "sound\\.wav|break-completion\\.caf|AVFoundation|AVAudioPlayer" README.md docs/decisions.md` and `rtk git diff --check -- README.md docs/decisions.md`; no dedicated docs linter exists in this repo)

### Task 6: Verify acceptance criteria

 - [x] verify the old runtime `Mahu/Resources/sound.wav` is removed from the repository/app target
 - [x] verify `Mahu/Resources/break-completion.caf` is present and bundled into `build/Mahu.app`
 - [x] run full unit test suite: `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
 - [x] run raw build: `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
 - [x] run app bundle build: `make build`
 - [x] verify no unexpected stale references to `sound.wav` remain in active runtime code, Makefile, README, or tests

### Task 7: Final documentation close-out

- [x] update this plan file if implementation deviated from the original task sequence (no task-sequence deviation beyond the Task 1 scope note already recorded in this plan)
- [x] ensure all completed implementation checkboxes are marked `[x]`
- [x] add any newly discovered manual verification limitations to Post-Completion

*Note: ralphex automatically moves completed plans to `docs/plans/completed/`.*

## Technical Details

- Runtime audio source path:
  - Source/staging file: `source-assets/11labs-sound-sample.caf`
  - Bundled app resource: `Mahu/Resources/break-completion.caf`
- Playback framework:
  - Use AVFoundation / AVFAudio `AVAudioPlayer`.
  - Load the bundled local URL with `Bundle.url(forResource:withExtension:)`.
  - Initialize with `AVAudioPlayer(contentsOf:)`, handling thrown errors.
  - Call `prepareToPlay()` before `play()` and treat a false result as a non-fatal playback failure.
  - Call `play()` and treat a false result as a non-fatal playback failure.
  - Keep a strong reference to the current player while playback starts.
- Processing flow:
  - `AppCoordinator` detects a visible natural `rest -> work` transition.
  - `AppCoordinator` calls `BreakCompletionSoundPlaying.playCompletionSound()`.
  - `BreakCompletionSoundPlayer` resolves `break-completion.caf`, validates it, creates an AVFoundation player, prepares, plays, and logs warning-only failures.

## Post-Completion

*Items requiring manual intervention or external systems - no checkboxes, informational only.*

**Manual verification**:

- Run fresh `build/Mahu.app`.
- Temporarily shorten local config durations.
- Let a visible break end naturally and confirm the new CAF sound plays once.
- Start another break, press `Skip`, and confirm no completion sound plays.
- Confirm pause/resume reminder toggles do not play the completion sound.
- Confirm the app still completes and restores focus normally when system audio output is muted or unavailable.
- Automated validation in this repo cannot prove real speaker output, output-device routing, or perceived loudness/timbre of the CAF clip; confirm those on a real macOS session.

**External references**:

- Apple AVFoundation / AVFAudio `AVAudioPlayer` docs.
- Apple Core Audio supported formats docs for CAF support.
