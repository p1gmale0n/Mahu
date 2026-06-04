# Session Handoff

## 2026-05-28 / External Review Close - No Actionable Findings

🏁 Session Handoff:
- Status: Done
- Key Decisions: Leave tracked product code unchanged because the external review output explicitly reported no actionable findings, the pause/resume plan already documents the shipped semantics, `git diff` and `git diff --cached` were empty, and the latest branch state already contains the prior review-fix commit for this area. Record closure through a durable handoff note instead of inventing a synthetic code change.
- Validation: `git status --short`; `git diff`; `git diff --cached`; `git diff --name-only main...HEAD`; `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- Friction/CDD: The external loop still requires a close-out commit even when the worktree is already clean and the review output is effectively a no-op, so the only truthful artifact in this state is a handoff-only commit. This works for low-risk closure, but it will create noisy history if the loop keeps repeating without new findings.
- Next Steps: Let the external review loop finish from this close-out commit; if a later pass reports a concrete defect, limit the next patch to the affected files and rerun the macOS test suite before another review-close signal.

## 2026-05-25 / Review Fixes - Retina Tray Asset

🏁 Session Handoff:
- Status: Done
- Key Decisions: Accept the review finding as valid because the shipped `tray-icon-template@2x.png` kept the 1x glyph bounds on a 36x36 canvas; regenerate a real Retina mask and move source-asset assertions into focused `TrayIconAssetTests.swift` so raw-pixel scale checks do not push `StatusItemControllerTests.swift` past the local readability threshold.
- Validation: `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `make build`; attempted `swiftlint`, but the command is not available in this environment.
- Friction/CDD: The review gate still implies lint proof, but the repo has no tracked lint command and `swiftlint` is not installed here, so lint cannot be proven reproducibly in this environment. Real tray readability on the live Retina menu bar remains manual-only validation even after deterministic raster checks.
- Next Steps: Let the external review loop run again from the fix commit; if lint remains part of the gate, add a repo-owned lint command or install `swiftlint`; keep manual tray-icon appearance checks open for light/dark/high-contrast states.

## 2026-05-23 / Tray Icon Review Close

🏁 Session Handoff:
- Status: Done
- Key Decisions: Treat the tray-icon review finding as valid because `TrayIconTemplate` lives in `Assets.xcassets` and the shipped contract in the completed plan already calls for `NSImage(named: "TrayIconTemplate")`; keep the fix scoped to `StatusItemController.makeTrayTemplateStatusIcon()` and leave the unrelated untracked `images/` workspace artifact out of the review-close commit.
- Validation: `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `make build`
- Friction/CDD: The repo still has no tracked lint command and `swiftlint` is not installed in this environment, so this pass can only prove XCTest/build evidence. `xcodebuild` still emits the environment-level multiple-destinations warning for `platform=macOS`.
- Next Steps: Let the external review loop finish from this commit; manual menu-bar appearance checks for the tray icon in light/dark/high-contrast states still remain manual-only.

## 2026-05-22 / Second Review Pass 4 Fixes

🏁 Session Handoff:
- Status: Done
- Key Decisions: Add one immediate display reconciliation pass after `showBreak()` registers the screen observer so monitor changes that land during overlay startup are not lost; keep the fix inside `BreakOverlayManager` and prove it with a focused registrar-driven regression test instead of widening `AppCoordinator` scope.
- Validation: `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `make build`; attempted `swiftlint version`, but the command is not available in this environment.
- Friction/CDD: The review gate still implies lint evidence, but the repo still has no tracked lint command and `swiftlint` is not installed here, so lint cannot be proven reproducibly in this environment. Real monitor and fullscreen-Space timing behavior at the exact break-start boundary remains manual-only proof.
- Next Steps: Let the external loop run the next review iteration; if hardware is available, manually verify plugging or unplugging a monitor during the first moment of break presentation; add a tracked lint command or install `swiftlint` if future review gates require lint proof.

## 2026-05-22 / External Review Pass 5 - No Actionable Findings

