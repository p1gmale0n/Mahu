# Decision History

| Date | Area | Decision | Rationale |
| --- | --- | --- | --- |
| 2026-05-20 | Agent instructions | Keep `AGENTS.md` compact and omit unverifiable build/test commands until project manifests exist. | At the time of the decision, the repository had no app sources, manifests, README, or CI; speculative commands would mislead future agents. |
| 2026-05-20 | Documentation | Keep a basic README as the human-facing project overview and update it with behavior, setup, structure, and verification changes. | The user wants README to stay current, and future agents need a stable source for project status without reading only agent instructions. |
| 2026-05-20 | MVP scope | Build the first version around 20-20-20 defaults, icon-only status menu with Quit, config-file settings, fullscreen break overlay, countdown, and Skip. | This keeps the first implementation small while preserving extension seams for settings UI, launch at login, sleep/wake handling, and App Store release work. |
| 2026-05-20 | Project shape and config | Use a modern Xcode macOS app shape with SwiftUI lifecycle plus AppKit interop, and store config in `~/Library/Application Support/Mahu/config.json` with default fallback. | This follows macOS conventions while keeping the MVP simple and resilient to missing or broken user-edited config. |
| 2026-05-20 | Development workflow | Treat OpenCode sessions as planning/review by default; execute implementation separately with `ralphex` unless the user explicitly asks for edits. | This preserves the user's chosen development pattern and prevents agents from changing files when the expected output is a plan or task prompt. |
| 2026-05-20 | MVP implementation plan | Plan MVP implementation as a standard Xcode app target with focused modules and regular code-first tasks that still require tests before each next task. | This fits the `ralphex` execution workflow while keeping the plan small, verifiable, and App Store-aware. |
| 2026-05-20 | Project bootstrap | Hand-author the initial Xcode project files instead of introducing a project generator dependency. | The environment had Xcode but no `xcodegen` or `tuist`; a small checked-in project keeps bootstrap deterministic and lets later tasks use `xcodebuild` immediately. |
| 2026-05-20 | Config storage | Implement config loading through an injectable `ConfigStore` that resolves the real Application Support path in production and a temporary directory in tests. | The MVP needs the canonical `~/Library/Application Support/Mahu/config.json` location, but deterministic unit tests should not touch the real user config. |
| 2026-05-20 | App lifecycle | Start the work timer from a small `AppCoordinator` that loads config once and drives `BreakTimer` with a simple repeating scheduler, while keeping `NSStatusItem` ownership in a separate AppKit controller. | Task 4 needs an auto-starting menu-bar app now, but overlay wiring belongs to a later task; this keeps AppKit side effects at the edges and leaves timer flow testable without a real status bar. |
| 2026-05-20 | Break overlay | Model the break overlay as a shared `BreakOverlayViewModel` plus a `BreakOverlayManager` that takes injectable screen/window collaborators for tests and owns live `NSWindow` creation at the AppKit edge. | Task 5 needs real fullscreen overlay windows on every display, but deterministic tests should verify countdown, skip, and one-window-per-display behavior without opening AppKit windows. |
| 2026-05-20 | MVP wiring | Let `AppCoordinator` own status-item installation, config loading, timer ticks, and overlay show/hide/update transitions through small injected protocols. | Task 6 needs the full MVP flow without pushing AppKit side effects back into `AppDelegate` or making coordinator tests depend on real windows or status bar state. |
| 2026-05-21 | Documentation and verification | Record exact `xcodebuild` build/test commands in `README.md` and `AGENTS.md`, and explicitly keep real display and fullscreen-Space checks as manual validation. | The app now has a real Xcode project, so future agents need verified commands instead of bootstrap placeholders, while some overlay behavior still cannot be proven in this headless environment. |
| 2026-05-21 | Config resilience | Treat non-positive config durations as invalid input, keep using defaults on malformed/unreadable config, and log unexpected filesystem failures before falling back. | The config file is the MVP settings surface, so resilience cannot stop at syntax-only validation; bad values or unreadable paths must not crash or silently wedge the timer state machine. |
| 2026-05-21 | App scene surface | Keep the minimal SwiftUI scene needed for startup, but remove the user-facing Settings command until a real settings UI exists. | The MVP must remain menu-bar-only; an empty Settings window is still a user-visible feature outside scope. |
| 2026-05-21 | Verification truthfulness | Keep multi-display manual validation explicitly incomplete in the plan until someone runs it on real hardware. | The abstraction-level overlay tests do not prove fullscreen Space or external-display behavior, so marking those checks complete would overstate acceptance evidence. |
| 2026-05-21 | Runtime hardening | Drive live timer ticks from monotonic awake uptime, require config durations of at least one second, and make overlay windows key-capable while restoring the previous frontmost app after breaks. | The review found runtime drift, config-driven freeze potential, and focus/interactivity bugs that all live in the MVP hot path and should be fixed without expanding into full sleep/wake reconciliation. |
| 2026-05-21 | Break transition integrity | Stop delayed work ticks at the work-to-break boundary so Mahu never spends unseen break time before the overlay is visible. | A large main-run-loop delay could otherwise consume some or all of the rest phase before the user ever sees it, including the worst case where the break is skipped entirely. |

## 2026-05-20 / Agent Instructions

**Date:** 2026-05-20

**Area:** Agent instructions

**Context:** At the time of the decision, the repository contained only `.memsearch/`; product constraints were provided by the user.

**Decision:** Create a compact `AGENTS.md` from user-provided Mahu requirements and explicitly avoid inventing build/test commands.

**Rationale:** Future agents need product invariants and implementation constraints, but unverified commands would create false confidence.

**Consequences:** Build, test, lint, and signing commands must be added after `Package.swift`, `.xcodeproj`, `.xcworkspace`, or CI config exists.

**Alternatives Considered:** Add generic Swift/Xcode commands; rejected because they are not verified in this repo.

## 2026-05-20 / Documentation

**Date:** 2026-05-20

**Area:** Documentation

**Context:** The project is still in bootstrap state, but needs a human-facing README with current purpose, constraints, and status.

**Decision:** Create `README.md` as the project overview and require updates when app behavior, structure, setup steps, or verification commands change.

**Rationale:** `AGENTS.md` is for agent operating guidance; README should remain the compact public project entrypoint.

**Consequences:** Future implementation changes that affect behavior or commands should update README in the same patch.

**Alternatives Considered:** Keep project information only in `AGENTS.md`; rejected because that file is agent-specific and not the right human-facing source.

## 2026-05-20 / MVP Scope

**Date:** 2026-05-20

**Area:** MVP scope

**Context:** The user clarified initial product behavior and explicitly deferred convenience features.

**Decision:** Use 20-20-20 defaults, allow skipping a break, keep settings in a manually editable config file, make the status item icon-only with a `Quit` menu action, and keep launch at login, settings UI, status countdown, sleep/wake reconciliation, and App Store packaging work as deferred features.

**Rationale:** The MVP should validate the core break-reminder behavior before adding UI and lifecycle complexity.

**Consequences:** The implementation should keep timer, config, status item, and overlay responsibilities separated so deferred features can be added without rewriting the core flow.

**Alternatives Considered:** Build settings UI, status countdown, and launch-at-login in the MVP; rejected to keep the first implementation focused on the core overlay behavior.

## 2026-05-20 / Project Shape and Config

**Date:** 2026-05-20

**Area:** Project shape and config

**Context:** The user does not have a strong project-format preference and asked to use current Apple/macOS conventions. The user also wants to manually edit the MVP config.

**Decision:** Use a standard modern Xcode macOS app shape with SwiftUI app lifecycle and AppKit interop for menu-bar and overlay behavior. Store config at `~/Library/Application Support/Mahu/config.json` with work and break durations in seconds.

**Rationale:** Xcode app targets are the normal path for a native macOS app and App Store packaging. Application Support is the conventional writable per-user location for app-owned configuration.

**Consequences:** Config loading must create a default file when missing and fall back to 20-20-20 defaults when invalid, without blocking the app.

**Alternatives Considered:** Use only a Swift package; rejected because app bundle metadata, Info.plist behavior, signing, and future App Store workflow fit Xcode targets better.