🏁 Session Handoff:
- Status: Done
- Key Decisions: Leave the tracked code untouched because the external review output reported `NO ISSUES FOUND`, `git diff --name-status` and `git diff --cached --name-status` were empty, and the referenced hot-plug plan already marks `icon.png` plus `images/` as unrelated untracked workspace artifacts that must stay out of review-close commits.
- Validation: `git status --short`; `git diff --name-status`; `git diff --cached --name-status`; `sed -n '1,220p' docs/plans/completed/2026-05-22-overlay-display-hotplug.md`
- Friction/CDD: The loop still asks for a close-out commit even when the only worktree changes are unrelated untracked artifacts, which creates pressure either to sweep in junk or to mint an empty/artificial fix commit. Clarify whether a handoff-only commit is the intended closure for a no-op review pass.
- Next Steps: Commit only this durable handoff note with the standard review-close message and let the external loop finish; if a later pass reports a real issue, keep the scope limited to the affected tracked files and rerun the required verification.

## 2026-05-22 / Overlay Hot-Plug Review Fixes

🏁 Session Handoff:
- Status: Done
- Key Decisions: Make active-overlay reconciliation tolerant of duplicate display identifiers, add deinit teardown for screen/focus observers plus live overlay windows without restoring the previous app, and extract display/window support types into a sidecar source file so `BreakOverlayManager.swift` stops growing past the local readability threshold.
- Validation: `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `make build`; attempted `swiftlint`, but the command is not installed in this environment.
- Friction/CDD: The repo still has no tracked lint command, and `swiftlint` is not installed in this environment, so this review round can only prove XCTest/build evidence after code changes. Real mirrored-display, external-display, and fullscreen-Space behavior still remains manual-only because headless XCTest cannot prove live WindowServer composition.
- Next Steps: Run the next external review iteration against this branch; if a later pass still targets overlay lifecycle, keep new edits out of `BreakOverlayManager.swift` unless they also move more support code into focused sidecar files; manually verify hot-plug plus fullscreen-Space behavior on hardware when available.

## 2026-05-22 / Overlay Display Hot-Plug Task 3

🏁 Session Handoff:
- Status: Done
- Key Decisions: Reconcile active overlay windows by stable display id inside `BreakOverlayManager` so hot-plugging preserves the shared countdown/Skip view model, keeps unchanged windows alive, and replaces only added, removed, or resized displays. Ignore transient empty `screenProvider()` snapshots during an active break instead of silently ending the break.
- Validation: `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- Friction/CDD: `BreakOverlayManager.swift` is now beyond the local readability threshold, so the next task should extract focused hot-plug/focus helpers instead of adding more inline logic. Real monitor hot-plugging, scaling, and fullscreen-Space validation remain manual by design.
- Next Steps: Let the external loop continue with Task 4; add focus/restore regression coverage for hot-plug flows before touching README or final acceptance docs.

## 2026-05-22 / External Review Pass - No Actionable Findings

🏁 Session Handoff:
- Status: Done
- Key Decisions: Keep the centering-fix implementation unchanged because the SwiftUI `GeometryReader` sizing matches the documented design, the overlay call flow still stays isolated to `BreakOverlayView`, and the review pass surfaced no actionable regressions.
- Validation: `git diff`; `git diff --cached`; `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- Friction/CDD: The repository still has unrelated untracked workspace artifacts (`icon.png`, `images/`), so review-close commits must stay scoped and avoid sweeping them in. Manual built-in-display, external-display, and fullscreen-Space overlay checks still remain open because headless XCTest cannot prove live pixel alignment.
- Next Steps: Let the external loop continue from this commit; if a later pass reports a real issue, fix only the affected scope and rerun the macOS test suite.

## 2026-05-22 / Second Review Pass 3 Fixes

🏁 Session Handoff:
- Status: Done
- Key Decisions: Stop timer consumption at the `rest -> work` boundary so a delayed break-completion tick cannot burn the next work interval before the overlay hides; reset the coordinator uptime baseline when a visible break ends so work time resumes from actual dismissal; keep this round scoped to the real timing defect and add a focused regression test instead of broad refactoring.
- Validation: `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `make build`; attempted `swiftlint` and the command was not installed in this environment.
- Friction/CDD: The review gate still asks for lint evidence, but the repo still has no tracked lint command and `swiftlint` is not available here, so lint cannot be proven reproducibly in this environment. Real display and fullscreen-Space overlay behavior remains manual by design and was not revalidated in this timing-only fix round.
- Next Steps: Run the next external review iteration against this branch; if lint stays part of the gate, add a tracked lint command or provide `swiftlint` in the execution environment; keep hardware-backed overlay verification separate from this coordinator timing fix.

## 2026-05-22 / Overlay Centering Review Fixes