## 2026-05-20 / Development Workflow

**Date:** 2026-05-20

**Area:** Development workflow

**Context:** The user clarified that this chat is primarily for discussing and planning implementation, while actual implementation is performed separately with `ralphex`.

**Decision:** Future OpenCode sessions should default to planning, task prompts, reviews, and debugging guidance. Agents must not create, edit, or delete project files unless the user explicitly asks for repository changes in the current message.

**Rationale:** This keeps the workflow aligned with the user's chosen execution tool and avoids unintended repo mutations from planning conversations.

**Consequences:** When implementation is needed, produce clear `ralphex` tasks or plans unless the user explicitly delegates direct editing to OpenCode.

**Alternatives Considered:** Let OpenCode implement by default; rejected because it conflicts with the intended `ralphex`-driven development pattern.

## 2026-05-20 / MVP Implementation Plan

**Date:** 2026-05-20

**Area:** MVP implementation plan

**Context:** The user asked for an interactive implementation plan for the Mahu MVP, intended for later execution with `ralphex`.

**Decision:** Create `docs/plans/2026-05-20-mahu-mvp.md` using the recommended Xcode app target approach, focused module boundaries, and regular code-first implementation with tests required inside every task.

**Rationale:** The project has no executable manifest yet, so the plan must bootstrap the app first, then require verification and documentation updates as soon as commands become real.

**Consequences:** `ralphex` should execute the plan task-by-task, update checkboxes immediately, and add exact build/test commands to `README.md` and `AGENTS.md` after the Xcode project exists.

**Alternatives Considered:** Swift Package first or UI prototype first; rejected because they either add setup overhead or increase the chance of rewriting timer/config/overlay seams.

## 2026-05-20 / Project Bootstrap

**Date:** 2026-05-20

**Area:** Project bootstrap

**Context:** Task 1 required a real macOS Xcode app target with tests, but the environment did not include `xcodegen` or `tuist`.

**Decision:** Create and commit the initial `Mahu.xcodeproj`, scheme, app sources, and test target directly in the repository instead of adding a new generation tool.

**Rationale:** A hand-authored minimal project keeps the bootstrap small, avoids adding tooling before the app exists, and immediately enables verified `xcodebuild` commands for the next tasks.

**Consequences:** Future structural project changes must edit checked-in Xcode project files directly unless the team later adopts a generator intentionally.

**Alternatives Considered:** Add `xcodegen` or `tuist`; rejected because introducing and documenting a new project-generation dependency would add more moving parts than the MVP bootstrap needs.

## 2026-05-20 / Config Storage

**Date:** 2026-05-20

**Area:** Config storage

**Context:** Task 2 required reading and creating `~/Library/Application Support/Mahu/config.json` while also adding unit tests for missing-file creation, valid custom JSON, and invalid JSON fallback.

**Decision:** Implement `ConfigStore` as a small Foundation-based type with an injectable base Application Support directory, defaulting to the real user directory in production and allowing tests to substitute a temporary directory.

**Rationale:** This preserves the required production path without making tests mutate the real user environment or rely on brittle filesystem cleanup.

**Consequences:** Future config-related tests can stay fast and deterministic; app wiring can construct `ConfigStore()` with defaults and get the correct macOS path automatically.

**Alternatives Considered:** Hardcode the real home-directory path everywhere or mock filesystem behavior more heavily; rejected because the first risks touching real user data during tests and the second adds unnecessary abstraction for the MVP.

## 2026-05-20 / App Lifecycle

**Date:** 2026-05-20

**Area:** App lifecycle

**Context:** Task 4 needs the menu-bar app to install its status item and start the work timer automatically, but overlay presentation is still deferred to later tasks.

**Decision:** Introduce a small `AppCoordinator` that loads config once, creates the timer, and advances it through a simple repeating scheduler. Keep `NSStatusItem` setup in a separate `StatusItemController` owned by `AppDelegate`.

**Rationale:** This delivers the MVP launch behavior without coupling timer startup to AppKit menu code or pre-emptively mixing in overlay concerns.