🏁 Session Handoff:
- Status: Done
- Key Decisions: Preserve the large-duration config contract by accumulating elapsed uptime across ticks and only quantizing above the subsecond-precision threshold; reset the break baseline after a successful overlay show so synchronous AppKit work does not steal visible rest time; gate hosted-test startup with `MAHU_DISABLE_APP_COORDINATOR_STARTUP=1` while keeping XCTest marker fallback; strengthen overlay tests through internal SwiftUI/AppKit seams instead of adding a third-party inspection dependency.
- Validation: `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `make build`; attempted `swiftlint` and the command was not installed in this environment.
- Friction/CDD: The review loop still expects lint evidence, but the repo has no tracked lint command and `swiftlint` is not installed here, so lint cannot be proven reproducibly yet. Live built-in-display, external-display, and fullscreen-Space overlay checks remain manual by design and should stay explicitly open in docs.
- Next Steps: Run the next external review iteration against this branch; manually verify overlay centering and background cropping on the built-in display plus an external display if available; add a tracked lint command or install `swiftlint` in the execution environment if lint remains part of the gate.

## 2026-05-22 / Timer Precision Review Fixes

🏁 Session Handoff:
- Status: Done
- Key Decisions: Reject config durations above the largest `TimeInterval` range that still preserves one-second countdown progress instead of allowing arbitrary finite doubles or reverting to the old 24-hour cap; keep README and decision history aligned with the new precision-based config contract.
- Validation: `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `make build`; `swiftlint`
- Friction/CDD: The repo still has no tracked lint command, and `swiftlint` is not installed in this environment, so this iteration can prove build/test/package success but not a repo-defined lint gate. Manual live-overlay verification on real displays/fullscreen Spaces is still pending by design.
- Next Steps: Run the next external review iteration against this branch; if lint remains part of the gate, add a tracked lint command or install `swiftlint` in the execution environment; keep the hardware-backed overlay checks open until someone records them.

## 2026-05-22 / Second Review Pass 2 Fixes

🏁 Session Handoff:
- Status: Done
- Key Decisions: Remove the accidental 24-hour config-validation cap, keep long finite `config.json` durations valid, and move overflow protection into an Int64-capped countdown formatter so the overlay stays safe without rewriting user schedules.
- Validation: `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `make build`; `swiftlint`
- Friction/CDD: The branch still has no tracked lint command, and `swiftlint` is not installed in this environment, so this iteration can prove build/test/package success but not a repo-defined lint gate. Manual live-overlay verification on real displays/fullscreen Spaces is still pending by design.
- Next Steps: Run the next external review iteration against this branch; if lint remains part of the gate, add a tracked lint command or ensure `swiftlint` is available in the execution environment; keep the hardware-backed overlay checks open until someone records them.

## 2026-05-22 / Second Review Pass Fixes

🏁 Session Handoff:
- Status: Done
- Key Decisions: Reject config durations outside `1...86_400` seconds and clamp countdown rendering to the same safe range; retry pending break presentation without consuming rest time until the overlay is actually visible; fall back to a home-derived `Library/Application Support` path if the system directory lookup returns nothing; fix the invalid-PNG test fixture so it writes into bundle resources and exercises the real decode path; move the new break-presentation retry regression into its own test file so `AppCoordinatorTests.swift` stays below the local readability threshold.
- Validation: `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `make build`; `swiftlint`
- Friction/CDD: The repo still has no tracked lint command, and `swiftlint` is not installed in this environment, so this iteration can only prove build/test green status plus the attempted-but-unavailable lint step. Manual live-overlay verification on real displays/fullscreen Spaces is still pending by design.
- Next Steps: Run the next external review iteration against this branch; manually verify that a transient display/Space transition still yields a full visible break once the overlay appears; add a tracked lint command only if future review gates require lint evidence.

## 2026-05-22 / Second Review Pass 4 Fixes