**Consequences:** Timer startup remains unit-testable with fake schedulers and fake timers, while later overlay wiring can subscribe to timer phase changes without rewriting the menu-bar bootstrap.

**Alternatives Considered:** Start `Foundation.Timer` directly inside `AppDelegate` or inside `StatusItemController`; rejected because both options mix lifecycle, menu-bar UI, and timer progression into harder-to-test AppKit types.

## 2026-05-20 / Timer State Machine

**Date:** 2026-05-20

**Area:** Timer state machine

**Context:** Task 3 requires a deterministic work/rest timer with unit tests, but the overlay windows and menu-bar lifecycle are not wired yet.

**Decision:** Implement `BreakTimer` as a pure Foundation-backed state machine with explicit `advance(by:)` and `skipBreak()` methods instead of binding it to `Timer` or AppKit lifecycle APIs now.

**Rationale:** Manual time advancement keeps the core timer logic deterministic in tests, isolates countdown/phase transitions from UI side effects, and leaves Task 4/6 free to decide how real clock ticks are delivered.

**Consequences:** Later app-coordinator code can drive the timer from a scheduled publisher or AppKit timer without rewriting transition logic, and unit tests can cover short-duration edge cases without sleeps.

**Alternatives Considered:** Couple the first implementation directly to `Foundation.Timer`; rejected because it would make phase-transition tests slower, more brittle, and harder to run without the app lifecycle.

## 2026-05-20 / Break Overlay

**Date:** 2026-05-20

**Area:** Break overlay

**Context:** Task 5 requires a fullscreen break overlay on every active display, a visible countdown and Skip action, and automated tests that avoid opening real AppKit windows.

**Decision:** Implement a shared `BreakOverlayViewModel` for countdown and Skip behavior, and a `BreakOverlayManager` that creates one borderless `NSWindow` per active display through injectable screen/window collaborators. The live window builder sets `NSWindow.Level.screenSaver`, uses `makeKeyAndOrderFront(nil)`, and activates the app after showing the windows.

**Rationale:** This keeps window ownership and AppKit side effects at the edge while preserving deterministic tests for countdown formatting, skip handling, and one-window-per-display behavior.

**Consequences:** Task 6 can wire timer-state changes into `showBreak`, `updateRemainingSeconds`, and `hideBreak` without redesigning the overlay layer, but fullscreen Spaces and hot-plug edge cases remain deferred hardening work.

**Alternatives Considered:** Drive overlay state directly from `AppCoordinator` with raw `NSWindow` instances or test only through manual UI checks; rejected because both approaches would make Skip/countdown behavior harder to verify automatically.

## 2026-05-20 / MVP Wiring

**Date:** 2026-05-20

**Area:** MVP wiring

**Context:** Task 6 requires one coordinator to connect status-item setup, config loading, timer state transitions, and overlay presentation, while keeping the app resilient to missing or invalid config and preserving deterministic tests.

**Decision:** Move status-item installation into `AppCoordinator.start()`, make the coordinator own overlay show/update/hide decisions, and interact with the timer, status item, and overlay through small protocols that can be replaced with fakes in unit tests.

**Rationale:** This keeps `AppDelegate` minimal, centralizes MVP flow orchestration in one place, and allows coordinator tests to cover launch, break start, break completion, and skip without real AppKit windows or status-bar state.

**Consequences:** The coordinator now becomes the single wiring point for MVP runtime flow, while deferred features still stay out of scope because they are not added to the status menu, timer API, or overlay contract.

**Alternatives Considered:** Keep status-item setup in `AppDelegate` and only wire overlay from the coordinator, or let AppKit types talk directly to each other; rejected because both options spread lifecycle logic across more files and weaken automated verification of the end-to-end timer flow.

## 2026-05-21 / Documentation and Verification

**Date:** 2026-05-21

**Area:** Documentation and verification

**Context:** Task 8 requires replacing bootstrap-era documentation with the actual project structure and exact verification commands now that `Mahu.xcodeproj`, app sources, and tests exist.

**Decision:** Document the verified `xcodebuild build` and `xcodebuild test` commands in both `README.md` and `AGENTS.md`, and keep external-display/fullscreen-Space behavior explicitly listed as manual checks instead of overstating automation coverage.

**Rationale:** Future agents and humans need deterministic local commands for proof of correctness, but this environment still cannot fully validate real multi-display AppKit behavior.

**Consequences:** Documentation now matches the executable project state, and remaining risk is isolated to manual UI verification rather than hidden behind incomplete automation.

**Alternatives Considered:** Keep only one documented command location or present overlay checks as fully automated; rejected because it would either fragment project guidance or misrepresent current verification limits.

## 2026-05-21 / Config Resilience

**Date:** 2026-05-21

**Area:** Config resilience

**Context:** Review of the MVP branch found that `ConfigStore` accepted zero or negative durations from the hand-edited `config.json`, while `BreakTimer` could livelock or surface a `00:00` break if those values reached the state machine.

**Decision:** Treat non-positive config durations as invalid input, continue using defaults for malformed or unreadable config, and log unexpected filesystem failures before falling back.

**Rationale:** The config file is the only MVP settings surface, so resilience must cover semantic validation and not just JSON syntax; otherwise a single bad edit can wedge timer flow or silently discard user intent.

**Consequences:** Production config loading now rejects broken duration values before timer construction, while filesystem failures still keep the app alive but leave a diagnostic trail for future debugging.

**Alternatives Considered:** Clamp invalid durations inside `BreakTimer` only or crash on config errors; rejected because clamping still produces surprising behavior and crashing violates the documented fallback contract.

## 2026-05-21 / App Scene Surface

**Date:** 2026-05-21

**Area:** App scene surface

**Context:** The initial SwiftUI app entrypoint used a placeholder `Settings` scene, which exposed an empty Settings window through the app menu even though settings UI is explicitly deferred for the MVP.

**Decision:** Keep the minimal SwiftUI scene required for app startup, but remove the user-facing Settings command until a real settings UI exists.

**Rationale:** This preserves the lightweight SwiftUI lifecycle bridge while keeping the shipped MVP surface aligned with the menu-bar-only requirement.

**Consequences:** The app still starts through the SwiftUI lifecycle and `AppDelegate`, but users can no longer open an empty Settings window via `Cmd+,` or the app menu.

**Alternatives Considered:** Replace the scene structure entirely with a different app bootstrap or leave the placeholder Settings window accessible; rejected because the first adds needless churn and the second violates scope.

## 2026-05-21 / Verification Truthfulness

**Date:** 2026-05-21

**Area:** Verification truthfulness

**Context:** The implementation plan had marked multi-display overlay verification complete even though the same plan still deferred real external-display and fullscreen-Space checks to manual follow-up.

**Decision:** Keep multi-display manual validation explicitly incomplete in the plan until someone runs it on real hardware, while documenting that automated coverage only proves the abstraction-level one-window-per-display path.

**Rationale:** Acceptance evidence should reflect what was actually verified, not what is only indirectly implied by unit tests.

**Consequences:** The plan now stays honest about remaining manual work, and future agents will not misread the branch as having already passed real multi-display validation.

**Alternatives Considered:** Leave the checkbox marked complete with a caveat or remove the manual follow-up entirely; rejected because both options blur the distinction between automated and manual proof.

## 2026-05-21 / Runtime Hardening

**Date:** 2026-05-21

**Area:** Runtime hardening

**Context:** Second-pass review found three hot-path runtime issues in the shipped MVP: the live coordinator assumed every timer callback represented exactly one second of awake time, the hand-edited config accepted subsecond durations that could force pathological phase-transition loops, and the overlay used non-key-capable borderless windows without restoring the previously frontmost app after the break.

**Decision:** Measure live tick deltas with `ProcessInfo.processInfo.systemUptime`, treat config durations below one second as invalid fallback cases, and show the overlay through a key-capable window subclass while capturing/restoring the previously frontmost app around break presentation.

**Rationale:** `systemUptime` tracks elapsed awake time without silently implementing deferred sleep/wake reconciliation, minimum one-second config validation blocks the only practical config-driven hang path, and the overlay changes make `Skip` reliably interactive while returning the user to the app they were using before the break.