🏁 Session Handoff:
- Status: Done
- Key Decisions: Switch `AppCoordinator` and `BreakOverlayManager` teardown to `isolated deinit` so main-actor cleanup no longer depends on release happening on the right thread by accident; narrow focus-retention docs back to the shipped best-effort bounce-back contract instead of implying hidden-input blocking that the public-API approach cannot guarantee.
- Validation: `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `make build`; attempted `swiftlint` discovery via `command -v swiftlint` and the tool is still unavailable in this environment.
- Friction/CDD: The review gate still wants lint evidence, but the repo still has no tracked lint command and `swiftlint` is not installed here, so lint cannot be proven reproducibly from the repository alone. Real `Cmd+Tab` bounce-back timing, external-display hot-plug, and fullscreen-Space behavior remain manual-only by design.
- Next Steps: Let the external loop run the next review iteration; if lint remains part of the gate, add a repo-owned lint command or provide `swiftlint` in the environment; when doing manual hardware validation, treat `Cmd+Tab` typing as characterization of a best-effort race window, not as a zero-leak guarantee.

## 2026-05-22 / Review Iteration Fixes

🏁 Session Handoff:
- Status: Done
- Key Decisions: Cache the overlay background image once per `BreakOverlayView` lifetime instead of decoding it on every countdown tick; make overlay presentation return success so the coordinator retries after transient zero-display states instead of entering an invisible break; split live focus-observer coverage into a dedicated test file and add isolated resign/workspace/repeated-burst cases; archive the fully completed rendering-fix plan under `docs/plans/completed/` and point README at the superseding runtime-fix history.
- Validation: `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `make build`
- Friction/CDD: The repo still has no tracked lint command, and `swiftlint` is not installed in this environment, so this review round can only prove build/test green status. Manual live-overlay verification of the background image on real displays/fullscreen Spaces is still pending by design.
- Next Steps: Run the next external review iteration against this branch; manually verify that the background image is visibly rendered in the live overlay on at least one real display and fullscreen Space; add a tracked lint command only if future review gates require lint evidence.

## 2026-05-22 / Overlay Background Review Fixes

🏁 Session Handoff:
- Status: Done
- Key Decisions: Keep the existing hosted macOS test target for now, but strengthen the background-resource proof by decoding `background.png` in XCTest and making `make build` fail if either bundled app artifact omits the resource; archive the completed overlay-background plan under `docs/plans/completed/` and correct README plan pointers plus the full-Xcode prerequisite.
- Validation: `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `make build`
- Friction/CDD: The repo still has no tracked lint command, and `swiftlint` is not installed in this environment, so this review round can only prove build/test green status. Manual visual verification of the overlay background on real displays and fullscreen Spaces is still open.
- Next Steps: Run the next external review iteration against this branch; manually verify overlay readability/cropping on at least one real display and fullscreen Space; add a tracked lint command only if future review gates require lint evidence.

## 2026-05-21 / Sixth Review Fixes

🏁 Session Handoff:
- Status: Done
- Key Decisions: Coalesce live focus-loss notifications on the MainActor so one real app switch produces one bounce-back; simplify observer teardown to an idempotent cancellation closure instead of a protocol token; split overlay tests into focused files and expand coverage for empty-display, live-registrar, and repeated-show teardown paths.
- Validation: `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `make build`
- Friction/CDD: The repo still has no tracked lint command, and `swiftlint` is not installed in this environment, so this review round can only prove build/test green status. Real fullscreen-Space and external-display focus behavior still requires hardware-backed manual verification and remains explicitly open in the plan.
- Next Steps: Run the next external review iteration against this branch; manually verify `Cmd+Tab` typing safety, previous-app restore after both natural break end and `Skip`, and the external-display/fullscreen-Space scenarios on hardware.

## 2026-05-21 / Final External Review

🏁 Session Handoff:
- Status: Done
- Key Decisions: No new code changes were required in this round because the external review reported `NO ISSUES FOUND` and both `git diff --name-only` and `git diff --cached --name-only` were empty; record the closure in a durable handoff instead of creating an artificial fix.
- Validation: `git status --short`; `git diff --name-only`; `git diff --cached --name-only`; `git log --oneline -5`
- Friction/CDD: The review loop asked for a fix-commit even though the worktree was already clean, which creates ambiguity about whether an empty commit is acceptable. Clarify the loop contract so the final no-issue state explicitly says whether a documentation-only closure commit is expected.
- Next Steps: Let the external loop finish on this branch; if future review rounds require a final commit message for automation, document whether an empty commit or a handoff-only commit is the intended mechanism.

## 2026-05-21 / Review Fixes

🏁 Session Handoff:
- Status: Done
- Key Decisions: Reject non-positive config durations at load time and keep timer logic safe around zero-length phases; remove the user-facing Settings command so the MVP stays menu-bar-only; keep external-display verification manual in the plan instead of marking it complete from abstraction-only tests.
- Validation: `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- Friction/CDD: No tracked lint command exists in the repo, and `swiftlint` is not installed in this environment. Add an explicit lint tool/config if linting is required for future review gates. `AGENTS.md` is globally ignored, so project-specific AI notes there will not travel through commits.
- Next Steps: Run the next external review iteration against this branch; manually verify overlay behavior on a real external display and fullscreen Space, then update `docs/plans/2026-05-20-mahu-mvp.md`; decide later whether the hidden placeholder SwiftUI scene should be replaced entirely when a real settings UI plan lands.

## 2026-05-21 / Second Review Fixes

🏁 Session Handoff:
- Status: Done
- Key Decisions: Drive live ticks from monotonic awake uptime instead of assuming every callback equals one second; reject config durations below one second to block config-driven timer hangs; make overlay windows key-capable and restore the previously frontmost app when a break ends or is skipped.
- Validation: `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- Friction/CDD: The repo still has no tracked lint command, and `swiftlint` is not installed in this environment, so review validation can only prove build/test green status today. `xcodebuild` also emits an environment-level multi-destination warning for `platform=macOS`; pin a concrete destination if you want quieter CI logs.
- Next Steps: Run the next external review iteration against this branch; manually verify that focus returns to the working app after real break dismissal on hardware; keep the external-display/fullscreen-Space manual checks open until they are executed and documented.

## 2026-05-21 / Third Review Fixes

🏁 Session Handoff:
- Status: Done
- Key Decisions: Reset the uptime baseline when `Skip` ends a break so the next work interval starts from the actual skip moment; split `AppCoordinator` test support out of the 300+ line test file before adding another regression case.
- Validation: `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- Friction/CDD: The repo still has no tracked lint command, and `swiftlint` is not installed in this environment, so validation remains limited to build/test evidence. Multi-display and fullscreen-Space overlay behavior still require hardware-backed manual verification and remain intentionally open in the plan.
- Next Steps: Run the next external review iteration against this branch; manually verify multi-display/fullscreen-Space overlay behavior on hardware; if a lint gate is expected in future review loops, add a tracked lint command/config to the repo first.

## 2026-05-21 / Fourth Review Fixes

🏁 Session Handoff:
- Status: Done
- Key Decisions: Stop delayed work-phase ticks at the work-to-break boundary so rest time never disappears before the overlay is visible; keep `BreakTimer.advance(by:)` collapsing zero-length phases even with zero consumed delta so coordinator edge cases stay deterministic in tests.
- Validation: `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- Friction/CDD: The repo still has no tracked lint command, and `swiftlint` is not installed in this environment, so validation can only prove build/test green status. Multi-display and fullscreen-Space overlay behavior still require hardware-backed manual verification and remain intentionally open in the plan.
- Next Steps: Run the next external review iteration against this branch; manually verify external-display/fullscreen-Space overlay behavior on hardware; if a lint gate is expected in future review loops, add a tracked lint command/config first.

## 2026-05-21 / Fifth Review Fixes

🏁 Session Handoff:
- Status: Done
- Key Decisions: Keep the hosted macOS test target for now, but block `AppDelegate` from starting the production coordinator under XCTest so review validation no longer creates real menu-bar/timer/config side effects.
- Validation: `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `HOME="$(mktemp -d)" xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO` followed by checking that `~/Library/Application Support/Mahu/config.json` was not created
- Friction/CDD: The repo still has no tracked lint command, and `swiftlint` is not installed in this environment, so this review gate can only prove build/test green status. The XCTest runtime guard depends on standard XCTest environment markers; if the project later adopts a nonstandard hosted runner, that launch path should be revalidated explicitly.
- Next Steps: Run the next external review iteration against this branch; if hosted integration/UI tests are added later, give them an explicit opt-in startup path instead of removing the XCTest guard; keep manual external-display/fullscreen-Space verification open until hardware validation is recorded.

## 2026-05-23 / Review Fixes

🏁 Session Handoff:
- Status: Done
- Key Decisions: Guard `BreakTimer.advance(by:)` against non-finite elapsed time; bound `config.json` reads to 64 KiB via chunked `FileHandle` loading before decode; add `PrivacyInfo.xcprivacy` for `ProcessInfo.processInfo.systemUptime` with Apple’s `NSPrivacyAccessedAPICategorySystemBootTime` reason `35F9.1`; replace fake overlay/status-item assertions with structured SwiftUI view-tree checks, accessibility identifiers, and a real menu-bar-only smoke check; archive the completed tray-icon plan and narrow README wording to the zero-display retry contract the code actually enforces.
- Validation: `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `make build`
- Friction/CDD: The review workflow still asks for lint evidence, but the repo has no tracked lint target and `swiftlint` is not installed here, so lint cannot be proven reproducibly from repository-owned tooling alone. `xcodebuild` continues to emit the environment-level multi-destination warning for `platform=macOS`; pinning a concrete destination would make local and CI logs quieter.
- Next Steps: Run the next external review iteration against this branch; if lint remains part of the gate, add a repo-owned lint command or provision `swiftlint` in the execution environment; keep tray-icon appearance, fullscreen Space behavior, and external-display verification as explicit manual checks.