**Consequences:** The MVP timer now resists run-loop drift during awake operation, malformed-but-decodable config values no longer create availability issues, and break dismissal no longer leaves Mahu frontmost with no visible window; real multi-display/manual hardware verification still remains a separate follow-up.

**Alternatives Considered:** Keep fixed one-second logical ticks, optimize `BreakTimer.advance(by:)` for arbitrarily tiny durations, or leave focus restoration to AppKit defaults; rejected because those paths either preserve known correctness bugs or depend on platform behavior that is too weak for the menu-bar-only UX.

## 2026-05-21 / Skip Timing Integrity

**Date:** 2026-05-21

**Area:** Timer coordination

**Context:** Follow-up review found that `AppCoordinator` reused the previous scheduled-tick uptime after a manual `Skip`, so the next work tick could subtract pre-skip break time from the new work interval whenever the user skipped between scheduler callbacks.

**Decision:** Reset the coordinator's `lastTickUptime` to the current monotonic uptime at the moment `Skip` transitions back to work, and keep a regression test that injects delayed uptime values around the skip path.

**Rationale:** Manual phase changes are not equivalent to scheduled timer ticks; the next work interval must measure elapsed time from the user's skip action, not from the last callback that happened while the break was still active.

**Consequences:** The post-skip work interval now starts with the full configured duration even when the main run loop is delayed, and the regression stays covered without pulling timing concerns into `BreakTimer`.

**Alternatives Considered:** Leave the small drift in place or clamp it inside `BreakTimer`; rejected because the bug lives in coordinator-owned uptime bookkeeping and would still violate the documented 20-20-20 flow on a common user path.

## 2026-05-21 / Break Transition Integrity

**Date:** 2026-05-21

**Area:** Break transition integrity

**Context:** A later review found that `AppCoordinator` always advanced `BreakTimer` by the full accumulated awake-time delta. If the main run loop was delayed past the end of the work phase, the timer could spend hidden rest time before any overlay appeared, and with a large enough delay it could skip the break entirely.

**Decision:** When the live timer is still in `.work`, cap each consumed delta at the remaining work time so the coordinator stops exactly at break entry, shows the overlay, and only starts consuming break time on later ticks. Keep `BreakTimer.advance(by:)` able to collapse zero-length phases even when the consumed delta is zero so edge-state tests remain deterministic.

**Rationale:** A break has not started from the user's perspective until the overlay is visible; burning that time off-screen violates the core MVP contract more severely than discarding overdue time after a delayed work tick.

**Consequences:** Delayed ticks now start a full visible break instead of silently shortening or skipping it, uptime-based work accounting remains intact during the work phase, and the regression is locked down with coordinator coverage.

**Alternatives Considered:** Keep consuming the full elapsed delta, clamp every tick to one second, or rely on config validation alone; rejected because those options either preserve the skip-break bug or reintroduce the awake-time drift fixed in the previous review.

## 2026-05-21 / Hosted Test Isolation

**Date:** 2026-05-21

**Area:** Test isolation

**Context:** The macOS unit-test target is configured as a hosted bundle, so every `xcodebuild test` launches the app binary. Without a guard, `AppDelegate` immediately started the production coordinator during tests, which could create a real status item, schedule a live timer, and touch the user's config file in `~/Library/Application Support/Mahu`.

**Decision:** Keep the current hosted test target, but add an explicit XCTest runtime guard in `AppDelegate` so production startup is skipped whenever the app binary runs under unit tests, and cover the detector with a regression test.

**Rationale:** This removes the verified test-side effect risk with a small local change, without broadening the review fix into Xcode target surgery that is not required to stop the current leak.

**Consequences:** Test runs no longer initialize the live coordinator path or mutate real user state through app launch side effects; if the project later adds real hosted integration/UI tests, they will need a separate opt-in path instead of relying on default launch behavior.

**Alternatives Considered:** Convert `MahuTests` into an unhosted logic test target immediately, or leave the hosted setup in place and accept the side effects; rejected because the first is a wider project-configuration change than needed for this review fix and the second preserves a real isolation bug.