## 2026-05-23 / Second Review Pass 2 Fixes

🏁 Session Handoff:
- Status: Done
- Key Decisions: Treat `config.json` as valid only when it is a regular file or a symlink resolving to one, keep filesystem error details private in OSLog, pause active-break countdown consumption while every display is unavailable, preserve the same shared overlay state across zero-display snapshots, and move display reconciliation into `BreakOverlaySupport.swift` so `BreakOverlayManager.swift` drops back under the local readability threshold.
- Validation: `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `make build`; attempted `command -v swiftlint` and the command is not available in this environment.
- Friction/CDD: The review gate still implies lint proof, but the repo still has no tracked lint command and `swiftlint` is not installed here, so lint cannot be validated reproducibly from repository-owned tooling. Real monitor/fullscreen-Space behavior remains manual-only even though the zero-display retry/pause contract is now covered by XCTest.
- Next Steps: Run the next external review iteration against this branch; if lint remains part of the gate, add a repo-owned lint command or provide `swiftlint` in the environment; manually verify a real monitor or fullscreen-Space transition that temporarily produces zero active displays.

## 2026-05-25 / Review Fixes

🏁 Session Handoff:
- Status: Done
- Key Decisions: Account active-break time at overlay visibility transitions so zero-display gaps that begin and end between timer ticks no longer consume hidden rest time; make `makeTrayTemplateStatusIcon(bundle:)` actually resolve images from the supplied bundle and prove it with custom-bundle tests; archive the fully completed transparent tray-glyph plan under `docs/plans/completed/` and sync README with the config-file and plan-status contracts already implemented in code.
- Validation: `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `make build`; attempted `command -v swiftlint` and the command is still unavailable in this environment.
- Friction/CDD: The review gate still implies lint proof, but the repo still has no tracked lint command and `swiftlint` is not installed here, so lint cannot be validated reproducibly from repository-owned tooling. Real tray-icon readability and fullscreen-Space/external-display behavior remain manual-only despite stronger deterministic coverage.
- Next Steps: Let the external review loop run again; if lint remains required, add a repo-owned lint command or install `swiftlint` in the execution environment; keep manual checks for tray readability and real display transitions open until someone records hardware-backed evidence.

## 2026-05-28 / Reminder Pause Review Fixes

🏁 Session Handoff:
- Status: Done
- Key Decisions: Reuse the config snapshot loaded during `AppCoordinator.start()` when `Resume Reminders` resets a work interval, so pause/resume does not become hidden live config reload; treat tray pause/resume interactions during an active break as menu-state-only so repeated pause/resume cannot extend the current break; collapse reminder-menu acceptance checks into a dedicated small test file that exercises the real `configureReminderActions(...)` path instead of growing `StatusItemControllerTests.swift` further.
- Validation: `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `make build`; attempted `command -v swiftlint` and the command is not available in this environment.
- Friction/CDD: The review workflow still asks for lint evidence, but the repo still has no tracked lint command and `swiftlint` is unavailable here, so lint cannot be validated reproducibly from repository-owned tooling. Manual hardware checks for real active-break tray interaction, fullscreen Spaces, and external-display behavior remain open by design.
- Next Steps: Let the external review loop run again from this commit; if lint stays part of the gate, add a repo-owned lint command or provide `swiftlint` in the environment; when doing manual verification, explicitly test toggling `Pause Reminders` / `Resume Reminders` during an active break and record whether countdown/`Skip` stay unchanged on real hardware.
