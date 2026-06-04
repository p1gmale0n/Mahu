# Decision History

| Date | Area | Decision | Rationale |
| --- | --- | --- | --- |
| 2026-06-04 | Config JSONC preprocessor shape | Implement JSONC tolerance as a small in-repo scanner that strips comments first and then removes trailing commas in a second pass. | This keeps the behavior string-safe and testable without regex corruption risks or prematurely expanding `ConfigStore.swift`. |
| 2026-06-04 | Config JSONC tolerance | Keep `config.json` as the persisted format, tolerate JSONC-style comments and trailing commas on read, and continue writing strict JSON. | The config is currently user-edited and Zed can insert JSONC comments, but migrating to YAML or adding a parser dependency would add more complexity than needed before the future Settings UI. |
| 2026-06-03 | Break overlay dormant-session recovery | Preserve a dormant break session even when break start finds zero active displays, and materialize windows later from screen-change events instead of retrying with a new session. | Review found that the zero-display start path dropped session state, delayed recovery until the next tick, and could recapture the wrong previous app once displays returned. |
| 2026-06-03 | Config write durability sync | Fsync the managed Mahu config directory after `renameat`, and fsync the parent directory too when the Mahu directory was created in the same write. | Review found that atomic temp-file replacement still reported success before the directory entries themselves were durable across crash or power loss. |
| 2026-06-03 | Config write TOCTOU hardening | Write config/default files through directory file descriptors and atomic `renameat` instead of path-based preflight plus `Data.write`. | Review found that symlink checks in `ConfigStore` were still racy between validation and the eventual write path. |
| 2026-06-03 | Status item main-actor contract | Mark the status-item protocol, implementation, and test doubles as `@MainActor`. | Review found that AppKit menu-bar state was only implicitly main-threaded, leaving future background calls compiler-unchecked. |
| 2026-06-03 | Sleep/wake wall-clock seam removal | Remove the unused `currentWallClockDate` seam from `AppCoordinator` and its tests. | After long-sleep measurement moved to a sleep-aware monotonic clock, the leftover wall-clock injection only created misleading API and test plumbing. |
| 2026-06-03 | Launch at Login thrown-error final status reporting | After `register()` or `unregister()` throws, re-read the final Login Item status and report that end state with the appropriate warning. | Review found that thrown ServiceManagement paths could log stale pre-mutation status even when macOS had already moved into a different end state. |
| 2026-06-03 | Config directory symlink hardening | Refuse config load/save when `~/Library/Application Support/Mahu` itself is a symbolic link or another non-directory object. | Review found that guarding only `config.json` left a parent-directory symlink path that still wrote or read outside the intended Mahu config location. |
| 2026-06-03 | Sleep/wake long-sleep measurement | Measure recorded sleep duration from a sleep-inclusive monotonic source rather than wall-clock `Date`. | Review found that wall-clock sleep classification can be corrupted by NTP, timezone, or manual clock changes during sleep, which breaks the `>= 300s` reset contract. |
| 2026-06-03 | Paused status-item icon readability | Dim only the status-item icon image during paused reminders and keep the button/title at full opacity. | Review found that dimming the whole `NSStatusBarButton` also dimmed timer text and `Paused`, violating the tray readability contract during timer mode and active breaks. |
| 2026-06-03 | Config save symlink hardening | Refuse `ConfigStore.save(_:)` when `~/Library/Application Support/Mahu/config.json` is a symbolic link, while still allowing symlink-based reads. | Review found that preserving symlinks on save created a local file-overwrite primitive outside the Mahu config directory, which is a worse outcome than losing shared-dotfile-style write-through support. |
| 2026-06-03 | Launch at Login runtime source of truth | Keep `RuntimeSettingsStore` as the authoritative in-process settings source and propagate `launchAtLoginEnabled` changes through the dedicated launch-at-login store/controller on runtime updates. | Second-pass review found that startup-only launch-at-login sync left runtime-edited desired state stale in memory, violating the documented single-source-of-truth invariant for future Settings UI work. |
| 2026-06-03 | Launch at Login review hardening | Validate the final Login Item status after register/unregister and treat any post-mutation mismatch as a non-fatal warning instead of silent success. | Review found that the startup sync could report success even when `SMAppService` still ended in the wrong state after a mutation, which hides real launch-at-login drift from logs and tests. |
| 2026-06-03 | Sleep-entry break-completion silence | Keep `willSleep` awake-time settlement silent even if that accounting crosses `rest -> work` before the later long-sleep reset. | The shipped long-sleep active-rest contract requires silent teardown/reset, and review found that sleep-entry accounting could otherwise trigger the natural completion sound in the last-second boundary window. |
| 2026-06-03 | Launch at Login documentation contract | Document launch-at-login as a shipped config-backed startup reconciliation feature, keep manual config edits launch-loaded only, and leave signed Login Item verification manual-only. | Task 6 needs README and AGENTS to match the implemented `launchAtLoginEnabled` behavior so future agents do not treat the feature as deferred, imply live reload, or overstate unsigned automated proof. |
| 2026-06-03 | Launch at Login coordinator startup wiring | Seed a dedicated launch-at-login desired-state store from startup config inside `AppCoordinator` and sync it once through an injected controller seam, treating sync warnings as log-only and non-fatal. | Task 4 needs startup reconciliation that follows config-backed intent without putting `SMAppService` calls in coordinator code or letting registration failures block normal timer/status-item startup. |
| 2026-06-03 | Launch at Login sync policy | Keep `SMAppService` behind a small manager adapter and make a controller return structured sync results with non-fatal warnings for `requiresApproval`, unavailable status, and register/unregister failures. | Task 3 needs deterministic policy tests and startup-safe diagnostics without exposing ServiceManagement enums to coordinator/config code or retrying registration forever when macOS still needs user approval. |
| 2026-06-03 | Launch at Login desired-state store | Model launch-at-login intent as a dedicated `@MainActor` Bool store with observer callbacks and no filesystem or ServiceManagement dependency. | Task 2 needs a reusable in-memory seam for startup config seeding and future Settings UI updates without conflating desired state with actual macOS Login Item status or expanding `AppCoordinatorSupport.swift`. |
| 2026-06-03 | Launch at Login config architecture | Plan launch-at-login as config-backed desired state through a dedicated settings store and ServiceManagement controller, with no status-menu item in the MVP. | This preserves the current manual-config workflow while creating a reusable seam for the future Settings UI without putting `SMAppService` logic into `AppCoordinator` or treating config as actual macOS Login Item state. |
| 2026-06-03 | Launch at Login config contract | Add `launchAtLoginEnabled: Bool` to `AppConfig`, default it to `false`, decode a missing key as `false`, and keep invalid or `null` values on the existing whole-config fallback path. | The launch-at-login feature needs backward-compatible manual-config behavior that matches Mahu's established malformed-config recovery semantics without introducing a second decoding rule. |
| 2026-06-03 | External review artifact hygiene | Ignore the external review loop's root `output.txt` scratch file and treat clean no-issue closures as documentation-only close-out, not product diffs. | Clean review passes currently leave an untracked repo-root artifact even when the tracked tree is correct, which makes the final commit step ambiguous and noisy. |
| 2026-06-03 | Sleep/wake cancellation synchronization | Replace the live sleep/wake registrar's shared cancellation `Bool` with a synchronized cancellation state object. | The follow-up review found that the shared mutable local flag was touched from observer callbacks and teardown concurrently, which could reintroduce lifecycle races or Swift exclusivity issues after the earlier synchronous-delivery fix. |
| 2026-06-03 | Break overlay startup retry preservation | Keep the current break session state alive when startup-time display resync temporarily leaves zero overlay windows, so the next retry reuses the original previous-app capture. | The review found that the zero-window startup path tore down the entire session and lost the pre-break app capture, violating the documented "do not recapture the previous app" invariant under transient display-loss races. |
| 2026-06-03 | Tray timer width stabilization | Freeze timer-mode status-item width to the widest observed title instead of leaving the item in `variableLength` mode for every countdown update. | The review found that valid long-duration timer text could cross minute digit boundaries and make the menu-bar item shrink mid-countdown, violating the stable-width tray timer requirement. |
| 2026-06-03 | Sleep/wake live delivery ordering | Deliver live `willSleep` and `didWake` notifications synchronously onto the main actor instead of bouncing them through fire-and-forget tasks. | A review found that queued lifecycle callbacks could race the first post-wake timer tick or suspend before `willSleep` bookkeeping ran, which breaks the core sleep/wake reconciliation contract on real hardware. |
| 2026-06-03 | Break completion overflow handling | Preserve already accrued awake time when a late tick finishes a break by carrying any post-rest overflow into the next work interval after the overlay tears down. | External review found that the coordinator dropped overflow elapsed on `rest -> work`, which under-counted work time after UI stalls or debugger pauses. |
| 2026-06-03 | Sleep/wake review hardening | Settle already-earned awake time at `willSleep` before discarding the sleep interval on wake, and make the live sleep/wake registrar suppress queued callbacks after cancellation. | Review exposed short-sleep timer drift plus a teardown race where queued lifecycle callbacks could still mutate coordinator state after cancellation. |
| 2026-06-03 | Sleep/wake plan review close-out | Mark the still-in-place sleep/wake plan explicitly completed at its current `docs/plans/` path until the external review loop no longer depends on that location. | The review automation still opens the original plan path, so a completed-status marker removes the false “in progress” signal without breaking the next review pass. |
| 2026-06-03 | Sleep/wake plan close-out | Close the sleep/wake reconciliation plan without task-sequence changes and keep live fullscreen-Space/external-display wake timing explicitly manual-only in Post-Completion. | The code and automated validation are complete, but XCTest still uses fake lifecycle delivery and cannot prove real WindowServer ordering after sleep; documenting that boundary prevents the automation loop from stalling or overstating acceptance. |
| 2026-06-03 | Sleep/wake documentation contract | Document sleep/wake reconciliation as shipped behavior: short sleep preserves phase/countdown, long sleep uses a fixed 300-second threshold, and lifecycle observation relies on public `NSWorkspace` notifications rather than config or private APIs. | Task 8 needs durable product and engineering docs that match the implemented coordinator policy so future agents do not reintroduce the old "awake-time only" story or assume configurable/private sleep hooks. |
| 2026-06-03 | Sleep/wake active-rest policy | Treat long sleep during an active break as a silent break teardown that resets Mahu to a fresh work interval, while short sleep preserves the current break countdown and overlay state. | Task 5 must prevent a stale break from resuming after a long away-from-keyboard sleep, but it must not trigger natural break completion side effects or disturb short sleep behavior. |
| 2026-06-03 | Sleep/wake paused-work policy | Treat long sleep during paused work as baseline-only reconciliation that preserves the paused menu state, clears pending wake-side effects, and defers the fresh work interval to the existing resume path using current runtime settings. | Task 4 must keep paused reminders non-destructive on wake while still preventing stale elapsed consumption and preserving the established pause/resume contract. |
| 2026-06-03 | Sleep/wake active-work reset policy | Treat wake after at least 300 seconds of recorded sleep as a fresh-work reset only when Mahu is in active work and reminders are not paused; shorter sleeps still only refresh the uptime baseline. | Task 3 must prevent near-expired work timers from triggering an immediate post-wake break without prematurely changing paused-work or active-rest semantics scheduled for later tasks. |
| 2026-06-03 | Sleep/wake coordinator baseline | Inject sleep/wake observation and wall-clock seams into `AppCoordinator`, but keep `didWake` without prior `willSleep` non-destructive by only refreshing the awake-time baseline in Task 2. | Task 2 needs lifecycle registration and a future long-sleep measurement seam now, while preserving current timer/rest state until the explicit long-sleep reset policy lands in later tasks. |
| 2026-06-03 | Sleep/wake observation seam | Add a dedicated `SleepWakeObservation` registrar based on public `NSWorkspace` sleep/wake notifications, and keep deterministic delivery/cancellation in test doubles instead of embedding observer setup in `AppCoordinator`. | Task 1 needs testable lifecycle observation now, while the coordinator policy work comes later; matching the existing focus/screen seam pattern is the smallest way to keep notification code isolated and cancellation behavior provable. |
| 2026-05-31 | Runtime settings review hardening | Reject unsupported durations at both runtime-update and disk-save boundaries, keep runtime settings/test doubles idempotent on repeated identical updates, and extract runtime-settings policy state out of `AppCoordinator.swift`. | Review found that the new runtime settings foundation could accept live schedules that `load()` would later reject, while the fake store/tests overstated notification behavior on no-op updates and `AppCoordinator.swift` had drifted past the local readability limit. |
| 2026-05-31 | Runtime settings persistence hardening | Preserve `config.json` symlinks on save by resolving and writing to the target file instead of atomically replacing the symlink path itself. | Review found that `Data.write(..., .atomic)` on the symlink path silently converted a symlinked config into a regular file, breaking shared dotfile-style setups after the first runtime save. |
| 2026-05-31 | Runtime settings plan close-out | Keep the completed runtime-settings foundation plan at its original `docs/plans/` path during the active review loop, but mark it explicitly completed and document the post-review archival rule. | The current external review workflow still targets the original path, so immediate archival would make documentation cleaner but break the next automated close-out pass. |
| 2026-05-29 | Runtime settings foundation | Apply runtime duration changes through coordinator-owned schedule policies: restart active work immediately on work-duration changes, defer break-duration-only work updates to the next break, and defer active-rest duration changes until the break ends or is skipped. | Task 5 needs deterministic runtime duration behavior without teaching `BreakTimer` about config mutation or restarting the visible break overlay. |
| 2026-05-31 | Runtime settings foundation | Document runtime settings as a single in-process source of truth seeded from launch-loaded `config.json`, with manual JSON remaining persistence-only and no runtime file watching. | Task 8 needs README/AGENTS to match the shipped architecture so future Settings UI work does not reintroduce direct JSON reads or imply live reload that Mahu does not support. |
| 2026-05-29 | Runtime settings foundation | Route runtime UI-only settings changes through a coordinator-owned `RuntimeSettingsStoring` observer that immediately updates the status-item timer mode, while leaving active-break overlay text untouched until the next break. | Task 4 needs live in-process UI updates without recreating the timer or overlay, and the break message policy explicitly forbids mutating an already visible break. |
| 2026-05-29 | Runtime settings foundation | Make `AppCoordinator` consume an injectable `RuntimeSettingsStoring` source, falling back to a one-time launch `loadConfig()` only when no store is provided. | Task 3 needs coordinator startup, resume, and break presentation to read current in-memory settings without repeated disk loads, while preserving existing tests and the no-file-watcher boundary. |
| 2026-05-29 | Runtime settings foundation | Add `ConfigStore.save(_:)` as a disk-only persistence API that creates the config directory, writes atomic JSON, and reports failure with a boolean plus logging. | Task 2 needs future runtime settings flows to persist manual-config-compatible JSON without introducing file watching, runtime rollback coupling, or filesystem behavior inside the runtime store. |
| 2026-05-29 | Runtime settings foundation | Introduce a `@MainActor` `RuntimeSettingsStore` that reuses `AppConfig` as the in-memory runtime value, exposes observer callbacks for accepted changes, and has no direct `ConfigStore` dependency. | Task 1 needs a single injectable runtime source of truth for future coordinator/UI work, but adding a second settings model or letting the runtime store read disk would increase scope and blur the no-live-reload boundary. |
| 2026-05-29 | Overlay message review hardening | Reuse `AppConfig.normalizedBreakOverlayMessageText` below the config layer, center multiline overlay titles inside a bounded width, strengthen legacy-config tests, and document whitespace fallback plus custom-title display resync in README manual checks. | Review found the config boundary normalized blank message text more strictly than the overlay view-model path, the missing-field tests could pass on full-config fallback, and the shipped docs did not explicitly cover whitespace fallback or custom-title persistence during display resync. |
| 2026-05-29 | Coordinator overlay message wiring | Make `AppCoordinator` pass `activeConfig.breakOverlayMessageText` into `showBreak`, with the default title only as a defensive fallback. | The config is loaded once at launch and cached on the coordinator already, so this is the smallest place to connect launch-time configuration to break presentation without introducing live reload or moving overlay policy into SwiftUI/AppKit seams. |
| 2026-05-29 | Overlay message plan close-out | Close the configurable overlay-message plan without sequence changes and keep physical-display text layout/readability checks explicit in Post-Completion manual verification. | The implementation and automated validation are complete, but XCTest/builds cannot prove real NSWindow rendering, text wrapping, or multi-display readability during a live break, so the final plan state must distinguish shipped automation from remaining hardware-only verification. |
| 2026-05-29 | Break overlay manager message wiring | Extend `BreakOverlayManaging.showBreak`/`BreakOverlayManager.showBreak` with `messageText` and keep resync on the shared `BreakOverlayViewModel`. | The manager owns initial overlay window creation plus active-break display reconciliation, so it is the smallest seam that can preserve title, countdown, and skip state across hot-plug changes while exposing the shown title to coordinator tests. |
| 2026-05-29 | Break overlay view-model message ownership | Store the overlay title on `BreakOverlayViewModel`, default it from `AppConfig.defaultBreakOverlayMessageText`, and have `BreakOverlayView` render only the model-provided string. | The configurable message feature needs a small UI seam that keeps config lookup out of SwiftUI view code while preserving the existing default title and countdown/skip behavior. |
| 2026-05-29 | Break overlay message config contract | Add `breakOverlayMessageText: String` to `AppConfig`, default it to `Время отвлечься`, decode a missing key as the default, normalize empty or whitespace-only strings back to the default, and let `null` or non-string values fail through the existing whole-config fallback path. | The new overlay-message feature must preserve old `config.json` files, keep the current Russian message when the field is absent or blank, and avoid inventing a second malformed-config recovery rule separate from the established decode-failure fallback behavior. |
| 2026-05-29 | Break overlay message documentation contract | Document `breakOverlayMessageText` in `README.md` and `AGENTS.md` as a shipped config-backed overlay title with the Russian default and explicit malformed-config fallback semantics. | Future agents use these docs as product invariants; leaving them on the hardcoded-title story would misstate shipped behavior and make backward-compatible config expectations easy to break. |
| 2026-05-29 | Tray timer text presentation | Render timer-mode status item text with a monospaced-digit attributed title and a small leading text spacer while keeping the native `NSStatusBarButton` and existing tray icon. | Manual tray validation showed the default image-leading title was too tight and proportional digits caused the status item width to shift during countdown; monospaced digits stabilize normal `MM:SS` transitions and the spacer improves readability without moving to a custom status-item view. |
| 2026-05-29 | Tray timer review hardening | Treat explicit `showStatusItemTimerState: null` as invalid config, and require the dedicated tray-timer coordinator XCTest files to be real Xcode target members with assertions that prove post-install status updates and exact work/rest state transitions. | The review found one config-contract leak plus false-green coverage gaps: `null` bypassed the documented whole-config fallback, two new XCTest files were not compiled into `MahuTests`, and some status-item assertions did not yet prove the production call order or natural-completion sequence precisely. |
| 2026-05-29 | Tray timer plan archival | Archive the completed optional tray-timer plan under `docs/plans/completed/` and add an explicit completed-status marker in the file. | The repo and README treat `docs/plans/` as the active queue, so leaving a finished plan there misstates project state for future agents and review loops. |
| 2026-05-29 | Tray timer plan close-out | Close the optional tray-timer plan without sequence changes, and explicitly keep native `NSStatusItem` width/truncation/spacing acceptance in Post-Completion manual checks. | The implementation landed task-by-task as planned, but XCTest still cannot prove real menu-bar rendering details, so the final plan state must distinguish complete automation from remaining live-UI verification. |
| 2026-05-29 | Tray timer documentation contract | Document optional status-item timer mode as a config-backed shipped feature in `README.md` and `AGENTS.md`, while keeping default behavior icon-only and manual menu-bar readability verification explicit. | The implementation is already complete, so leaving docs in the old deferred-only state would mislead future agents about product invariants and config support. |
| 2026-05-29 | Coordinator-to-status timer wiring | Let `AppCoordinator` push semantic `StatusDisplayState` updates plus the config-backed timer-mode flag through `StatusItemControlling`, while keeping paused-text rendering and AppKit title/image behavior inside `StatusItemController`. | The tray timer feature needs launch/tick/pause/resume/skip/coordinator lifecycle updates without moving AppKit concerns into `AppCoordinator` or duplicating pause-display rules outside the status-item edge. |
| 2026-05-29 | Status item timer-mode presentation | Keep `StatusItemController` in icon-only mode by default, switch to `NSStatusItem.variableLength` plus cached icon-and-text rendering only when timer display is enabled, and let paused state override timer text with `Paused`. | The optional tray-timer feature must preserve the existing menu-bar contract and icon identity in default mode while localizing AppKit-specific width/title behavior inside `StatusItemController` for later coordinator wiring. |
| 2026-05-29 | Shared timer display formatting | Centralize `MM:SS` and `Paused` status text in a small `StatusDisplayFormatter`/`StatusDisplayState` pair and reuse it from `BreakOverlayViewModel` instead of keeping a second countdown formatter there. | The new optional tray timer feature needs deterministic, AppKit-free text formatting that can be tested once and reused across UI surfaces without adding display-string logic to `AppCoordinator` or duplicating `safeDisplayWholeSeconds` handling. |
| 2026-05-29 | Status item timer config contract | Add `showStatusItemTimerState: Bool` to `AppConfig`, decode a missing key as `false`, and keep invalid non-boolean values on the existing whole-config fallback path. | The optional tray-timer feature must preserve old `config.json` files and default runtime behavior, while malformed manual edits should still fail safely through the project's established config fallback contract. |
| 2026-05-29 | Overlay geometry-bounded centering | Restore and preserve `GeometryReader` in `BreakOverlayView`, framing the background, dark layer, and foreground to the hosting window's exact size; this supersedes the same-day `Break overlay layout composition` simplification. | Manual testing showed the simplified fullscreen `ZStack` lets `scaledToFill()` expand the SwiftUI layout and shift the foreground on the built-in laptop display while external monitors may still look centered; geometry-bounded layout prevents future agents from reintroducing this MacBook-only centering regression without using display-specific offsets. |
| 2026-05-29 | Break overlay layout composition | Simplify `BreakOverlayView` to a full-frame `ZStack` without `GeometryReader`, while keeping centered foreground content and fullscreen background fill. | `GeometryReader` was extra layout machinery for a view that already wants to occupy the full window; the simpler composition preserves behavior and makes rendered-body assertions less fragile. |
| 2026-05-29 | Break overlay skip and startup visibility guards | Run break skip state transitions before final overlay teardown side effects, and treat startup resync that ends with zero visible overlays as a failed presentation instead of a successful break start. | This prevents `Skip` from accidentally triggering the natural-completion sound path and avoids activating Mahu when no overlay UI survives a transient zero-display snapshot. |
| 2026-05-29 | Break overlay observer cancellation | Make focus-loss and screen-change coalescers cancellation-aware so already queued deliveries become no-ops after break teardown. | Notification observers are removed on teardown, but already queued `Task` deliveries can otherwise fire late and mutate the next break lifecycle. |
| 2026-05-29 | Break completion sound runtime format | Replace the bundled runtime completion sound with `Mahu/Resources/break-completion.caf` and switch playback from `NSSound` to `AVAudioPlayer`. | The new source asset is already CAF, `AVAudioPlayer` is the native local-file playback API for this use case, and a stable runtime filename avoids shipping the human-provided source name with spaces while keeping failure handling localized in the sound player seam. |
| 2026-05-29 | Break completion sound documentation contract | Document `break-completion.caf` as the only shipped completion-sound filename in README/build verification, while keeping `source-assets/11labs-sound-sample.caf` as a staging/source asset name only. | The repo now has different source and runtime filenames; locking the docs to the bundled name avoids stale `sound.wav` references and prevents humans or future agents from confusing the editable source asset with the app-bundle contract. |
| 2026-05-29 | Source asset organization and completion sound | Rename the repository staging folder from `images/` to `source-assets/`, use `Warm Focus Nudge 48k 16bit.wav` as the source for the bundled completion audio, and keep the runtime bundle filename as `Mahu/Resources/sound.wav`. | `source-assets/` describes mixed design/audio source material more clearly than `images/`; preserving the stable bundled `sound.wav` name avoids Xcode project churn, spaces in runtime resource names, and unnecessary code/test/Makefile changes. |
| 2026-05-29 | Native status item layout | Roll back status-item length/render-size experiments and keep the native `NSStatusItem.squareLength` layout with an 18x18 template image. | Manual checks showed the 20pt/18x18 and 18pt/20x20 tuning attempts did not visibly reduce menu-bar spacing; using a custom view would be less native and risk menu-bar behavior for a minor visual deviation, so the safest result is to keep AppKit's standard status-item layout. |
| 2026-05-28 | Tray icon visual fit | Tighten the status item slot to 18pt and render the existing `TrayIconTemplate` image at 20x20. | The earlier 20pt slot with an 18x18 rendered image did not visibly reduce menu-bar whitespace; increasing rendered glyph size while tightening the slot keeps the same asset and behavior but better matches neighboring menu-bar icons. |
| 2026-05-28 | Compact status item length | Use an explicit 20pt `NSStatusItem` length for Mahu's icon-only tray control while keeping the `TrayIconTemplate` image at 18x18. | After fixing glyph bounds, the remaining visual imbalance came from the menu-bar slot width rather than the asset itself; tuning the status-item length reduces horizontal padding without degrading the template artwork or changing menu behavior. |
| 2026-05-28 | Tray icon high-resolution crop | Regenerate `TrayIconTemplate` from the archive's high-resolution transparent source, crop to the visible glyph bounds, and downscale to 18x18/36x36 instead of editing the existing low-resolution tray PNGs. | The live menu-bar icon looked smaller than neighboring icons because the glyph did not fill enough of the template canvas; using the high-resolution archive source avoids compounding low-res artifacts while glyph-bound tests prevent future padded-mask regressions. |
| 2026-05-28 | Refactor plan archival | Archive completed refactor plans under `docs/plans/completed/` and describe plan directories generically in `README.md` instead of enumerating every archived file. | A completed plan left in the active queue misleads future review loops, and the per-file README inventory had already drifted out of sync with the repository. |
| 2026-05-28 | App coordinator support refactor | Keep `AppCoordinator` focused on orchestration by moving coordinator-facing protocols, scheduler/typealias support, and concrete conformance glue into `Mahu/AppCoordinatorSupport.swift` without changing runtime behavior. | `AppCoordinator.swift` had crossed the local readability threshold, and extracting support declarations is the smallest refactor that reduces cognitive load while preserving the existing ownership boundaries and regression-proof behavior. |
| 2026-05-28 | Break completion sound review fixes | Preserve the hidden-break countdown contract, but settle the last visible rest slice at overlay-hide time so a break that naturally ends on that boundary still plays sound once; also harden the false-green test/docs gaps the review exposed. | The review found one real edge-case runtime bug plus several incomplete checks that could let future refactors break shipped behavior or mislead future agents even though current `xcodebuild` runs were green. |
| 2026-05-28 | Break completion sound close-out | Archive the fully completed break-completion sound plan under `docs/plans/completed/` and record a durable handoff entry for the shipped sound feature. | The repo treats finished plans as archived artifacts, and the task contract requires durable close-out notes; leaving the plan active and the handoff missing makes project state look partially unfinished. |
| 2026-05-28 | Break completion sound trigger | Trigger the bundled completion sound only from `AppCoordinator` after a natural `rest -> work` transition that occurred while the break overlay was still visible. | This keeps playback semantics tied to the app flow instead of `BreakTimer`, prevents false-positive sounds on `Skip` or hidden/retrying overlays, and preserves a small injectable seam for tests. |
| 2026-05-28 | Break completion sound seam | Add a dedicated `BreakCompletionSoundPlayer` edge around bundled `sound.wav`, with AppKit playback hidden behind a small protocol and failure-tolerant resource checks. | Audio playback is a side effect that should stay outside `BreakTimer`; a separate seam keeps future coordinator wiring testable and makes missing or broken resources non-fatal. |
| 2026-05-28 | Paused icon wiring coverage | Add one integration-style XCTest that clicks real pause/resume menu items through `AppCoordinator` with a live `StatusItemController`, instead of relying only on separate fake-coordinator and direct-controller tests. | The previous coverage missed the real menu-to-coordinator-to-status-item wiring path and did not prove that the same icon instance survives pause/resume transitions. |
| 2026-05-28 | Paused icon plan archival | Move the fully completed paused-icon execution plan into `docs/plans/completed/` and sync README plan references to the archived path. | The repo already treats finished plans as archived artifacts; leaving this one in the active queue creates false ambiguity for future agents and reviewers. |
| 2026-05-28 | Paused icon acceptance contract | Treat paused-icon acceptance as a visible dimming band, not an exact alpha constant, so tests lock behavior without blocking later menu-bar readability tuning. | The feature contract is "visibly dimmed while still recognizable", and manual tray validation may require adjusting the exact opacity without changing the intended behavior. |
| 2026-05-28 | Paused reminder icon state | Dim the existing status-item button at runtime to show paused reminders, using the same `TrayIconTemplate` asset and keeping the control enabled. | This keeps the paused cue inside `StatusItemController`, preserves the asset contract, and avoids introducing a second paused icon or disabled-control semantics. |
| 2026-05-28 | Reminder pause review fixes | Cache the launch-loaded config for resume resets and keep rest-phase pause/resume from touching active-break timing. | Review found hidden live-config reload behavior and active-break timing drift when the tray menu was used during rest. |
| 2026-05-26 | Reminder pause/resume semantics | Treat the tray menu action as enabling or disabling automatic reminders at the coordinator layer, and make resume start a fresh work interval from the current config instead of continuing partially elapsed work time. | This keeps break countdown behavior unchanged, avoids introducing countdown-pause semantics into `BreakTimer`, and gives users a predictable reset when they re-enable reminders. |
| 2026-05-26 | Reminder menu status-item API | Keep pause/resume menu wiring inside `StatusItemController` with injected callbacks plus a `setRemindersPaused(_:)` view-state method, leaving reminder semantics in `AppCoordinator`. | The tray layer should only own AppKit menu construction and dispatch, while coordinator-level reminder state and timer resets remain testable outside AppKit. |
| 2026-05-25 | Overlay visibility pause accounting | Account for active-break elapsed time at overlay visibility edges and freeze the uptime baseline whenever zero-display transitions hide or re-show the overlay between timer ticks. | Tick-only visibility checks miss transient no-display windows that begin and end between scheduler callbacks, which silently consumes hidden rest time. |
| 2026-05-25 | Bundle-aware tray icon loading | Make `StatusItemController.makeTrayTemplateStatusIcon(bundle:)` load the tray image from the supplied bundle and prove that path with custom-bundle tests. | A bundle parameter that still performs global image lookup is a fake seam; explicit bundle lookup keeps the tray-icon path testable and resilient if the asset ever moves out of the main bundle. |
| 2026-05-25 | Tray icon documentation contract | Define `TrayIconTemplate` as transparent glyph-only template artwork, document live menu-bar readability as manual-only, and record that a directly drawn simplified lotus silhouette is acceptable when automated extraction from `icon.png` produces an unreadable or empty tray mask. | The shipped contract is about a transparent template-friendly tray silhouette, not about preserving a specific generation script. Locking the visual/runtime contract and the fallback generation constraint prevents future regressions back to opaque square rasters or brittle empty-mask pipelines. |
| 2026-05-25 | Tray icon contract verification | Freeze Task 3 as verification-only code proof: keep `StatusItemController` behavior unchanged and extend XCTest coverage to assert the menu-bar-only `LSUIElement` plist contract alongside the existing icon provider, resize/template, and Quit-menu checks. | The tray asset itself was already regenerated in Task 2, so the smallest correct Task 3 change is stronger automated proof of the shipped contract rather than touching working status-item behavior and risking regressions. |
| 2026-05-25 | Tray icon glyph regeneration | Replace the opaque tray raster with a simplified lotus-shaped monochrome glyph on transparent background, and verify source tray assets by decoded bitmap dimensions plus transparency rather than `NSImage.size` point semantics on `@2x` filenames. | The menu-bar icon needs a template-friendly non-square mask, and source-file regression proof should follow real pixel data because Cocoa's logical image size varies with Retina filename conventions. |
| 2026-05-25 | Tray icon retina asset verification | Verify tray source PNGs from raw raster metrics and require the `@2x` glyph mask to scale beyond the 1x bounds instead of only checking canvas size and transparent corners. | A 36x36 PNG can still carry a 1x-sized glyph on a larger canvas, which looks broken on Retina menu bars while passing the earlier transparency-only regression test. |
| 2026-05-25 | Tray icon transparency regression | Prove `TrayIconTemplate` asset correctness with a direct XCTest that reads the source PNGs, locks 18x18/36x36 dimensions, requires transparent corners/background, and requires non-empty glyph pixels even before regenerating the artwork. | Task 1 must fail on the current opaque-square assets before any redraw work begins, so the smallest truthful proof lives at the asset-file level rather than in status-item runtime behavior. |
| 2026-05-23 | Review-pass hardening | Treat `config.json` as loadable only when it is a regular file (or a symlink resolving to one), pause active-break countdown consumption while all displays are unavailable, and move overlay display reconciliation into shared support instead of further growing `BreakOverlayManager.swift`. | The second review pass found a startup hang path through special files at the config location and an invisible-break path when active overlays lose every display; fixing both while respecting the local file-size guard requires tighter file validation plus a small overlay-layer refactor. |
| 2026-05-22 | Tray status icon contract | Document the shipped status-item icon contract as `TrayIconTemplate` first, then a copied/resized compiled app icon fallback, both forced to an 18x18 template image. | The menu bar needs compact tray-specific artwork for readability, but Mahu still must avoid an empty status item if the tray asset lookup fails at runtime. |
| 2026-05-22 | Status item icon fallback | Make the production status-item icon provider prefer `TrayIconTemplate`, then fall back to a copied/resized app icon, with both paths returning an 18x18 template image copy. | This removes the old SF Symbol, keeps the menu bar icon path resilient if the tray asset is missing, and avoids mutating shared `NSImage` cache instances while staying inside `StatusItemController`. |
| 2026-05-22 | Tray icon asset packaging | Add a dedicated `TrayIconTemplate` asset catalog image set derived from `icon.png`, plus a small loader that marks loaded images as template images. | The menu bar icon needs asset-backed proof before replacing the SF Symbol, and forcing template behavior in code keeps tintability explicit regardless of asset naming. |
| 2026-05-22 | Config file load hardening | Stream-read `config.json` with a 64 KiB cap before decoding and fall back to defaults when the file exceeds that limit. | The config file is user-editable, so launch should not allocate unbounded memory or hang on an oversized local file. |
| 2026-05-22 | Privacy manifest coverage | Add `PrivacyInfo.xcprivacy` declaring `NSPrivacyAccessedAPICategorySystemBootTime` with reason `35F9.1` for `ProcessInfo.processInfo.systemUptime`. | Mahu uses monotonic uptime for in-app timer calculations, and Apple requires a matching privacy manifest declaration for that API category. |
| 2026-05-22 | Structured overlay UI assertions | Verify overlay foreground content through recursive SwiftUI view-tree assertions plus stable accessibility identifiers instead of `String(describing:)` snapshots of SwiftUI internals. | The previous tests could stay green while the view tree lost required text or button identity, so review-proof coverage needs to inspect structured SwiftUI data rather than debug strings. |
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
| 2026-05-21 | Local build artifact | Add `make build` to produce `build/Mahu.app` while keeping Xcode intermediate files under ignored `build/DerivedData`. | Users need a predictable app path, but keeping Xcode cache/artifacts out of source control avoids polluting the repo and preserves standard `xcodebuild` behavior. |
| 2026-05-21 | Overlay focus hardening plan | Plan focus retention as public-API bounce-back while the break overlay is active, not as global keyboard shortcut blocking. | This addresses accidental hidden-app input after `Cmd+Tab` without introducing Accessibility/Input Monitoring permissions or App Store-hostile input capture. |
| 2026-05-21 | Overlay focus reassertion | Re-show existing overlay windows and re-activate Mahu on focus-loss notifications, while preserving the previous-frontmost app captured at break start. | This is the smallest public-API hardening that improves accidental `Cmd+Tab` behavior without rebuilding windows, changing timer flow, or corrupting restore behavior at break end. |
| 2026-05-21 | Overlay focus teardown | Centralize focus-observer replacement/cancellation inside `BreakOverlayManager` and model cancellation accurately in shared test doubles. | Task 3 needs proof that `hideBreak`, `Skip`, and repeated `showBreak` calls do not leak observer callbacks after teardown, and a single replacement path is the smallest robust way to guarantee that. |
| 2026-05-21 | Overlay focus retention documentation | Document overlay focus hardening as best-effort public-API behavior in README, AGENTS, and the task plan, with manual `Cmd+Tab` verification still required. | The implementation is intentionally App Store-friendly and does not block global shortcuts directly, so future agents and humans need the docs to state both the protection and its limits precisely. |
| 2026-05-21 | Live focus-loss handling | Coalesce public focus-loss notifications on the MainActor and represent observer teardown as an idempotent cancellation closure. | Review found duplicate bounce-back risk from paired resign/activation notifications and unnecessary seam complexity around one-shot observer teardown. |
| 2026-05-21 | Overlay background image plan | Plan `background.png` as a raw bundled app resource under `Mahu/Resources/` and render it behind a dark readability layer in `BreakOverlayView`. | A single PNG does not justify introducing an asset catalog yet, and the overlay must stay readable and packaged inside the `.app`. |
| 2026-05-21 | Overlay background rendering | Render the bundled `background.png` fullscreen with `scaledToFill` under a semi-transparent black layer while keeping the existing foreground content unchanged. | This localizes the visual change to `BreakOverlayView`, preserves readability on varied imagery, and avoids changing timer or window-management behavior. |
| 2026-05-21 | Overlay background documentation | Document the bundled overlay background and required dark readability treatment in `README.md`, `AGENTS.md`, and the execution plan. | The visual feature is now part of shipped behavior, and future agents need the docs to preserve readability and the bundled-resource constraint. |
| 2026-05-22 | Overlay resource verification | Strengthen the overlay-background proof by decoding the hosted app resource in XCTest and making `make build` fail if either app bundle omits `background.png`. | The previous proof only checked resource lookup by URL, which could stay green even with a corrupted image or an incomplete copied `.app` artifact. |
| 2026-05-22 | Completed plan archival | Move finished implementation plans into `docs/plans/completed/` with explicit status and keep README plan references current, including Xcode prerequisites for verification commands. | Finished plans should not stay in the active queue, and humans need README pointers and setup caveats that match the actual repo layout and build workflow. |
| 2026-05-22 | Overlay background rendering fix plan | Plan the runtime image fix around explicit bundle lookup and `NSImage` decoding instead of implicit `Image("background")` named-image lookup. | The PNG is already bundled and decodable, so the smallest robust fix is to remove SwiftUI named-resource ambiguity without changing resource packaging, overlay windows, or timer behavior. |
| 2026-05-22 | Overlay background runtime loading | Replace implicit `Image("background")` rendering with a small bundle-injected loader that resolves `background.png`, decodes it with `NSImage(contentsOf:)`, and falls back to a dark background when loading fails. | The resource packaging path already works; explicit loading removes named-resource ambiguity on macOS while keeping the fix localized and preserving overlay readability if the image is missing or undecodable. |
| 2026-05-22 | Overlay background documentation | Document the runtime background fix as explicit app-bundle image loading and keep final visual confirmation manual-only. | Future agents and humans need README and plan language that matches the shipped implementation and current proof limits. |
| 2026-05-22 | Overlay review fixes | Cache the loaded overlay background per view lifetime, refuse invisible breaks when no displays exist, and split live focus-observer tests into their own file with extra signal coverage. | Review found per-tick image decode churn, a silent no-display break edge case, and test gaps that could hide regressions in specific focus-loss notification paths. |
| 2026-05-22 | Second review hardening | Bound supported config durations to 1...86,400 seconds, retry pending breaks without consuming rest time, and fall back to a home-based Application Support path if directory lookup fails. | The second review found a config-driven crash path, invisible-break time loss after transient display failures, and a startup resilience gap before config fallback logic could even run. |
| 2026-05-22 | Review follow-up config semantics | Keep config durations finite and at least one second, and protect countdown rendering with an Int64-capped display conversion instead of rejecting schedules above 24 hours. | The 24-hour validation cap solved an overflow path by changing manual-config semantics; moving the guard into the countdown formatter preserves user schedules while still preventing conversion traps. |
| 2026-05-22 | Timer precision bounds | Reject config durations above the largest `TimeInterval` range that still preserves one-second countdown progress. | Arbitrarily large finite doubles can stop changing when the timer subtracts one second, so the config contract needs a precision-based ceiling even though the 24-hour product cap was too strict. |
| 2026-05-22 | Overlay content centering fix plan | Plan the MacBook alignment fix around explicit fullscreen SwiftUI geometry sizing in `BreakOverlayView`, not display-specific offsets or AppKit window changes. | The external monitor already works and the symptom appears when `scaledToFill()` can expand image layout on a 16:10 display, so the smallest robust fix is to decouple foreground centering from image crop size. |
| 2026-05-22 | Overlay content centering implementation | Size `BreakOverlayView` explicitly to `GeometryReader` bounds and clip the background image inside those bounds, while keeping coverage at the SwiftUI-layout contract level in tests. | This fixes centering without display-specific offsets or AppKit churn; SwiftUI runtime text extraction is brittle in XCTest, so the stable proof point is the geometry-sized body contract plus existing foreground/view-model behavior. |
| 2026-05-22 | Break timing precision follow-up | Accumulate elapsed uptime across ticks, stop consuming at phase boundaries, quantize only above the subsecond-precision threshold, and reset the baseline after a successful overlay show. | This preserves the large-duration config contract while preventing hidden break-time loss during synchronous overlay presentation work. |
| 2026-05-22 | Config diagnostics privacy | Log malformed `config.json` fallbacks as warnings and treat filesystem paths as private OSLog data. | Manual config editing is the only MVP settings surface, so users need a clear decoding signal without leaking usernames or home-directory paths in exported logs. |
| 2026-05-22 | Hosted test startup control | Gate production coordinator startup with a shared test-scheme environment variable while keeping XCTest marker detection as fallback. | A project-owned startup switch is more stable than relying only on runner internals and lets tests cover both launch branches deterministically. |
| 2026-05-22 | Overlay contract test seams | Expose small internal overlay/window helpers instead of adding a third-party SwiftUI inspection framework. | This makes the centering/background/window invariants testable with existing XCTest/AppKit tools and keeps the dependency surface small. |
| 2026-05-22 | Overlay display hot-plug plan | Plan active-break display hot-plug handling as incremental window resync owned by `BreakOverlayManager`, while leaving live config reload out of scope. | The overlay invariant depends on current displays, but settings reload will be handled later by GUI configuration; keeping this work in the overlay layer avoids coupling timer/config concerns to monitor changes. |
| 2026-05-22 | Overlay active window tracking | Replace the plain overlay window array with display-bound active overlay records before adding live hot-plug resync. | Future display reconciliation needs stable display identity without changing current break lifecycle, skip, or focus-retention behavior. |
| 2026-05-22 | Overlay display resync | Reconcile active overlay windows by stable display id, preserving unchanged windows and replacing only added, removed, or resized displays during an active break. | Hot-plug support needs frame-change detection that survives display identity across resolution changes; incremental resync keeps countdown, skip, observer ownership, and previous-app restore semantics intact without routing display events through `AppCoordinator`. |
| 2026-05-22 | Overlay hot-plug lifecycle verification | Prove hot-plug focus/restore semantics with focused XCTest coverage instead of changing `BreakOverlayManager` behavior when the current implementation already preserves those invariants. | Task 4 is about preventing regressions in previous-app capture, observer teardown, and focus bounce-back after display changes; tests are the smallest correct change when runtime behavior is already aligned with the contract. |
| 2026-05-22 | Overlay hot-plug documentation | Document active-break display hot-plug as shipped overlay behavior and keep live config reload explicitly out of scope. | The implementation is already present, so README and AGENTS must preserve the runtime contract for future agents while avoiding accidental scope creep into settings reload. |
| 2026-05-22 | Overlay hot-plug acceptance verification | Close Task 6 with deterministic XCTest/build proof and documented manual-only hardware follow-up instead of blocking on unavailable monitor or Spaces checks. | The codebase now has focused tests for add/remove/resize/focus/state invariants plus green `xcodebuild` and `make build`; physical display hot-plugging and fullscreen Spaces still require real hardware and should stay explicit manual validation instead of keeping the automation loop open forever. |
| 2026-05-22 | Overlay hot-plug review fixes | Make display reconciliation collision-tolerant, tear down active overlay resources on manager deinit, and split overlay support types out of `BreakOverlayManager.swift` while closing the remaining plan/README follow-up. | Review found a potential duplicate-key crash when display identifiers collide, missing observer/window cleanup on teardown, and stale documentation around the completed hot-plug plan and retry semantics. |
| 2026-05-22 | Overlay startup hot-plug race | Reconcile active overlays once immediately after screen-observer registration in `showBreak()`. | A display change between the first screen snapshot and observer installation can otherwise miss the only notification and leave the new display uncovered for the rest of the break. |
| 2026-05-22 | Review lifecycle and focus docs fixes | Use `isolated deinit` for `@MainActor` teardown paths and narrow focus-retention docs to best-effort bounce-back only. | Ordinary `deinit` is not actor-isolated, and the current public-API focus bounce-back cannot guarantee zero leaked keystrokes after `Cmd+Tab`. |
| 2026-05-22 | App icon asset catalog | Use a standard `Assets.xcassets/AppIcon.appiconset` generated from the root `icon.png` and wire it through the existing `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` setting. | App icons are a build-time bundle identity asset, so an asset catalog is the native Xcode path and avoids hand-maintaining `.icns` files. |

## 2026-06-04 / Config JSONC Tolerance

## 2026-06-04 / Config JSONC Preprocessor Shape

**Date:** 2026-06-04

**Area:** Config parsing

**Context:** Task 2 needs a dedicated preprocessing seam before `ConfigStore` load wiring lands. `ConfigStore.swift` is already large, and the tolerance layer must preserve string literals such as URLs and comment-looking text while handling comment stripping and trailing-comma cleanup deterministically.

**Decision:** Implement `ConfigJSONPreprocessor` as a small in-repo scanner that first strips `//` and `/* ... */` comments outside strings, preserving newline characters from removed comments, and then removes trailing commas before `}` or `]` in a separate whitespace-aware pass.

**Rationale:** A scanner keeps string handling explicit and avoids the corruption risks of whole-file regex transforms. Splitting comment removal and trailing-comma cleanup into two simple passes keeps the helper small, testable, and independent from the already-large `ConfigStore` file until Task 3 wires the load path.

**Consequences:** The repo now has a focused preprocessing seam with direct helper tests for array/object trailing commas and unterminated block-comment errors. `ConfigStore` integration remains unchanged until the next task, so existing failing JSONC load tests still truthfully signal that wiring has not happened yet.

**Alternatives Considered:** Fold the scanner directly into `ConfigStore.loadRegularConfig(from:)`; rejected because it grows an already large file before the behavior is validated in isolation. Use a single-pass regex-based cleanup; rejected because it is brittle around escaped quotes, URLs, and comment-like text inside strings.

**Date:** 2026-06-04

**Area:** Config parsing

**Context:** Mahu's config is still manually edited through `~/Library/Application Support/Mahu/config.json`, and the project-root `config.json` can be a symlink to that file. The user commented out a line in Zed, which produced JSONC-like `//` syntax; the current strict `JSONDecoder` path treated the file as invalid and fell back to default 20-20-20 settings with tray timer disabled.

**Decision:** Keep `config.json` as the persisted format, tolerate JSONC-style `//` comments, `/* ... */` comments, and trailing commas on read, and continue writing strict JSON through `ConfigStore.save(_:)`. Implement this with a small scanner-based preprocessor rather than a regex-only transform or a new YAML/JSON5 dependency.

**Rationale:** This directly fixes the user's manual-edit workflow without a config migration, new package dependency, or dual-format precedence rules. Scanner-based preprocessing can preserve string literals like URLs and comment-looking text, while strict JSON output remains compatible with the existing save path and future Settings UI.

**Consequences:** Users can temporarily comment optional config lines and keep custom durations/tray settings after relaunch. Malformed JSONC, invalid explicit field types, unsupported durations, and filesystem hardening behavior still fall back as before. YAML remains a possible future choice only if manual config grows substantially and outlives the planned Settings UI.

**Alternatives Considered:** Migrate to YAML; rejected for now because it requires a Swift YAML dependency, migration plan, and source-of-truth rules if both JSON and YAML exist. Add a third-party JSON5 parser; rejected as unnecessary for the current small config surface. Keep strict JSON and only update docs; rejected because it leaves the current editor-driven failure mode unfixed.

## 2026-06-03 / Launch at Login Config Architecture

## 2026-06-03 / Launch at Login Documentation Contract

**Date:** 2026-06-03

**Area:** Launch at Login

**Context:** The implementation is already wired through `AppConfig`, a desired-state store, a controller, and `SMAppService.mainApp`, but the product docs still list Launch at Login as deferred and do not explain that manual config edits apply only on the next app launch. Signed Login Item behavior also remains outside what the current automated test/build commands can prove.

**Decision:** Document Launch at Login as a shipped config-backed startup reconciliation feature: `launchAtLoginEnabled` defaults to `false`, manual changes to `config.json` require relaunch, startup sync warnings remain non-fatal, and real System Settings/login persistence checks stay manual-only for a signed app.

**Rationale:** This is the smallest durable documentation change that keeps README and AGENTS aligned with the implemented behavior without implying live reload, a new menu-bar toggle, or stronger automated verification than the repo actually has.

**Consequences:** Future agents will treat Launch at Login as part of the shipped product contract instead of a deferred feature, humans editing `config.json` will know a relaunch is required, and release work can build on explicit manual signed-app validation instead of rediscovering those limits.

**Alternatives Considered:** Leave the docs unchanged and rely on code/tests alone; rejected because this repo uses README and AGENTS as active product and engineering contracts. Add a menu/status-item control to make the feature more discoverable; rejected because the current product scope intentionally defers UI for Launch at Login to a future Settings surface.

**Date:** 2026-06-03

**Area:** Launch at Login

**Context:** Mahu currently uses a manually editable launch-loaded `config.json` as the only settings surface, while a real Settings UI remains deferred. The user explicitly rejected adding a status-menu item for Launch at Login now and wants a config option that can later be surfaced in the Settings window without rewriting the ServiceManagement integration.

**Decision:** Plan Launch at Login as config-backed desired state, not a status-menu control. Add a dedicated launch-at-login settings store for the in-process desired value, a small controller/policy that reconciles desired state with macOS actual Login Item state, and a ServiceManagement adapter around `SMAppService.mainApp`. Keep `SMAppService` calls out of `AppCoordinator`, and do not rewrite `config.json` to `false` when macOS reports `requiresApproval` or a registration error.

**Rationale:** A separate desired-state store is slightly more code than startup-only reconciliation, but it preserves the existing config workflow and gives the future Settings UI a stable seam to update desired state, sync with macOS, and persist through `ConfigStore.save`. Treating config as desired state also avoids lying about the actual Login Item state, which can be changed or blocked by macOS outside Mahu.

**Consequences:** The MVP can ship with only `launchAtLoginEnabled` in `config.json` and startup reconciliation. Future Settings UI work can reuse the same store/controller instead of reimplementing ServiceManagement logic. Real registration behavior still requires signed-app manual verification, and failures remain non-fatal warnings rather than startup blockers.

**Alternatives Considered:** Add a status-menu checkbox now; rejected because the user wants no menu item and prefers a future Settings UI. Use config-only startup reconciliation with no settings store; rejected because it would be smaller today but less ready for Settings UI. Automatically enable Launch at Login by default; rejected because public-release startup behavior should be explicit opt-in.

## 2026-06-03 / Launch at Login Config Contract

**Date:** 2026-06-03

**Area:** Launch at Login

**Context:** Task 1 extends Mahu's manually editable launch-loaded `config.json` before any ServiceManagement integration exists. The new field must preserve old config files, participate in save/load round trips, and follow the repo's current malformed-config fallback behavior instead of introducing special-case per-field recovery.

**Decision:** Add `launchAtLoginEnabled: Bool` to `AppConfig`, default it to `false`, decode a missing key as `false`, and let invalid or `null` values fail through the existing whole-config fallback behavior.

**Rationale:** This is the smallest contract change that keeps older config files working unchanged, preserves the single established recovery rule for malformed manual edits, and gives later launch-at-login tasks a deterministic desired-state input without extra migration logic.

**Consequences:** Default config creation and persistence now include an explicit `launchAtLoginEnabled: false`, focused tests lock the new field's decode and round-trip semantics, and later startup/controller work can build on the field without revisiting config compatibility rules.

**Alternatives Considered:** Add custom per-field fallback for invalid values; rejected because it would diverge from Mahu's current whole-config fallback semantics. Omit the field from encoded defaults until the feature is fully wired; rejected because round-trip persistence and explicit config visibility are part of the manual-config contract.

## 2026-06-03 / Sleep/Wake Review Hardening

**Date:** 2026-06-03

**Area:** Sleep/wake timer reconciliation

**Context:** External review found two real short-sleep edge cases in the newly shipped reconciliation flow. `AppCoordinator.handleWillSleep()` only recorded the wall-clock sleep start, so awake time that had already elapsed between the last scheduled tick and the actual sleep event was discarded on wake instead of being charged to the active work/break phase. The same review also pointed out that `LiveSleepWakeObservationRegistrar` spawned `Task { @MainActor ... }` deliveries without checking cancellation inside the queued task body, so `cancel()` could remove observers while already-posted `willSleep`/`didWake` callbacks still executed during teardown.

**Decision:** Settle already-earned awake time in `handleWillSleep()` before recording the sleep start, while still discarding only the actual sleep interval on wake. Also make the live sleep/wake registrar check its cancellation flag inside queued `Task` deliveries and add regression tests for the queued-callback cancellation path plus pre-sleep awake-time accounting during active work, active rest, and paused work.

**Rationale:** Short sleep must exclude only the suspended interval, not awake time Mahu had already earned before the machine slept. Cancellation also needs to be truthful at the queued-task boundary because lifecycle callbacks that arrive after teardown can silently corrupt coordinator state even when the observer itself was removed correctly.

**Consequences:** Short sleep now preserves timer progress earned just before the machine slept, active-break countdown updates no longer drift by up to a tick across repeated short sleep/wake cycles, and stale queued sleep/wake callbacks become no-ops after cancellation. The existing long-sleep threshold remains on the current wall-clock contract from the original plan; this review fix only closes the newly confirmed awake-time/accounting race.

**Alternatives Considered:** Keep settling elapsed time only on the next post-wake tick; rejected because that still loses or delays already-earned awake time and makes immediate post-wake phase state inaccurate. Add a heavier coalescer object for sleep/wake notifications; rejected because the existing registrar only needed queued-task cancellation awareness, not event coalescing.

## 2026-06-03 / Sleep/Wake Plan Review Close-Out

**Date:** 2026-06-03

**Area:** Sleep/wake timer reconciliation

**Context:** The sleep/wake plan is fully checked off, but the current external review loop still references the original file under `docs/plans/2026-06-03-sleep-wake-timer-reconciliation.md`. Leaving it without an explicit status marker makes the file look active even though the implementation and documentation work are complete.

**Decision:** Keep the plan at its current path for the duration of the active review loop, but add an explicit completed-status block at the top that says the work is done and only archival is pending after external review.

**Rationale:** The review automation needs a stable path, but humans and future agents should not have to infer plan completion from a wall of checked boxes alone.

**Consequences:** The next review pass can still open the original plan path, while the repo no longer gives a false signal that the sleep/wake work is still in progress. Once the review loop no longer depends on the original location, the plan can move to `docs/plans/completed/` without another status rewrite.

**Alternatives Considered:** Archive the plan immediately; rejected because the current review loop still targets the original path. Leave the path unchanged with no explicit status marker; rejected because that keeps the plan state ambiguous for the next human or agent reader.

## 2026-06-03 / Sleep/Wake Coordinator Baseline Handling

**Date:** 2026-06-03

**Area:** Sleep/wake timer reconciliation

**Context:** Task 2 adds coordinator-owned sleep/wake lifecycle wiring before the long-sleep reset policy exists. The coordinator needs testable observation registration and a wall-clock seam for future duration measurement, but a plain `didWake` callback without a recorded `willSleep` must not recreate timers, hide overlays, or otherwise mutate the current phase.

**Decision:** Inject `SleepWakeObservationRegistrar` and `CurrentWallClockDateProvider` into `AppCoordinator`, register and cancel the observation with coordinator lifecycle, record wall-clock sleep start on `willSleep`, and make `didWake` without prior `willSleep` only refresh `lastTickUptime` instead of resetting timer state.

**Rationale:** This is the smallest Task 2 change that prepares the coordinator for later long-sleep threshold logic while preserving the existing awake-time-only behavior. Keeping the wake path non-destructive also prevents false timer resets from stray wake notifications or startup-order edge cases.

**Consequences:** `AppCoordinator` now owns explicit sleep/wake lifecycle seams and teardown, future tasks can compute sleep duration without rereading config or teaching `BreakTimer` about wall-clock time, and the next scheduler tick after wake no longer consumes stale elapsed time from before the wake callback.

**Alternatives Considered:** Add the observation later together with the long-sleep reset logic; rejected because Task 2 explicitly needs lifecycle wiring and baseline protection first, and deferring the seam would make later policy changes larger and riskier.

## 2026-06-03 / Sleep/Wake Active Work Reset Threshold

**Date:** 2026-06-03

**Area:** Sleep/wake timer reconciliation

**Context:** Task 3 introduces the first destructive wake policy. Mahu already records `willSleep`/`didWake` timestamps and refreshes the uptime baseline, but it still needs a narrow rule that prevents a nearly expired work timer from showing a break right after a long lid-close while leaving paused-work and active-rest handling for later tasks.

**Decision:** Add an internal `longSleepResetThresholdSeconds` constant set to `300`, and on `didWake` reset to a fresh work timer only when Mahu has a recorded sleep start, the elapsed wall-clock sleep is at least that threshold, the current phase is active work, and reminders are not paused.

**Rationale:** This is the smallest Task 3 policy that matches the product goal without widening scope into paused or rest semantics too early. Using an internal constant keeps the config contract stable until there is a settings surface, while short sleeps and stray wake events still preserve the current countdown.

**Consequences:** Active work no longer carries a near-expired timer through lunch-length sleeps, the next tick starts from a fresh work interval instead of an immediate break, and future tasks can layer paused/rest-specific wake behavior on top of the same baseline-refresh flow.

**Alternatives Considered:** Make long-sleep reset unconditional for every phase; rejected because it would silently change paused reminders and active breaks before those behaviors are specified and tested in later tasks.

## 2026-06-03 / Sleep/Wake Paused Work Semantics

**Date:** 2026-06-03

**Area:** Sleep/wake timer reconciliation

**Context:** Task 4 needs long-sleep wake handling for paused reminders without changing the existing pause/resume menu contract. Mahu already refreshes the uptime baseline on wake and resumes work from current runtime settings, but paused-work behavior needs an explicit rule so long sleep does not show a break, consume hidden elapsed time, or resurrect any deferred runtime-schedule action from before the pause.

**Decision:** Treat long sleep during paused work as a baseline-only wake reconciliation path: keep reminders paused, clear pending elapsed time, refresh the uptime baseline, reset the runtime-settings policy to current settings, and let the existing resume flow create the fresh work timer from the current runtime settings when the user resumes reminders.

**Rationale:** This is the smallest Task 4 policy that keeps wake behavior non-destructive while preserving the already-shipped pause/resume contract. By leaving the fresh interval creation on the resume path, the coordinator avoids a second paused-only timer lifecycle and keeps `BreakTimer` sleep/wake-unaware.

**Consequences:** Long sleep while paused no longer risks stale elapsed consumption or an immediate post-resume break, pause state remains visible and intact after wake, and later active-rest work can use the same wake routing without inheriting paused-work side effects.

**Alternatives Considered:** Recreate the work timer immediately on wake even while paused; rejected because the user-facing reset is only needed when reminders resume, and immediate timer replacement would add extra paused-state lifecycle churn without changing visible behavior.

## 2026-06-03 / Sleep/Wake Active Rest Semantics

**Date:** 2026-06-03

**Area:** Sleep/wake timer reconciliation

**Context:** Task 5 extends long-sleep reconciliation into the active-rest phase. Mahu already preserves break countdown state across short sleeps by refreshing the uptime baseline on wake, but a long sleep during an active break should not resume an obsolete overlay or play the natural completion sound when the user returns.

**Decision:** Add a dedicated active-rest wake reconciliation action that resets Mahu to a fresh work timer from current runtime settings after a long sleep, and let the existing `.work` coordinator path hide the stale overlay. Keep short sleep during rest non-destructive so the current break countdown and overlay continue normally after wake.

**Rationale:** This is the smallest Task 5 change that reuses the shipped overlay teardown and status update seams instead of duplicating hide logic or threading special-case sound handling through `handleDidWake()`. Keeping the reset on the normal `.work` path also preserves `Skip` teardown invariants without teaching `BreakTimer` about sleep/wake.

**Consequences:** Long sleep during an active break now closes the stale overlay without completion audio and restarts work from a fresh interval, while short sleep still resumes the same break countdown. The wake-routing enum grows by one case, but the coordinator change stays minimal and future rest-specific regressions remain easy to test in isolation.

**Alternatives Considered:** Do nothing on wake during rest; rejected because the old break would incorrectly resume after a long away period. Hide the overlay directly inside `handleDidWake()` and then separately recreate the timer; rejected because that would duplicate `.work` transition behavior and make sound/skip side effects easier to regress.

## 2026-06-03 / Sleep/Wake Documentation Contract

**Date:** 2026-06-03

**Area:** Sleep/wake timer reconciliation

**Context:** The sleep/wake reconciliation implementation is already complete, but `README.md` and `AGENTS.md` still describe Mahu as awake-time-only and still list sleep/wake reconciliation as deferred work. Task 8 needs the durable product docs and agent-facing invariants to match the shipped behavior and preserve the chosen public-API boundary.

**Decision:** Update `README.md` and `AGENTS.md` to describe sleep/wake reconciliation as shipped behavior: short sleep preserves the current phase/countdown after a baseline refresh, long sleep is defined by an internal fixed 300-second threshold, paused reminders stay paused until resume, active breaks close silently into fresh work without completion sound, and lifecycle observation relies on public `NSWorkspace` sleep/wake notifications rather than config-driven thresholds or private APIs.

**Rationale:** This is the smallest durable documentation change that prevents future agents from reintroducing the old non-reconciled timer story or widening scope into live config reload and private system hooks. Recording the threshold and public-API choice alongside the product behavior keeps the implementation constraints visible where the repo expects them.

**Consequences:** README manual checks now cover long sleep, short sleep, paused reminders, and active-break wake scenarios; AGENTS product invariants no longer list sleep/wake reconciliation as deferred; and future work can build on the fixed-threshold/public-notification contract without re-discovering it from code alone.

**Alternatives Considered:** Leave the docs unchanged and rely on tests; rejected because this repo treats README and AGENTS as active product/engineering contracts for future agent work. Expose the long-sleep threshold as a config field in docs now; rejected because the shipped implementation intentionally keeps it internal until there is a settings surface.

## 2026-05-31 / Runtime Settings Documentation Contract

**Date:** 2026-05-31

**Area:** Runtime settings foundation

**Context:** The runtime settings foundation is already implemented, but README and AGENTS still described resume behavior and config ownership mostly in launch-config terms. Task 8 needs the durable docs to distinguish launch-time JSON persistence from the in-process runtime settings source that future Settings UI work should use.

**Decision:** Document `config.json` as launch-loaded persistence/backward-compatibility only, describe the runtime settings store as the single in-process source of truth for coordinator behavior, and explicitly state that editing the file while Mahu is running does not trigger live reload.

**Rationale:** The code now supports runtime settings policies without repeated disk reads, so leaving docs on the old model would encourage future agents to wire UI changes through direct JSON reads or assume live file watching exists. A doc-level contract is the smallest way to preserve the architecture boundary.

**Consequences:** README manual checks and product notes now describe fresh resume intervals in terms of current runtime settings, while AGENTS preserves the same invariant for future implementation work. Users still edit `config.json` manually today, but the docs no longer imply that runtime file edits are immediately effective.

**Alternatives Considered:** Leave README/AGENTS unchanged and rely on code/tests alone; rejected because this repo explicitly treats those docs as product and engineering invariants for future agent work.

## 2026-05-29 / Runtime Schedule Update Policies

**Date:** 2026-05-29

**Area:** Runtime settings foundation

**Context:** Task 5 introduces live duration-update behavior on top of the runtime settings store. The plan requires three different policies: active work must restart immediately only when work duration changes, break-duration-only changes during work must affect the next break without resetting the current countdown, and active-rest duration changes must preserve the visible overlay and only apply after the break finishes or is skipped.

**Decision:** Keep all schedule-update policy in `AppCoordinator`. On accepted runtime settings changes, restart the work timer immediately when the work duration changes during active work, queue break-duration-only work updates for the next work-to-rest transition, queue active-rest duration changes for the next rest-to-work transition, and keep paused-work duration changes as stored runtime state that is consumed by the existing resume path.

**Rationale:** `AppCoordinator` already owns timer replacement, break presentation, and pause/resume semantics, so it is the smallest place to adapt runtime schedules without pushing config-mutation logic into `BreakTimer` or restarting the current overlay. Separating immediate and deferred actions also preserves the plan's visible-break invariants while still making the next relevant phase use the newest settings.

**Consequences:** Runtime duration edits now follow explicit, test-locked policies across active work, paused work, natural break completion, and skip. The coordinator gained a small deferred-action state, but `BreakTimer` remains a pure countdown state machine and active-break overlays are not recreated by settings changes.

**Alternatives Considered:** Recreate `BreakTimer` on every duration change; rejected because break-duration-only work edits would incorrectly reset the current work interval and active-rest edits would disrupt the visible break. Add mutable schedule-update APIs to `BreakTimer`; rejected because the plan explicitly keeps timer/config policy out of the state machine.

## 2026-05-29 / Shared Timer Display Formatting

## 2026-05-29 / Runtime UI-only Settings Routing

**Date:** 2026-05-29

**Area:** Runtime settings foundation

**Context:** Task 4 introduces the first observer-driven runtime settings behavior. The plan requires `showStatusItemTimerState` to apply immediately, forbids recreating the timer or current overlay when that flag changes, and keeps `breakOverlayMessageText` scoped to the next break instead of mutating an already visible break.

**Decision:** Subscribe `AppCoordinator` to `RuntimeSettingsStoring` updates, route accepted changes through a small coordinator handler, and make that handler immediately call `StatusItemControlling.setShowsTimerState(_:)` while relying on the existing break-start path to pick up the latest overlay message for future breaks only.

**Rationale:** The coordinator already owns timer lifecycle plus status/overlay routing, so it is the smallest place to react to runtime settings without teaching `BreakTimer` about settings changes or pushing policy into AppKit edges. Using the current break-start lookup for message text preserves the plan's explicit "next break only" rule with no active-break mutation path.

**Consequences:** Runtime tray timer toggles now update immediately and preserve subsequent status text rendering, but active breaks keep their current title until they end or are skipped. Later schedule-update tasks can extend the same observer path for duration changes without revisiting the UI-only policy boundary.

**Alternatives Considered:** Let `RuntimeSettingsStore` reach into UI objects directly; rejected because it would blur the runtime-state and presentation boundaries. Recreate the timer or re-show the break overlay on every update; rejected because Task 4 explicitly treats these settings as UI-only and forbids current-break disruption.

## 2026-05-29 / App Coordinator Runtime Settings Source

**Date:** 2026-05-29

**Area:** Runtime settings foundation

**Context:** Task 3 moves `AppCoordinator` off the old cached `activeConfig` path and needs to prove that coordinator startup and resume behavior read from a single runtime settings source instead of repeatedly calling `ConfigStore.load()`. The plan still forbids file watching and keeps `BreakTimer` free of settings concerns, so the smallest correct change is at the coordinator boundary.

**Decision:** Let `AppCoordinator` accept an optional injected `RuntimeSettingsStoring`, lazily create a `RuntimeSettingsStore(initialSettings: loadConfig())` only when no store is supplied, and read current settings from that store for startup, resume resets, and break message lookup.

**Rationale:** This preserves existing default ergonomics for production and most tests, while giving focused tests and future Settings UI code a real runtime source-of-truth seam. Reading current settings from the store removes the old `activeConfig` cache without teaching `BreakTimer` about config reloads or adding runtime disk reads.

**Consequences:** Coordinator ticks no longer need or perform repeated config loads, injected stores can drive future runtime-update policies, and pause/resume now resets from the current runtime settings source rather than a stale launch-only copy. Actual observer-driven UI updates are still deferred to the next task.

**Alternatives Considered:** Keep the `activeConfig` cache and only wrap startup load in a store; rejected because resume and break-message paths would still read stale settings outside the new source of truth. Move runtime-settings logic into `BreakTimer`; rejected because it would violate the plan's pure state-machine boundary.

## 2026-05-29 / Config Persistence API

**Date:** 2026-05-29

**Area:** Runtime settings foundation

**Context:** Task 2 needs a persistence seam for future runtime settings updates, but the plan explicitly keeps `ConfigStore` responsible for disk I/O only and rejects file watching or hidden reloads. The runtime store from Task 1 also must stay filesystem-free, so save behavior belongs in `ConfigStore` with focused tests around directory creation, round-trip encoding, and write failure handling.

**Decision:** Add `ConfigStore.save(_:) -> Bool`, make it create the `~/Library/Application Support/Mahu` parent directory as needed, write `AppConfig` as atomic JSON to `config.json`, and report write failures through logging plus a `false` return value instead of throwing into callers by default.

**Rationale:** A boolean return is the smallest contract that lets later coordinator/runtime code detect persistence failure without entangling Task 2 with user-facing error plumbing yet. Keeping save atomic and in `ConfigStore` preserves the manual-JSON compatibility boundary, while directory creation mirrors the existing default-file bootstrap behavior.

**Consequences:** Later runtime settings flows can accept in-memory updates immediately and attempt persistence separately, which matches the plan's note that disk save failure should not force runtime rollback. Tests now lock the no-file-watcher contract together with round-trip load compatibility and deterministic failure handling.

**Alternatives Considered:** Put persistence into `RuntimeSettingsStore`; rejected because it would make the runtime source touch the filesystem and blur the launch-load/runtime-update separation. Throw save errors directly as the only API; rejected for now because Task 2 does not yet have a caller-side error presentation path and a small boolean contract is enough to keep behavior testable.

## 2026-05-29 / Runtime Settings Foundation

**Date:** 2026-05-29

**Area:** Runtime settings foundation

**Context:** The runtime-settings plan needs a single in-process source of truth before any Settings UI exists, while the repository explicitly keeps manual JSON as launch-time persistence only and rejects hidden live reloads. Task 1 only needs the seam and tests, so introducing extra model translation or a disk-aware singleton would add coupling before coordinator policies are wired.

**Decision:** Add a `@MainActor` `RuntimeSettingsStore` that stores `AppConfig` directly, exposes observer callbacks for accepted updates, and remains injectable through a `RuntimeSettingsStoring` protocol with no `ConfigStore` dependency.

**Rationale:** Reusing `AppConfig` is the smallest correct move because the persisted and runtime settings fields are still identical at this stage. MainActor isolation fits upcoming UI/coordinator usage, callback-based observation is enough for task-scoped tests and future routing, and keeping disk I/O out of the runtime store preserves the no-file-watcher/no-hidden-reload boundary.

**Consequences:** Future coordinator work can subscribe to a single runtime settings source without rereading JSON or teaching `BreakTimer` about settings changes. If later tasks require persistence on update or richer observation primitives, they can layer that around this seam instead of replacing the runtime value model immediately.

**Alternatives Considered:** Add a separate `AppSettings` model now; rejected because it would duplicate the current shape without solving an immediate problem. Let the runtime store own `ConfigStore.load()` or persistence; rejected because that would couple Task 1 to disk behavior and muddy the plan's explicit separation between launch-time config loading and runtime updates.

## 2026-05-29 / Coordinator Overlay Message Wiring

**Date:** 2026-05-29

**Area:** Coordinator overlay message wiring

**Context:** Task 4 needed the already-loaded `AppConfig.breakOverlayMessageText` to reach break presentation, but the repo explicitly keeps live config reload out of scope and avoids pushing extra display/window logic into `AppCoordinator`. The overlay manager and view model already accept message text by this point, so the remaining seam is the coordinator's rest-phase `showBreak` call.

**Decision:** Pass `activeConfig.breakOverlayMessageText` from `AppCoordinator` into `overlayManager.showBreak(...)`, keeping `AppConfig.defaultBreakOverlayMessageText` only as a defensive fallback if `activeConfig` is unexpectedly absent.

**Rationale:** `AppCoordinator.start()` already loads and caches config exactly once per launch. Reusing that cached value is the smallest correct wiring change, keeps configuration ownership out of SwiftUI/AppKit layers, and preserves the current no-live-reload contract.

**Consequences:** Coordinator tests can now prove both custom and default-message launch paths without changing overlay-manager behavior or adding new state to `BreakOverlayView`. If a future feature adds live config reload, that should be a separate coordinator/config-store change rather than piggybacking on this path.

**Alternatives Considered:** Keep sending the hardcoded default from `AppCoordinator`; rejected because it would leave the feature half-wired and make launch-loaded config ineffective at runtime. Re-read config at break start; rejected because this plan explicitly keeps live reload out of scope and would introduce hidden runtime config semantics.

## 2026-05-29 / Break Overlay View-Model Message Ownership

**Date:** 2026-05-29

**Area:** Break overlay view-model message ownership

**Context:** Task 2 needs the break overlay title to become configurable without letting `BreakOverlayView` read `AppConfig` or any config store directly. The existing view model already owns the countdown formatter and skip callback, so it is the smallest seam that can carry the title through both production and tests.

**Decision:** Add a `titleText` property to `BreakOverlayViewModel`, default it from `AppConfig.defaultBreakOverlayMessageText`, and make `BreakOverlayView` render that property instead of a hardcoded string.

**Rationale:** This keeps the SwiftUI layer data-driven and leaves config ownership outside the view code, which matches the repo's AppKit/SwiftUI boundary guidance. Reusing the existing view model also avoids adding another wrapper type or passing parallel title state through the view tree.

**Consequences:** Task 3 and Task 4 can later wire the configured message through `BreakOverlayManager` and `AppCoordinator` without changing `BreakOverlayView` again. Tests can now prove both the default and custom Unicode title rendering together with the existing countdown and `Skip` behavior.

**Alternatives Considered:** Keep the hardcoded title in `BreakOverlayView` and swap it later in Task 4; rejected because that would force a larger cross-task UI change and keep the view non-data-driven longer than necessary. Let `BreakOverlayView` read `AppConfig.defaultBreakOverlayMessageText` directly; rejected because the feature contract explicitly keeps config access out of SwiftUI view code.

## 2026-05-29 / Break Overlay Message Config Contract

**Date:** 2026-05-29

**Area:** Break overlay message config contract

**Context:** The break overlay currently hardcodes `Время отвлечься`, but the new feature needs a config-backed message without breaking existing manually edited `config.json` files. The repo already has an established config contract: omitted optional keys decode to safe defaults, while explicit invalid values fail decoding and make `ConfigStore.load()` fall back to `AppConfig.default`.

**Decision:** Add `breakOverlayMessageText: String` to `AppConfig`, make `AppConfig.default` encode it as `Время отвлечься`, decode a missing key as that default, normalize empty or whitespace-only strings back to the default, and keep `null` or non-string values on the existing whole-config fallback path by decoding them as required strings when present.

**Rationale:** Missing-key-as-default preserves backward compatibility for already-written config files. Blank-string normalization gives users a predictable fallback instead of shipping an invisible title, and reusing the current decode-failure path for `null` and wrong types keeps malformed-manual-edit behavior consistent with the rest of the config surface.

**Consequences:** Task 1 can stay localized to `AppConfig` plus config tests; `ConfigStore` does not need custom field-specific recovery logic. Future overlay wiring can trust `activeConfig.breakOverlayMessageText` to always contain a non-empty string.

**Alternatives Considered:** Treat blank strings as valid and render them literally; rejected because it would allow an effectively missing overlay title and conflict with the feature's default-message intent. Add custom `ConfigStore` repair logic for `null`; rejected because it would split one field away from the repo's established invalid-config fallback contract.

## 2026-05-29 / Break Overlay Message Documentation Contract

**Date:** 2026-05-29

**Area:** Break overlay message documentation contract

**Context:** The configurable overlay title is now implemented in config, view model, overlay manager, and coordinator tests, but the human-facing docs still described the break screen as always showing the hardcoded Russian text. This creates a drift risk because future agents rely on `README.md` and `AGENTS.md` to understand shipped behavior and config guarantees.

**Decision:** Update `README.md` and `AGENTS.md` so they describe `breakOverlayMessageText` as a shipped config-backed break title, preserve `Время отвлечься` as the default when the field is missing or blank, and document that `null` or wrong types still trigger the existing whole-config fallback behavior.

**Rationale:** This is the smallest durable way to keep product docs aligned with the implemented config contract and prevent future work from accidentally re-hardcoding the title or misdocumenting malformed-config behavior.

**Consequences:** Humans now have a correct config example and manual verification path for custom Unicode titles. Future agents can treat the configurable title as an invariant rather than rediscovering it from tests or source.

**Alternatives Considered:** Leave docs unchanged because the code and tests already prove behavior; rejected because Mahu's workflow explicitly treats README and AGENTS as durable product guidance, and stale docs would mislead both humans and future agents. Document only the default message without the config key; rejected because it would hide the shipped customization surface and the backward-compatibility rules.

## 2026-05-29 / Tray Timer Plan Archival

**Date:** 2026-05-29

**Area:** Tray timer plan archival

**Context:** The optional tray-timer implementation and Task 7 close-out were already complete, but the plan file still lived in `docs/plans/` without a completed-status marker. README and the repo's prior completed-plan fixes both treat `docs/plans/` as the active queue and `docs/plans/completed/` as the archive, so the branch state still implied unfinished work even after all feature checkboxes were marked done.

**Decision:** Move `2026-05-29-optional-tray-timer-display.md` into `docs/plans/completed/` and add `Status: Completed (2026-05-29)` near the top of the archived file.

**Rationale:** This is the smallest truthful fix for the review finding. It keeps the active-plan queue aligned with actual unfinished work and matches the archival pattern already used for other completed Mahu plans.

**Consequences:** Future agents and review loops will no longer treat the optional tray-timer feature as still active just because its plan file remained in the wrong directory. If later follow-up work reopens this area, it should start from a new active plan instead of mutating the archived execution record.

**Alternatives Considered:** Leave the file in `docs/plans/` because the checkboxes are already complete; rejected because that still contradicts README and prior archival conventions. Add only a completed-status line without moving the file; rejected because the active directory would still mix open and closed plans.

## 2026-05-29 / Tray Timer Plan Close-Out

**Date:** 2026-05-29

**Area:** Tray timer plan close-out

**Context:** Tasks 1 through 6 for the optional tray-timer feature were completed and validated in order, leaving only the final close-out section. The remaining ambiguity was not code scope but acceptance scope: XCTest proves config, formatting, controller wiring, coordinator updates, and build/package success, yet native menu-bar width, truncation, and spacing still depend on live `NSStatusItem` rendering.

**Decision:** Keep the plan sequence unchanged, mark Task 7 complete with an explicit "no deviation" note, and add a Post-Completion manual-check bullet that calls out live `NSStatusItem` width/truncation/spacing as manual-only acceptance.

**Rationale:** This closes the plan truthfully without inventing extra implementation work or leaving the final task open for an unautomatable UI detail. It also makes the remaining risk explicit for future humans or agents running the built app.

**Consequences:** The plan can now be considered implementation-complete, while real menu-bar rendering proof remains a separate manual activity. If future automation adds reliable live menu-bar UI inspection, this manual limitation can be narrowed or removed.

**Alternatives Considered:** Leave Task 7 open until someone performs manual checks; rejected because the task is specifically about plan close-out and would keep the automation loop running on non-automatable work. Treat the current Post-Completion readability note as sufficient; rejected because Task 7 asked for newly discovered manual limitations, and controller-state tests still do not cover actual width/truncation behavior.

## 2026-05-29 / Tray Timer Documentation Contract

**Date:** 2026-05-29

**Area:** Tray timer documentation contract

**Context:** The optional tray timer display is already implemented behind `showStatusItemTimerState`, but `README.md` and `AGENTS.md` still described timer text as deferred and did not spell out the shipped config contract or manual verification split between icon-only and timer-display modes.

**Decision:** Update `README.md` and `AGENTS.md` so they describe icon-only mode as the default, document `showStatusItemTimerState` as the enabling config key for icon-plus-text/`Paused` behavior, remove the old deferred-feature claim, and keep real menu-bar readability checks explicit in the manual verification sections.

**Rationale:** Future agents rely on these docs as product invariants; if they stay in the pre-feature state, they will treat shipped behavior as out of scope and risk undoing or misdocumenting the tray timer contract.

**Consequences:** Documentation now matches runtime behavior and test coverage: icon-only remains the default, tray timer mode is an opt-in config behavior, and visual menu-bar proof still requires manual checks. If a later Settings UI exposes this option, the docs should add that control surface without changing the underlying default contract.

**Alternatives Considered:** Keep the docs generic and mention only that status-item behavior is configurable; rejected because the exact config key and default behavior are part of the shipped manual-config contract. Leave `AGENTS.md` unchanged and document only in `README.md`; rejected because project invariants would remain stale for future implementation tasks.

## 2026-05-29 / Coordinator-to-Status Timer Wiring

**Date:** 2026-05-29

**Area:** Coordinator-to-status timer wiring

**Context:** The optional tray timer mode already had a config flag, formatter, and `StatusItemController` support, but the live app still needed coordinator-driven updates on startup, work/rest ticks, pause, resume, skip, and natural break completion. The wiring had to avoid pushing AppKit presentation decisions into `AppCoordinator.swift`, which is already near the local readability threshold.

**Decision:** Extend `StatusItemControlling` with `setShowsTimerState(_:)` and `setStatusDisplayState(_:)`, let `AppCoordinator.start()` configure the mode from launch-loaded config, and push semantic `.active(...)` state updates from a small helper inside `handle(state:)` while leaving paused-text override behavior inside `StatusItemController`'s existing `setRemindersPaused(_:)` path.

**Rationale:** This keeps the coordinator responsible only for semantic timer lifecycle state and preserves AppKit-specific string/title/image behavior at the status-item edge. Reusing the controller's paused override avoids duplicating `Paused` rendering rules or adding display-string knowledge to `AppCoordinator`.

**Consequences:** Coordinator tests can now prove status-item updates across launch, work/rest ticks, pause/resume, skip, and natural completion with a fake seam. If future surfaces need the same semantic timer state, they can reuse `StatusDisplayState` without depending on AppKit.

**Alternatives Considered:** Have `AppCoordinator` compute final display strings or paused text directly; rejected because that leaks presentation rules into orchestration code. Push raw `BreakTimer.State` into `StatusItemController`; rejected because the coordinator-to-view seam would then expose a timer implementation detail instead of the smaller shared display model.

## 2026-05-29 / Status Item Timer-Mode Presentation

**Date:** 2026-05-29

**Area:** Status item timer-mode presentation

**Context:** The new config-backed tray timer mode needs `StatusItemController` to render the same tray icon together with timer text or `Paused`, but Mahu must keep icon-only behavior and menu semantics unchanged by default. Re-fetching the icon on every pause/timer update would also break the existing "same image instance" contract that current pause/resume wiring tests already rely on.

**Decision:** Keep `StatusItemController` icon-only by default, add small concrete-only setters for enabling timer mode and passing `StatusDisplayState`, switch the status item to `NSStatusItem.variableLength` only in timer mode, and cache the initially installed icon so later text/pause updates reuse the same image instance while paused state overrides the visible title to `Paused`.

**Rationale:** This localizes all AppKit title/length/image-position behavior to the status-item edge, preserves the default square icon-only contract, and leaves protocol/coordinator expansion for the next task instead of bloating `AppCoordinator` early. Caching the icon avoids unnecessary provider churn and keeps the existing runtime identity behavior stable across pause/resume transitions.

**Consequences:** Future Task 4 can wire launch/tick/pause updates through explicit status-display methods without changing how timer strings are formatted. Real menu-bar readability and truncation remain manual checks because XCTest cannot prove native menu-bar rendering details.

**Alternatives Considered:** Move timer-mode state into `AppCoordinator` now; rejected because Task 3 is scoped to the controller edge and `AppCoordinator.swift` is already near the local readability threshold. Always use `variableLength`; rejected because icon-only mode must remain visually and behaviorally unchanged by default.

**Date:** 2026-05-29

**Area:** Shared timer display formatting

**Context:** The optional tray timer display needs AppKit-free text generation for active work, active rest, and paused states, but Mahu already has countdown string logic embedded in `BreakOverlayViewModel`. Leaving overlay and status item formatting separate would duplicate `safeDisplayWholeSeconds` edge-case handling and make future formatting changes easy to drift.

**Decision:** Introduce a small `StatusDisplayState` model plus `StatusDisplayFormatter`, make it own `MM:SS` and `Paused` rendering, and reuse it from `BreakOverlayViewModel` for countdown text instead of keeping a second formatter there.

**Rationale:** A dedicated formatter keeps text generation out of `AppCoordinator` and `BreakTimer`, satisfies the new status-item seam without AppKit dependencies, and gives one deterministic place to test negative, fractional, non-finite, and very large durations.

**Consequences:** Future status-item wiring can pass semantic state into the formatter directly, while overlay countdowns stay behaviorally unchanged but now share the same formatting contract. If a later feature needs different wording per surface, that should be modeled explicitly rather than reintroducing duplicated ad-hoc formatting.

**Alternatives Considered:** Keep formatting only inside `BreakOverlayViewModel` and add a second status-item formatter later; rejected because it duplicates edge-case logic immediately. Put formatting helpers on `AppConfig`; rejected because config should remain about validation/defaults, not UI state rendering.

## 2026-05-29 / Status Item Timer Config Contract

**Date:** 2026-05-29

**Area:** Status item timer config contract

**Context:** The optional menu-bar timer display is config-backed, but Mahu already ships user-editable `config.json` files and defaults to icon-only tray behavior. The new key must not break existing configs that omit it, and malformed manual edits should continue using the current safe fallback path instead of creating partial or ambiguous runtime state.

**Decision:** Add `showStatusItemTimerState: Bool` to `AppConfig`, make `AppConfig.default` encode it as `false`, decode a missing key as `false`, and let non-boolean values fail decoding so `ConfigStore.load()` falls back to `.default` through the existing invalid-config behavior.

**Rationale:** Missing-key-as-false preserves backward compatibility for already-written config files and keeps icon-only as the default shipped UX. Reusing the current decode-failure fallback for invalid types avoids inventing a second recovery rule for one manual-config field and keeps the whole config contract consistent.

**Consequences:** Existing configs without the new key continue loading as icon-only. New default configs persist the key explicitly, which makes the available option discoverable. If future config surface grows further, the same pattern can be reused for optional backward-compatible booleans, but field-by-field silent coercion should still be avoided.

**Alternatives Considered:** Treat invalid non-boolean values as `false`; rejected because it hides manual config mistakes and diverges from the repo's existing invalid-config fallback semantics. Omit the key from encoded defaults; rejected because the feature would be less discoverable in the generated config file and harder to document consistently.

## 2026-05-28 / Break Completion Sound Seam

## 2026-05-29 / Break Completion Sound Documentation Contract

**Date:** 2026-05-29

**Area:** Break completion sound documentation contract

**Context:** The runtime sound contract now differs from the checked-in source filename: the editable source asset remains `source-assets/11labs-sound-sample.caf`, while the shipped app bundle exposes `Mahu/Resources/break-completion.caf`. README and build-verification text still serve as the human-facing source of truth for that bundle contract.

**Decision:** Document `break-completion.caf` as the only runtime completion-sound filename in README and bundle-verification guidance, and treat the source-asset filename as implementation/staging detail only.

**Rationale:** Keeping one documented runtime name avoids future stale `sound.wav` references and makes it clear which filename must exist inside the app bundle versus which one is only edited in the repository.

**Consequences:** Human verification steps, build notes, and future plan work should reference `break-completion.caf` when talking about shipped behavior. This works for the current single bundled clip; if the app later supports user-selectable sounds, the docs will need to describe configuration rather than a single fixed bundle filename.

**Alternatives Considered:** Document both filenames interchangeably; rejected because it blurs the boundary between source asset and shipped runtime contract. Keep README wording generic without naming the resource; rejected because the repo intentionally uses explicit bundle-resource checks in tests and `make build`.

## 2026-05-29 / Break Completion Sound Runtime Format

**Date:** 2026-05-29

**Area:** Break completion sound runtime format

**Context:** The runtime completion sound is being switched from the earlier bundled WAV contract to a checked-in CAF source file, and Task 3 now converts the playback edge from `NSSound` to AVFoundation while keeping the coordinator seam and non-fatal failure behavior intact. The previous 2026-05-29 source-asset decision kept `sound.wav` only to minimize churn before the newer CAF-specific implementation plan was approved.

**Decision:** Bundle the completion sound as `Mahu/Resources/break-completion.caf`, resolve that filename from `BreakCompletionSoundPlayer`, and use `AVAudioPlayer(contentsOf:)` plus `prepareToPlay()`/`play()` for local playback instead of `NSSound`.

**Rationale:** The source asset is already CAF, so keeping a CAF runtime resource avoids unnecessary transcoding or dual-format maintenance. `AVAudioPlayer` is the standard public API for bundled local audio playback on macOS and gives an explicit initialization failure path that matches the desired warning-only behavior. The stable runtime name `break-completion.caf` keeps the bundle contract clear without exposing the human source filename with spaces.

**Consequences:** Resource lookup, tests, build checks, and docs must now point at `break-completion.caf`, and the earlier "keep runtime sound.wav" decision is superseded for this feature. This works for the current single bundled clip; if Mahu later needs richer playback control or multiple simultaneous sounds, `AVAudioEngine` would be the better alternative.

**Alternatives Considered:** Keep bundling `sound.wav`; rejected because the approved plan now standardizes on CAF and the extra conversion path adds maintenance with no product benefit. Keep `NSSound`; rejected because the current task needs an explicit AVFoundation-backed seam with prepare/init failure coverage.

**Date:** 2026-05-28

**Area:** Break completion sound seam

**Context:** The new break-completion sound must come from bundled `sound.wav`, play only through app-edge code, and never block timer or overlay cleanup if the resource is missing, empty, undecodable, or unplayable. `AppCoordinator.swift` is already near the local readability threshold, and `BreakTimer` must remain a pure state machine without bundle or audio knowledge.

**Decision:** Add a dedicated `BreakCompletionSoundPlayer` type with a small `BreakCompletionSoundPlaying` protocol, keep bundle lookup and `NSSound` playback inside that type, and make the live player fail gracefully through resource-size checks plus decode/play guards instead of surfacing errors into timer state logic.

**Rationale:** This keeps audio as an AppKit edge effect that can be injected into coordinator tests later without spreading playback logic through timer code or view models. The extra seam also gives deterministic, no-speaker unit coverage for missing and broken resource cases.

**Consequences:** Future Task 4 can wire sound playback into `AppCoordinator` with a narrow dependency instead of direct `NSSound` calls. Missing or malformed `sound.wav` will quietly skip playback while logs preserve a debugging signal. Real speaker output still remains manual-only verification.

**Alternatives Considered:** Play `NSSound` directly from `AppCoordinator`; rejected because it would couple timer-flow code to bundle lookup and AppKit playback. Put audio logic in `BreakTimer`; rejected because it breaks the state-machine purity contract.

## 2026-05-28 / Break Completion Sound Trigger

**Date:** 2026-05-28

**Area:** Break completion sound trigger

**Context:** The sound player seam and coordinator semantics tests already existed, but the live app still did not decide exactly when playback should happen. The product contract requires one sound only when a visible break ends naturally, with no sound for `Skip`, work-to-break, pause/resume, failed overlay presentation, or hidden-overlay timing paths.

**Decision:** Let `AppCoordinator` trigger `BreakCompletionSoundPlaying.playBreakCompletionSound()` only after `consumeElapsedTime(...)` crosses from `.rest` to `.work` during a tick that started with a visible overlay, and only after normal overlay teardown has already run.

**Rationale:** `AppCoordinator` already owns the work/rest lifecycle and can distinguish natural completion from `Skip` or retry paths without polluting `BreakTimer` or overlay view types. Playing after `handle(state:)` keeps overlay cleanup first, so audio failure cannot block break teardown.

**Consequences:** Natural visible break completion now produces a single sound through the injected seam, while hidden-overlay and retry paths remain silent. Tests can lock the behavior with fakes and without asserting real speaker output.

**Alternatives Considered:** Trigger sound from `skipBreak()` or generic `.work` handling; rejected because those paths cannot distinguish natural completion from unrelated transitions. Trigger sound before overlay teardown; rejected because it would unnecessarily couple playback timing to UI cleanup order.

## 2026-05-28 / Break Completion Sound Close-Out

**Date:** 2026-05-28

**Area:** Break completion sound close-out

**Context:** The break-completion sound feature already had production code, tests, README updates, and decision history, but the fully checked-off execution plan still lived in the active `docs/plans/` queue and `docs/session-handoff.md` did not contain a durable close-out entry for this shipped feature.

**Decision:** Move the finished sound plan into `docs/plans/completed/`, add a completion status header to the archived plan, sync README's plan inventory to the archived path, and record the feature close-out in `docs/session-handoff.md`.

**Rationale:** This repo already uses archived plan files plus durable handoff notes as the source of truth for finished work. Leaving the plan in the active queue or keeping the close-out only in chat makes the project look partially incomplete to the next agent or reviewer.

**Consequences:** Plan discovery now reflects the real state of the sound feature, and future review loops can treat the feature as fully closed except for the explicitly documented manual audio checks. Runtime behavior and automated validation remain unchanged.

**Alternatives Considered:** Leave the plan in `docs/plans/` with all boxes checked; rejected because it weakens the repo's completed-plan convention. Record closure only in conversation; rejected because the task contract requires a durable artifact.

## 2026-05-28 / Paused Icon Wiring Coverage

**Date:** 2026-05-28

**Area:** Paused icon wiring coverage

**Context:** The paused-icon branch already had direct `StatusItemController` tests and `AppCoordinator` tests with a fake status controller, but nothing exercised the real `NSMenuItem -> AppCoordinator -> StatusItemController.setRemindersPaused(...)` path. That left a gap where callback ordering or wiring regressions could break live pause/resume behavior while unit suites stayed green, and it also left the existing-icon preservation contract unproven across pause/resume transitions.

**Decision:** Add one integration-style XCTest using a real temporary `NSStatusItem`, a live `StatusItemController`, and real pause/resume menu item invocation through `AppCoordinator.start()`, then assert the menu titles, dimming band, and same icon instance across both transitions.

**Rationale:** One focused AppKit-backed test closes the real wiring gap without introducing UI automation, new production seams, or more duplicate assertions in already-covered controller-only tests.

**Consequences:** Review coverage now protects the production menu wiring path and the "dim the existing icon" contract together. The test still cannot prove human-perceived readability in the macOS menu bar, so light/dark/high-contrast validation remains manual-only.

**Alternatives Considered:** Keep relying on separate unit suites; rejected because they do not prove the live menu dispatch path. Add UI automation; rejected because the repo intentionally has no UI E2E harness and the requirement can be covered deterministically in XCTest.

## 2026-05-28 / Paused Icon Plan Archival

**Date:** 2026-05-28

**Area:** Paused icon plan archival

**Context:** The paused-icon implementation plan reached a fully checked-off state and the feature already had code, tests, README updates, decisions, and handoff notes, but the plan file itself still lived under `docs/plans/` instead of the completed archive used by the rest of the repo.

**Decision:** Move `2026-05-28-paused-reminders-dimmed-icon.md` into `docs/plans/completed/`, mark it explicitly as completed in the file header, and update README plan references to the archived location.

**Rationale:** The repo's documentation flow already archives finished implementation plans so the active queue reflects only unfinished work. Keeping a finished plan in the active directory creates avoidable ambiguity for the next agent or reviewer reading the plan list.

**Consequences:** Plan discovery now reflects the true state of the project, and README project-structure references point at the final archived artifact instead of an apparently active task file. The feature behavior, tests, and manual checks remain unchanged.

**Alternatives Considered:** Leave the plan in `docs/plans/` and rely only on checked boxes; rejected because the repo already records a stronger completed-plan convention and prior plan work follows it consistently.

## 2026-05-28 / Paused Icon Acceptance Contract

**Date:** 2026-05-28

**Area:** Paused icon acceptance contract

**Context:** The paused-icon implementation already documents an acceptable dimming range around `0.45...0.60`, but an acceptance test had started asserting the exact current tuning value `0.5`, which would fail on future visual polish even if the feature still met its user-visible contract.

**Decision:** Keep the production alpha tuning local to `StatusItemController`, but make acceptance coverage assert a dimmed range rather than one exact paused alpha constant.

**Rationale:** The feature contract is that the tray icon becomes visibly dimmer while remaining recognizable and usable. Locking the exact implementation constant in acceptance coverage makes later menu-bar readability tuning look like a regression when behavior has not actually changed.

**Consequences:** Future paused-icon tuning can move within the documented band without forcing unrelated acceptance rewrites, while lower-level tests still prove that the icon does become dimmer than its enabled state.

**Alternatives Considered:** Keep the exact `0.5` assertion; rejected because it overfits an implementation detail instead of the behavior promised by the plan and README.

## 2026-05-28 / Paused Reminder Icon State

**Date:** 2026-05-28

**Area:** Paused reminder icon state

**Context:** The pause/resume menu feature already exposed the reminder-enabled state through menu titles, but the new follow-up requires a visual paused cue in the tray without changing timer semantics or adding a second asset variant.

**Decision:** Keep the same `TrayIconTemplate` image path and implement the paused cue entirely inside `StatusItemController` by applying a lower alpha value to the existing status item button when reminders are paused, then restoring full opacity when reminders resume.

**Rationale:** The status item layer already owns AppKit presentation state, so dimming there is the smallest correct change. It preserves the existing asset contract and keeps the button/menu interactable, avoiding the misleading disabled-control behavior that `isEnabled = false` would introduce.

**Consequences:** Pause/resume remains a coordinator-owned semantic change, while tray presentation stays localized to the AppKit edge. Manual menu-bar readability validation is still required because XCTest can prove state transitions, not live menu-bar rendering quality.

**Alternatives Considered:** Add a second paused icon asset; rejected because the plan and product constraints require reusing the existing template asset. Disable the status item button to get a dimmed appearance for free; rejected because it risks breaking click/menu interaction and communicates the wrong UI state.

## 2026-05-28 / App Coordinator Support Refactor

**Date:** 2026-05-28

**Area:** App coordinator support refactor

**Context:** `AppCoordinator.swift` grew past the local readability threshold after pause/resume, paused-icon, and break-completion sound work. The runtime behavior was already correct, but the file mixed orchestration logic with coordinator-facing protocols, scheduler/typealias declarations, and concrete conformance glue that did not need to stay inline.

**Decision:** Extract the coordinator support declarations into `Mahu/AppCoordinatorSupport.swift`, keeping `AppCoordinator.swift` responsible only for orchestration flow, state, and lifecycle methods while leaving timer, status-item, overlay, and sound ownership unchanged.

**Rationale:** This is the smallest behavior-neutral refactor that lowers cognitive load without introducing new abstractions or moving product semantics into the wrong layer. Existing coordinator regression tests already prove the contract better than structure-only assertions would.

**Consequences:** Future coordinator work has a clearer seam: support types live in a focused file, while orchestration changes remain isolated to `AppCoordinator.swift`. This works for the current scope, but if future features push elapsed-time accounting into similar complexity, that logic should be extracted in a separate explicitly planned refactor rather than folded into this one.

**Alternatives Considered:** Leave everything in `AppCoordinator.swift`; rejected because the file had already crossed the local readability threshold. Extract deeper helper objects now; rejected because the current regression-tested behavior does not require more structural change and a larger refactor would increase risk.

## 2026-05-28 / Refactor Plan Archival

**Date:** 2026-05-28

**Area:** Refactor plan archival

**Context:** The `AppCoordinatorSupport` refactor plan had every task checkbox completed, but the file still lived in `docs/plans/` and `README.md` maintained a brittle per-file list of archived plans that had already fallen out of sync with the repository.

**Decision:** Move completed refactor plans into `docs/plans/completed/`, add an explicit completed status line to the archived plan, and document the plan layout in `README.md` at the directory level instead of enumerating every archived plan file.

**Rationale:** Future review loops and agents use `docs/plans/` as the active queue. Leaving completed work there creates false ambiguity. Directory-level README guidance is more stable than a hand-maintained list that drifts every time a plan is archived.

**Consequences:** The active plan queue stays trustworthy, and README no longer needs per-plan churn for every archival move. Readers still know where active and completed execution history lives, but detailed plan discovery moves to the filesystem rather than a fragile static inventory.

**Alternatives Considered:** Keep the plan in `docs/plans/`; rejected because it makes completed work look active. Keep enumerating every archived plan in README; rejected because it had already drifted and creates recurring documentation debt.

## 2026-05-26 / Reminder Pause/Resume Semantics

**Date:** 2026-05-26

**Area:** Reminder pause/resume semantics

**Context:** The new tray-menu controls needed a precise behavioral contract before documentation could be finalized: users asked for pause/resume reminders, but the product still should not gain a break-phase pause mechanism, persisted reminder-disable state, or a partial-countdown continuation on resume.

**Decision:** Model the feature as a runtime-only reminder-enabled flag owned by `AppCoordinator`. While paused, work-phase ticks become a no-op and no new break overlay can start. When the user resumes during the work phase, Mahu rebuilds `BreakTimer` from the current config and starts a fresh full work interval instead of continuing the old remainder.

**Rationale:** This keeps the AppKit menu layer dumb, preserves the existing break overlay and `Skip` contract, and gives the user predictable semantics that do not depend on remembering partially elapsed background time. It also avoids pushing reset/pause behavior into `BreakTimer`, whose responsibility remains work/rest countdown progression.

**Consequences:** README and tests now describe pause/resume as reminder disable/enable semantics rather than timer suspension. Pause state is intentionally lost on restart, and active breaks continue unchanged if the tray action is used during rest.

**Alternatives Considered:** Pause and later continue the partially elapsed work countdown; rejected because it creates more stateful semantics with less predictable UX and complicates coordinator/test behavior. Add a true break-pause feature or persist the paused flag; rejected because both are outside MVP scope.

**Date:** 2026-05-25

**Area:** Tray icon retina asset verification

**Context:** The second external review pass found that `tray-icon-template@2x.png` was a 36x36 canvas carrying the same 1x-sized glyph pixels as the non-Retina asset, so the menu bar still shipped a visibly undersized Retina icon while the existing regression test stayed green.

**Decision:** Regenerate `tray-icon-template@2x.png` as a genuinely larger glyph mask, move tray-asset assertions into a focused `TrayIconAssetTests.swift` file, and validate raw raster metrics via `CGImageSource` plus explicit `@2x`-vs-`1x` glyph-scale checks instead of relying on `NSImage`-derived bitmap data alone.

**Rationale:** Canvas size and transparent corners prove only that the file is a transparent PNG, not that it is a real Retina asset. Raw decoded pixels are the durable contract, and the dedicated test file keeps `StatusItemControllerTests.swift` under the local readability threshold while strengthening the review-proof coverage.

**Consequences:** Future regressions where a Retina tray asset silently contains a 1x mask on a larger canvas will fail deterministically in XCTest. Final menu-bar readability still remains a manual hardware-backed check because XCTest cannot prove WindowServer rendering quality.

**Alternatives Considered:** Keep the old test and rely on manual menu-bar inspection; rejected because the broken `@2x` asset already escaped once. Add the new assertions to `StatusItemControllerTests.swift`; rejected because that file was already near the local 300-line cognitive-load threshold.

## 2026-05-25 / Tray Icon Documentation Contract

**Date:** 2026-05-25

**Area:** Tray icon documentation contract

**Context:** The tray asset work is functionally complete, but Task 5 still needs the durable documentation to match what actually shipped: the menu-bar icon is now a transparent glyph-only template image, and the implementation had to fall back from automated mask extraction to a directly drawn simplified silhouette when that pipeline produced an empty tray PNG in this environment.

**Decision:** Document `TrayIconTemplate` as transparent-background glyph-only template artwork with manual-only readability verification in the real menu bar, and explicitly allow a directly drawn simplified lotus silhouette derived from the app icon motif when auto-extracting a tray mask from `icon.png` fails or becomes unreadable at 18 pt.

**Rationale:** The product contract is about the resulting menu-bar silhouette and transparent alpha behavior, not about preserving one fragile generation method. Capturing the fallback generation constraint prevents future agents from reintroducing an opaque square raster or wasting time trying to force a brittle asset script that emits an empty mask.

**Consequences:** README and plan guidance now match the shipped tray icon behavior and the known generation edge case. Automated tests continue proving dimensions and transparency, while final legibility across light, dark, and highlighted menu-bar states remains manual validation.

**Alternatives Considered:** Require regeneration strictly from an automated transform of the full `icon.png`; rejected because that pipeline already produced empty output here and the contract does not depend on the generator. Reuse the scaled app icon raster; rejected because it reintroduces the visible square background regression.

## 2026-05-25 / Tray Icon Glyph Regeneration

## 2026-05-25 / Tray Icon Contract Verification

**Date:** 2026-05-25

**Area:** Tray icon contract verification

**Context:** Task 3 is explicitly about proving that the tray-icon contract did not drift after the asset regeneration. The code already preserved the desired behavior, but the automated checks still lacked direct proof that the app remains menu-bar-only via `LSUIElement` in `Info.plist`.

**Decision:** Keep `StatusItemController` implementation unchanged for this task and extend the XCTest suite with a direct `Info.plist` assertion for `LSUIElement = true`, relying on the existing tests for tray-asset preference, 18x18 template resizing, icon-only installation, and Quit-only menu behavior.

**Rationale:** The smallest truthful change is stronger proof, not more runtime code. Touching the already-correct status-item implementation would add regression risk without improving the shipped contract.

**Consequences:** Task 3 now has deterministic coverage for both runtime status-item behavior and the no-Dock menu-bar app plist flag. Visual appearance in the real menu bar is still manual-only verification.

**Alternatives Considered:** Add new production code to re-enforce the same contract at runtime; rejected because the current implementation already satisfies the requirements and extra code would duplicate behavior without adding real resilience.

**Date:** 2026-05-25

**Area:** Tray icon glyph regeneration

**Context:** Task 2 needed to replace the opaque square tray raster with transparent template artwork. While doing that, the direct XCTest revealed that standalone `@2x` PNG files can report loader-dependent `NSImage.size` values that do not reflect the real source raster stored on disk.

**Decision:** Use a simplified monochrome lotus glyph on transparent background for `TrayIconTemplate`, keep the asset-catalog metadata unchanged, and treat decoded bitmap dimensions plus alpha coverage as the durable proof for the source tray PNGs instead of relying on Cocoa point-size semantics for the raw `@2x` file.

**Rationale:** The status item needs a small, template-friendly non-square silhouette derived from the app icon motif. For source-asset regression coverage, real pixel raster and transparency are the stable contract; `NSImage.size` on raw Retina-named PNG files is a presentation detail of the loader, not the underlying asset quality the plan is trying to preserve.

**Consequences:** The tray icon update stays asset-only and keeps `StatusItemController` unchanged, while the regression test now proves the right thing about the source files. Final readability in the actual menu bar still requires manual checking across light, dark, and highlighted states.

**Alternatives Considered:** Keep extracting a mask automatically from the full-color icon; rejected because repeated generator variants produced unstable empty output at 18 pt in this environment. Keep the original `NSImage.size` assertion for the raw `@2x` file; rejected because it can fail or pass based on filename/loader semantics even when the actual 36x36 raster is correct.

## 2026-05-22 / Overlay Content Centering Implementation

**Date:** 2026-05-22

**Area:** Overlay content centering implementation

**Context:** The break overlay foreground was horizontally shifted on the built-in MacBook display after the runtime background-image fix, while the external monitor still looked correct.

**Decision:** Keep the fix entirely inside `BreakOverlayView` by sizing the root `ZStack`, background image, readability layer, and foreground frame to `GeometryReader` bounds, and clip the `scaledToFill` background inside those explicit window dimensions.

**Rationale:** The regression comes from image-crop layout expansion on non-16:9 windows, not from window creation or display enumeration. Explicit geometry sizing recenters the foreground within the real overlay window without introducing display-specific offsets or AppKit hosting changes.

**Consequences:** Foreground centering is now coupled to visible window bounds instead of the cropped image size. Automated proof remains at the SwiftUI layout-contract level plus existing foreground/view-model coverage; live pixel-perfect centering on real displays is still a manual check.

**Alternatives Considered:** Add hardcoded offsets for the MacBook display; rejected because that would likely regress other aspect ratios. Change `BreakOverlayManager` or `NSHostingView` sizing; rejected because the SwiftUI-only fix is smaller and matches the observed failure mode.

## 2026-05-22 / Overlay Active Window Tracking

## 2026-05-23 / Review-Pass Hardening

**Date:** 2026-05-23

**Area:** Review-pass hardening

**Context:** The second tray-icon review pass surfaced two verified runtime problems outside the icon asset itself: `ConfigStore` could still open special filesystem objects at the user config path and block startup, and an active break could lose every visible overlay during a transient zero-display transition while the timer kept consuming hidden rest time. The same pass also hit the local readability guard because `BreakOverlayManager.swift` was already above the 300-line refactor signal.

**Decision:** Accept `config.json` only when the path is a regular file or a symlink that resolves to a regular file, treat all other filesystem objects as invalid config with fallback defaults, keep filesystem error details private in logs, pause active-break timer consumption whenever the overlay layer has no visible windows, close current overlay windows while preserving the shared break state during zero-display snapshots, recreate them from the same `BreakOverlayViewModel` when a display returns, and move display-reconciliation helpers into `BreakOverlaySupport.swift` instead of adding more lifecycle code directly to `BreakOverlayManager.swift`.

**Rationale:** Named pipes, devices, directories, and bad symlink targets are all invalid config surfaces for a user-edited JSON file and can wedge launch if treated like ordinary files. During an active break, invisible countdown consumption breaks the product contract more severely than briefly pausing the timer until a display returns. Extracting reconciliation logic keeps the fix reviewable and avoids pushing an already-large file further past the local cognitive-load guard.

**Consequences:** Startup now falls back cleanly on special-file config paths, sensitive filesystem diagnostics no longer leak through public OSLog interpolation, and transient all-display loss preserves the same break countdown and `Skip` state until overlays are visible again. Future overlay changes should continue to keep display-window diffing in shared support rather than re-expanding `BreakOverlayManager.swift`.

**Alternatives Considered:** Reject all symlinks outright; rejected because a symlink to a regular user-owned config file is still a reasonable local setup and can be validated safely enough for this app. Keep consuming rest time while no displays exist; rejected because it allows a whole break to finish without ever being shown. Add the zero-display pause entirely inside `AppCoordinator`; rejected because the overlay layer already knows when no windows are visible and the user requirement is specifically about display-driven overlay behavior.

**Date:** 2026-05-22

**Area:** Overlay active window tracking

**Context:** Display hot-plug support needs the overlay layer to know which live window belongs to which display, but Task 2 should not yet implement display reconciliation or change external break behavior.

**Decision:** Replace `BreakOverlayManager`'s internal plain window array with display-bound active overlay records that store both `DisplayDescriptor` and `BreakOverlayWindowing`, and keep show/hide/focus flows operating on those records.

**Rationale:** The next hot-plug task needs display identity for add/remove/replace decisions. Introducing that identity now is the smallest refactor that preserves current `showBreak()`, `hideBreak()`, `Skip`, observer teardown, and focus-retention semantics.

**Consequences:** Overlay lifecycle behavior stays externally unchanged, while future screen-change handling can reconcile windows incrementally instead of rebuilding everything blindly. `BreakOverlayManager.swift` remains near the cognitive-load threshold, so later hot-plug logic should stay tightly scoped.

**Alternatives Considered:** Keep the plain array and recompute identity later from window order; rejected because order is not a reliable display key for hot-plug. Move the active-overlay record into `AppCoordinator`; rejected because the plan explicitly keeps display ownership inside `BreakOverlayManager`.

## 2026-05-22 / Overlay Display Resync

**Date:** 2026-05-22

**Area:** Overlay display resync

**Context:** Active-break display hot-plug support needed to add, remove, and resize overlay windows without restarting the break, recapturing the previous app, or tearing down observer state.

**Decision:** Give each `DisplayDescriptor` a stable display identifier, then make `BreakOverlayManager.handleScreenChange()` reconcile active overlays by that identifier: preserve unchanged windows, create new windows for added displays, close removed displays, and replace only the windows whose display frame changed.

**Rationale:** Frame-only comparison cannot distinguish a resized display from one display disappearing while another appears. A stable display id keeps the hot-plug logic incremental, preserves the shared `BreakOverlayViewModel`, and avoids pushing screen-change ownership into `AppCoordinator`.

**Consequences:** Active-break hot-plugging now keeps the same countdown and `Skip` action across all current displays, ignores transient empty screen snapshots instead of silently ending the break, and only reactivates Mahu when the overlay set actually changes. `BreakOverlayManager.swift` is now above the local readability threshold, so the next hot-plug/focus task should prefer extracting focused helpers or a sidecar type instead of growing the file further.

**Alternatives Considered:** Rebuild all overlay windows on every screen notification; rejected because it would cause avoidable churn and extra reactivation even when nothing changed. Keep frame-only display identity; rejected because resize detection would collapse into remove/add semantics and could not preserve unchanged windows reliably.

## 2026-05-22 / Overlay Hot-Plug Documentation

**Date:** 2026-05-22

**Area:** Overlay hot-plug documentation

**Context:** The hot-plug implementation and tests are in place, but README, AGENTS, and the active task plan still needed to state the shipped runtime contract and preserve the out-of-scope boundary around settings reload.

**Decision:** Update project docs to describe active-break display add/remove/frame-change resync as normal overlay behavior, expand manual checks around monitor hot-plugging and display scaling, and explicitly keep live config reload out of scope.

**Rationale:** Future agents and humans should not infer that overlay windows only enumerate displays once per break, and they should not broaden the feature into runtime config watching while touching the same area.

**Consequences:** Documentation now matches the implemented overlay lifecycle and gives deterministic manual verification targets, but hardware-dependent hot-plug and Spaces behavior still remain manual-only proof.

**Alternatives Considered:** Leave docs unchanged until manual hardware verification is complete; rejected because that would preserve stale behavior descriptions after the feature shipped.

## 2026-05-22 / Status Item Icon Provider Seam

**Date:** 2026-05-22

**Area:** Status item icon provider seam

**Context:** The tray-icon plan needs focused tests around status-item image selection before replacing the current SF Symbol with bundled artwork.

**Decision:** Keep status-item image setup inside `StatusItemController`, but add a minimal injected `statusIconProvider: () -> NSImage?` that defaults to the production icon provider.

**Rationale:** This is the smallest seam that lets XCTest assert the exact installed `NSImage` instance without moving menu-bar responsibilities into `AppCoordinator` or introducing broader abstractions before the tray-asset work exists.

**Consequences:** Later tasks can test production asset selection and fallback behavior through the same controller entrypoint while preserving the existing icon-only menu contract.

**Alternatives Considered:** Move icon loading into `AppCoordinator`; rejected because it would blur AppKit ownership boundaries. Introduce a protocol-backed icon service; rejected because Task 1 only needs a single-function seam.

## 2026-05-22 / Tray Icon Asset Packaging

**Date:** 2026-05-22

**Area:** Tray icon asset packaging

**Context:** Task 2 needs a real tray-icon asset and automated proof that production code can load it from the hosted app bundle before the default status item icon switches away from the SF Symbol.

**Decision:** Add `Mahu/Assets.xcassets/TrayIconTemplate.imageset/` with 1x and 2x PNGs generated from the source-controlled root `icon.png`, and expose a small `StatusItemController.makeTrayTemplateStatusIcon(bundle:)` helper that copies the asset-backed `NSImage` and marks it as a template image.

**Rationale:** Keeping the tray artwork in the existing asset catalog matches the app-icon workflow and lets Xcode compile it into the app bundle automatically. Making template behavior explicit in code preserves tintability even if asset metadata or naming conventions change later.

**Consequences:** Tests can now verify hosted-bundle asset loading without yet changing the production default icon selection order. The helper is intentionally narrow so Task 3 can add fallback/resizing logic without moving status-item ownership out of `StatusItemController`.

**Alternatives Considered:** Reuse the full-color app icon directly in the menu bar; rejected because the plan already calls out readability and contrast issues at 16-18 pt. Keep the asset outside `Assets.xcassets`; rejected because the app already uses an asset catalog for icon-derived artwork and bundle lookup should stay conventional.

## 2026-05-22 / Tray Status Icon Contract

**Date:** 2026-05-22

**Area:** Tray status icon contract

**Context:** The tray-icon implementation is complete, and the remaining work is to document the exact shipped icon-selection behavior in the human-facing docs and durable decision log.

**Decision:** Treat the status-item icon contract as `TrayIconTemplate` first and a copied/resized compiled app icon second, with both paths returning an explicit 18x18 template image owned by `StatusItemController`.

**Rationale:** The tray asset keeps the menu bar readable across light, dark, and highlighted states because it is derived from the source artwork but simplified for template rendering. The compiled app icon fallback is less ideal visually, yet it is the smallest resilient fallback that prevents Mahu from launching with a blank status item if asset lookup fails.

**Consequences:** README and future reviews should describe the tray icon as bundled artwork rather than an SF Symbol, while still calling out that the app icon path is only a runtime resilience fallback. The status-item layer remains the single owner of image loading, copying, resizing, and template enforcement.

**Alternatives Considered:** Switch back to the old SF Symbol when asset loading fails; rejected because it would reintroduce unrelated artwork and hide tray-asset packaging regressions. Use the compiled app icon as the primary menu-bar image; rejected because the plan already identified readability and contrast issues at menu-bar size.

## 2026-05-22 / Config File Load Hardening

**Date:** 2026-05-22

**Area:** Config file load hardening

**Context:** Review found that `ConfigStore.load()` read the user-edited `~/Library/Application Support/Mahu/config.json` with `Data(contentsOf:)` on the launch path, which allowed a very large local file to inflate memory usage before any validation happened.

**Decision:** Read `config.json` through `FileHandle` in bounded chunks, cap accepted file size at 64 KiB, and fall back to default config when the file exceeds that limit.

**Rationale:** Mahu only expects two numeric fields, so a small size cap is plenty for legitimate config while preventing a trivial oversized-file denial of service from stalling or bloating app startup.

**Consequences:** Launch remains synchronous and simple, but oversized config files now log a warning and cleanly fall back to defaults instead of reading the whole file into memory first.

**Alternatives Considered:** Keep `Data(contentsOf:)` and trust the local file size; rejected because the config path is user-editable. Use filesystem metadata to preflight the size; rejected because chunked reads solve the same problem without broadening the required-reason API surface.

## 2026-05-22 / Privacy Manifest Coverage

**Date:** 2026-05-22

**Area:** Privacy manifest coverage

**Context:** Mahu measures elapsed awake time with `ProcessInfo.processInfo.systemUptime` to keep timer drift low, and Apple treats system boot time access as a required-reason API category for shipping binaries.

**Decision:** Add `Mahu/PrivacyInfo.xcprivacy` to the app target resources with `NSPrivacyAccessedAPICategorySystemBootTime` declared for reason `35F9.1`.

**Rationale:** Mahu uses system uptime only to measure elapsed time between in-app events and drive timers, which matches Apple's approved reason for the system boot time category.

**Consequences:** The app target now carries an explicit privacy manifest for App Store compliance without changing timer behavior or introducing a weaker time source.

**Alternatives Considered:** Replace `systemUptime` with a different clock; rejected because the current awake-time semantics are already intentional and well-tested. Leave the manifest out until release packaging; rejected because the compliance requirement is tied to the shipped binary, not only to later release docs.

## 2026-05-22 / Structured Overlay UI Assertions

**Date:** 2026-05-22

**Area:** Structured overlay UI assertions

**Context:** Review found several `BreakOverlayViewTests` cases proving SwiftUI structure through `String(describing:)`, which could stay green even if the break overlay body lost required foreground content or stable identifiers.

**Decision:** Add stable accessibility identifiers to the overlay title, countdown, and skip button, and assert those values by recursively inspecting the structured SwiftUI view tree that drives the overlay foreground in tests.

**Rationale:** The overlay already exposes a deterministic SwiftUI view tree, so recursive view inspection is a stronger lightweight proof than debug-string matching and does not require a third-party inspection framework.

**Consequences:** Overlay UI tests now fail when the foreground view tree drops required text or accessibility identifiers, while still avoiding a new third-party SwiftUI inspection dependency.

**Alternatives Considered:** Keep the `String(describing:)` checks; rejected because they are too easy to satisfy without preserving the intended body structure. Add a third-party inspection framework; rejected because the body tree already carries the required data and the dependency surface would grow for one narrow test need.

## 2026-05-22 / Overlay Hot-Plug Acceptance Verification

**Date:** 2026-05-22

**Area:** Overlay hot-plug acceptance verification

**Context:** The final plan task needed evidence for display add/remove/resize behavior, shared countdown state, and surrounding app invariants, but this environment cannot physically attach monitors or exercise fullscreen Spaces.

**Decision:** Treat the acceptance task as complete when targeted XCTest coverage for display reconciliation and focus/restore semantics is green and the documented repo-level commands `xcodebuild test`, `xcodebuild build`, and `make build` all succeed, while keeping real monitor hot-plugging, scaling, and fullscreen Space checks explicitly manual-only.

**Rationale:** The important invariants are already proven deterministically in-repo, and forcing hardware-only checks inside this execution loop would either block forever or encourage inaccurate checkbox updates.

**Consequences:** The active plan can finish truthfully without pretending physical-display proof happened here. Humans still need to run the manual checks before claiming hardware coverage.

**Alternatives Considered:** Leave Task 6 open until hardware verification happens; rejected because the task runner explicitly forbids indefinite looping on non-automatable checks. Mark the task complete with no note about manual gaps; rejected because that would overstate the evidence.

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

## 2026-05-21 / Overlay Focus Reassertion

**Date:** 2026-05-21

**Area:** Overlay focus reassertion

**Context:** Task 2 of the overlay-focus-hardening plan requires best-effort focus recovery after `Cmd+Tab` or other app activation changes while the break overlay is already visible.

**Decision:** On focus-loss notifications, `BreakOverlayManager` should call `show()` again on the existing overlay windows and run the existing app activator, without rebuilding windows or recapturing the previous frontmost application.

**Rationale:** Reusing the existing windows and shared view model keeps the change local to the overlay owner, preserves countdown/Skip state, and avoids breaking the original restore target captured when the break started.

**Consequences:** Mahu can only reassert focus after the system changes active app; it still does not block global shortcuts directly and real fullscreen/Spaces behavior remains a manual validation concern.

**Alternatives Considered:** Recreate overlay windows on each focus-loss event or add stronger input-capture APIs; rejected because the first adds churn and restore risk, while the second violates current public-API/App Store constraints.

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

## 2026-05-21 / Local Build Artifact

**Date:** 2026-05-21

**Area:** Local build artifact

**Context:** The default Xcode `DerivedData` output path is inconvenient when the user wants the finished app bundle in the repository workspace.

**Decision:** Add a `Makefile` target `make build` that runs `xcodebuild` with `-derivedDataPath ./build/DerivedData` and copies the resulting bundle to `build/Mahu.app`; ignore `build/` in git.

**Rationale:** This gives a stable local artifact path without changing the Xcode project build directories or committing generated files.

**Consequences:** `build/Mahu.app` is a local debug artifact for testing; release distribution still needs a separate signing/notarization workflow.

**Alternatives Considered:** Override project build directories directly in `.xcodeproj`; rejected because it makes the Xcode project less standard and can complicate tests, previews, configurations, and future signing.

## 2026-05-21 / Overlay Focus Hardening Plan

**Date:** 2026-05-21

**Area:** Overlay focus hardening plan

**Context:** During an active break overlay, the user can still switch applications with `Cmd+Tab`; because the overlay covers the screen, this creates a risk of typing or triggering actions in another app without seeing the result.

**Decision:** Create `docs/plans/2026-05-21-overlay-focus-hardening.md` to implement best-effort focus retention in `BreakOverlayManager` through public AppKit/NSWorkspace notifications, re-show existing overlay windows, and reactivate Mahu while the break is active.

**Rationale:** Public API bounce-back reduces accidental hidden-app input while preserving the existing no-global-input-capture and App Store-aware constraints.

**Consequences:** The feature should not promise absolute `Cmd+Tab` blocking; manual verification must confirm that focus returns quickly enough for the intended friendly break-reminder behavior.

**Alternatives Considered:** Use `CGEventTap` or Accessibility-based keyboard capture; rejected for this plan because it is invasive, permission-heavy, and conflicts with current product constraints.

## 2026-05-21 / Overlay Focus Observation Seam

**Date:** 2026-05-21

**Area:** Overlay focus observation seam

**Context:** Task 1 of the overlay hardening plan needs deterministic unit tests for focus-loss handling before the real bounce-back behavior is added, while production code must stay on public AppKit/Foundation APIs.

**Decision:** Add a small focus-observation seam inside `BreakOverlayManager` that injects a registrar returning an idempotent cancellation token. The live registrar listens to `NSApplication.didResignActiveNotification` and `NSWorkspace.didActivateApplicationNotification`, while tests provide a fake registrar that can trigger the stored handler manually.

**Rationale:** This keeps notification side effects at the overlay edge, allows deterministic tests without real workspace focus changes, and gives later tasks a safe teardown path without introducing new project files or private APIs.

**Consequences:** Future focus-retention logic can reuse the same seam for re-show/reactivate behavior and for teardown/leak tests; public APIs still only support best-effort focus recovery, not hard shortcut blocking.

**Alternatives Considered:** Observe notifications directly inside `showBreak` without injection or introduce a separate file/protocol hierarchy; rejected because the first would be hard to test deterministically and the second adds unnecessary project churn for a small seam.

## 2026-05-21 / Overlay Focus Teardown

**Date:** 2026-05-21

**Area:** Overlay focus teardown

**Context:** Task 3 of the overlay hardening plan requires safe observer teardown on normal hide, `Skip`, and repeated `showBreak`, plus deterministic tests that prove canceled focus callbacks do not bounce the overlay back after the break has ended.

**Decision:** Route all focus-observer lifecycle changes through a single `replaceFocusObservation` helper in `BreakOverlayManager`, and move the fake focus/window test doubles into shared test support so they can model idempotent cancellation and late-event suppression accurately.

**Rationale:** A centralized replacement path is the smallest reliable guard against duplicate observers and late callbacks, while shared test doubles keep the tests deterministic without adding more project structure churn.

**Consequences:** Future overlay tasks can reuse the same cancellation semantics in tests, and teardown behavior stays local to `BreakOverlayManager`; this still remains best-effort focus retention and cannot prevent the system switch itself.

**Alternatives Considered:** Rely on each call site to cancel the observer manually or add more production state flags for canceled focus events; rejected because the first is easier to regress and the second adds complexity without improving observable behavior.

## 2026-05-21 / Overlay Focus Retention Documentation

**Date:** 2026-05-21

**Area:** Documentation

**Context:** Task 5 closes the overlay-focus-hardening plan after implementation and validation were already complete, but the human-facing and agent-facing docs still described only the original overlay activation behavior.

**Decision:** Document the shipped focus-retention behavior as best-effort bounce-back via public AppKit/NSWorkspace notifications, and keep `Cmd+Tab`, fullscreen Space, and external-display validation explicitly manual.

**Rationale:** The feature meaningfully reduces hidden-app input risk, but overstating it as hard shortcut blocking would misrepresent both the implementation and the App Store/public-API constraints.

**Consequences:** Future agents should preserve the public-API-only approach unless product requirements change, and manual QA remains the source of truth for real-world focus behavior across Spaces and displays.

**Alternatives Considered:** Leave docs unchanged or describe the behavior as full shortcut prevention; rejected because the first hides shipped behavior and the second is technically false.

## 2026-05-21 / Live Focus-Loss Handling

**Date:** 2026-05-21

**Area:** Live focus-loss handling

**Context:** Review of the overlay hardening branch found that the live observer listened to both `NSApplication.didResignActiveNotification` and `NSWorkspace.didActivateApplicationNotification` without coalescing them, which can re-show windows and reactivate Mahu twice for one real app switch. The same review also found that the observer seam used a protocol token even though the lifetime is just one idempotent cancel action.

**Decision:** Keep both public notifications for coverage, but funnel them through a MainActor coalescer so one real focus switch produces one bounce-back callback. Replace the protocol token with an idempotent cancellation closure and split overlay tests into dedicated files for manager lifecycle, focus retention, and view behavior.

**Rationale:** Coalescing removes avoidable flicker and extra activation churn, while the simpler cancel seam keeps the hot path easier to reason about and reduces support-code weight in tests.

**Consequences:** Live focus tests now inject notification centers and synthetic process identifiers directly, and overlay-related test files stay below the project refactor threshold instead of growing one monolith.

**Alternatives Considered:** Rely on a single notification source or keep the protocol/token hierarchy; rejected because a single source risks missing some focus-loss paths and the extra token abstraction adds complexity without giving more safety.

## 2026-05-21 / Overlay Background Image Plan

**Date:** 2026-05-21

**Area:** Overlay background image plan

**Context:** The user added `background.png` at the repository root and wants it moved to an appropriate app location and used as the break overlay background.

**Decision:** Create `docs/plans/2026-05-21-overlay-background.md` to move the image into `Mahu/Resources/background.png`, bundle it through the Xcode app target, and render it in `BreakOverlayView` behind a dark readability treatment.

**Rationale:** The image must be part of the packaged app, not loaded from a development path, and the existing dark/minimal overlay invariant still requires readable text/countdown/Skip controls.

**Consequences:** The implementation should add a resource packaging test and run `make build` so `build/Mahu.app` is proven to contain the image.

**Alternatives Considered:** Create an asset catalog immediately or load the root file by path; rejected because an asset catalog is unnecessary for one PNG today, and path loading would break packaged app behavior.

## 2026-05-21 / Overlay Background Resource Wiring

**Date:** 2026-05-21

**Area:** Overlay resources

**Context:** Task 1 of the overlay-background plan needs `background.png` moved out of the repository root, bundled by the app target, and proven present in the hosted app bundle during tests.

**Decision:** Store the image at `Mahu/Resources/background.png`, add an explicit Xcode resources build phase for the app target, and verify bundle packaging with a hosted-unit-test lookup through `Bundle.main`.

**Rationale:** This is the smallest packaging change that works for the checked-in hand-authored Xcode project and catches regressions where the file exists in source control but is omitted from the built `.app`.

**Consequences:** Future visual-resource additions can follow the same raw-resource pattern until the project has enough assets to justify an asset catalog, and tests now guard the packaged-app path rather than only source-tree presence.

**Alternatives Considered:** Check only that the source file exists or migrate immediately to `Assets.xcassets`; rejected because the former misses app-bundle packaging regressions and the latter adds unnecessary structure for a single PNG.

## 2026-05-21 / Overlay Background Rendering

**Date:** 2026-05-21

**Area:** Overlay background rendering

**Context:** Task 2 of the overlay-background plan required switching the break overlay from a flat black fill to the bundled image without changing the title, countdown, or `Skip` interaction.

**Decision:** Render `Image("background")` as a fullscreen `resizable` + `scaledToFill` layer and place a semi-transparent black treatment above it before the existing foreground controls.

**Rationale:** This is the smallest implementation that satisfies the visual requirement while preserving white-text readability across different image crops and brightness levels.

**Consequences:** The image may crop on unusual aspect ratios, so manual visual checks still matter, but the foreground contrast remains stable without changing timer or AppKit overlay logic.

**Alternatives Considered:** Keep the flat black background or add dynamic blur/image processing; rejected because the first misses the feature goal and the second adds unnecessary rendering complexity for the MVP.

## 2026-05-21 / Overlay Background Documentation

**Date:** 2026-05-21

**Area:** Overlay background documentation

**Context:** The background image feature is implemented and packaged, but repository docs still need to describe it consistently for humans and future agents.

**Decision:** Update `README.md`, `AGENTS.md`, and the execution plan to state that the break overlay uses a bundled background image with a dark readability layer, and keep manual visual verification separate from automated proof.

**Rationale:** This keeps product docs aligned with the shipped `.app`, preserves the readability constraint as an invariant, and avoids overstating headless automation coverage.

**Consequences:** Future visual changes to the overlay should update documentation in the same patch and preserve the bundled-resource plus readability-treatment behavior unless product requirements change.

**Alternatives Considered:** Mention only the image or only the manual checks; rejected because either omission would lose an important product constraint or blur verification limits.

## 2026-05-22 / Overlay Resource Verification

**Date:** 2026-05-22

**Area:** Overlay resource verification

**Context:** Review of the overlay-background implementation found that the hosted smoke test only proved `Bundle.main` could return a URL for `background.png`, while `make build` still relied on an external manual shell check to prove the copied `build/Mahu.app` actually contained the resource.

**Decision:** Keep the existing hosted test target, but strengthen the resource proof by decoding `background.png` as an `NSImage` during XCTest and by making `make build` fail if either the DerivedData app bundle or the copied `build/Mahu.app` is missing the resource.

**Rationale:** This closes the weak-proof gap without reopening the broader hosted-vs-unhosted test-target decision, and it makes the documented local build command self-validating for the packaged overlay asset.

**Consequences:** Future image/resource regressions now fail deterministically during test or local build validation, while the AppKit-heavy test target can stay in its current configuration until there is a dedicated reason to revisit it.

**Alternatives Considered:** Convert the whole test target back to unhosted logic tests or leave the URL-only smoke test in place; rejected because the first is a wider AppKit-test configuration change and the second leaves corrupted-image or copied-bundle regressions weakly covered.

## 2026-05-22 / Completed Plan Archival

**Date:** 2026-05-22

**Area:** Documentation

**Context:** Review also found that the finished overlay-background plan still lived in `docs/plans/` without an explicit completion status, README still pointed to the pre-move focus-hardening plan path, and README did not repeat the verified Xcode prerequisite already captured in agent docs.

**Decision:** Move the completed overlay-background plan into `docs/plans/completed/`, add an explicit status section there, and update README plan pointers plus the full-Xcode prerequisite for verification commands.

**Rationale:** Completed plans should be archived out of the active queue, and README must remain the accurate human-facing source for repo structure and build prerequisites.

**Consequences:** Future agents and humans can distinguish active versus completed plans more reliably, and first-run build failures caused by `CommandLineTools` are documented in the primary project overview instead of only in agent instructions.

**Alternatives Considered:** Leave the completed plan in place or rely on `AGENTS.md` alone for the Xcode prerequisite; rejected because the first keeps the plan queue misleading and the second hides a human-facing build caveat in agent-only guidance.

## 2026-05-22 / Overlay Background Rendering Fix Plan

**Date:** 2026-05-22

**Area:** Overlay background rendering fix plan

**Context:** Runtime testing showed `background.png` is present in `build/Mahu.app/Contents/Resources/` and can be decoded from the app bundle, but the live break overlay still does not display the image. The current view uses `Image("background")`, while the project stores the PNG as a raw bundled resource rather than in an asset catalog.

**Decision:** Create `docs/plans/2026-05-22-overlay-background-rendering-fix.md` around explicit bundle lookup and `NSImage` decoding, then render with `Image(nsImage:)` and keep a dark fallback if loading fails.

**Rationale:** The packaging path already has automated proof, so changing project resource wiring or introducing an asset catalog would add scope without addressing the likely runtime lookup ambiguity. A small explicit loader is testable and keeps the fix localized to the overlay view layer.

**Consequences:** `ralphex` should avoid touching timer, focus retention, status item, or multi-display window creation unless the explicit loader proves insufficient. Manual visual verification is still required because XCTest can prove loading and view construction, not live rendered pixels in the overlay window.

**Alternatives Considered:** Move `background.png` into an asset catalog; rejected as unnecessary scope for one image. Rework `BreakOverlayManager` window settings; rejected because the window already hosts SwiftUI over a clear non-opaque window and packaging evidence points at image lookup instead.

## 2026-05-22 / Overlay Background Runtime Loading

**Date:** 2026-05-22

**Area:** Overlay background runtime loading

**Context:** Task 1 of the rendering-fix plan required a production code change, not just plan documentation. The overlay already preserved readability and bundle packaging, but `BreakOverlayView` still relied on `Image("background")`, which can fail for a raw bundled PNG outside an asset catalog.

**Decision:** Keep the fix inside `BreakOverlayView` by introducing a small `BreakOverlayBackgroundImageLoader` with an injected `Bundle`, load `background.png` through `bundle.url(forResource:)` plus `NSImage(contentsOf:)`, and render a plain dark fallback when no image can be produced.

**Rationale:** This is the smallest production fix that directly targets the runtime lookup ambiguity, is easy to test with hosted and empty bundles, and avoids unnecessary project wiring or asset-catalog scope.

**Consequences:** The overlay keeps the same title, countdown, skip control, and readability layer, while future tests can exercise background loading without depending on live overlay windows. Manual runtime visual confirmation is still required because XCTest cannot prove actual on-screen pixels.

**Alternatives Considered:** Keep implicit SwiftUI named-image lookup; rejected because it is the likely failing runtime path. Move the PNG into an asset catalog; rejected because raw bundle packaging already works and the current fix does not need broader resource migration.

## 2026-05-22 / Overlay Background Documentation

**Date:** 2026-05-22

**Area:** Overlay background documentation

**Context:** Task 4 of the rendering-fix plan required the docs to reflect the shipped runtime loading path and to state clearly which proof remains manual-only.

**Decision:** Update `README.md` and the active execution plan to describe the overlay background as explicitly loaded from the app bundle via `NSImage(contentsOf:)`, while keeping manual live-pixel confirmation separate from automated bundle-decoding and fallback tests.

**Rationale:** This keeps the human-facing docs aligned with the implementation and avoids overstating what the headless XCTest environment can prove.

**Consequences:** Future visual or packaging work should preserve the explicit app-bundle loading path unless the team intentionally adopts a different resource strategy.

**Alternatives Considered:** Leave README wording generic or imply that the visual proof is fully automated; rejected because both options hide important implementation truth or verification limits.

## 2026-05-22 / Overlay Review Fixes

**Date:** 2026-05-22

**Area:** Overlay review fixes

**Context:** Parallel review found three concrete gaps after the runtime image-loading fix landed: `BreakOverlayView` re-decoded `background.png` on every countdown tick, `AppCoordinator` could mark a break active even when `BreakOverlayManager` had no displays to show, and the live focus-observer tests did not isolate per-signal behavior or repeated focus-loss bursts.

**Decision:** Cache the resolved `NSImage` once during `BreakOverlayView` initialization, make `showBreak` return success so the coordinator retries instead of entering an invisible break state, and move live focus-observer coverage into a dedicated test file with separate resign/workspace/repeated-burst cases.

**Rationale:** This fixes the real runtime risks without adding a broader resource layer, preserves the existing overlay UX, and keeps the focus-retention test surface readable instead of growing one near-300-line test file.

**Consequences:** Overlay countdown updates no longer repeat synchronous bundle lookup and image decode work, break presentation retries safely after transient zero-display states, and future regressions in individual focus-loss notification paths should fail deterministically in XCTest.

**Alternatives Considered:** Leave the per-tick image decode in place, silently accept zero-display breaks, or keep stacking new registrar tests into `BreakOverlayFocusRetentionTests.swift`; rejected because each option either preserves a real runtime bug or increases maintenance risk in a hot-path test area.

## 2026-05-22 / Second Review Hardening

**Date:** 2026-05-22

**Area:** Second review hardening

**Context:** The second external review pass found three robustness gaps that were still live in the shipped branch: a user-edited `config.json` could accept absurdly large finite durations that later trap on `Int(...)` conversion in the overlay countdown, `AppCoordinator` kept spending rest-phase time even when the overlay could not yet be shown, and `ConfigStore` indexed the Application Support URL array without guarding the documented empty-array case.

**Decision:** Treat supported config durations as the closed range `1...86_400` seconds, clamp overlay countdown formatting to that same maximum, retry pending break presentation without advancing the timer while the overlay is still invisible, and fall back to `~/Library/Application Support` derived from the current home directory when the system directory lookup cannot resolve.

**Rationale:** These changes fix two real runtime failure paths and one startup resilience gap with local code only: the app now rejects clearly nonsensical schedules before they can reach UI formatting, preserves the full visible break when display enumeration fails transiently, and keeps config fallback logic reachable even if the system path lookup degrades.

**Consequences:** Config values above 24 hours now deliberately fall back to defaults, invisible-break retries keep rest time frozen until Mahu can actually present the overlay, countdown rendering no longer traps on oversized values, the directory-lookup fallback is provable in tests, and the new retry regression lives in a dedicated coordinator test file instead of pushing `AppCoordinatorTests.swift` farther past the local readability limit.

**Alternatives Considered:** Clamp only in the overlay view, keep consuming rest time after a failed show, or rely on `urls(for:in:)[0]` continuing to work in every environment; rejected because each option leaves either a reachable crash, a requirement-breaking hidden break, or a startup crash before resilience code runs.

## 2026-05-22 / Review Follow-Up Config Semantics

**Date:** 2026-05-22

**Area:** Review follow-up config semantics

**Context:** The next review pass confirmed that the 24-hour upper bound introduced in the second hardening round fixed the countdown overflow by changing `config.json` semantics: any finite duration above `86_400` seconds now silently fell back to defaults even though long work intervals are valid for a manually edited config surface.

**Decision:** Remove the 24-hour cap from config validation, keep accepting any finite duration of at least one second, and move the overflow guard entirely into countdown formatting via an Int64-capped whole-seconds conversion.

**Rationale:** The runtime defect lived in `Int(...)` conversion for overlay display, not in timer math or config storage. Fixing the formatter directly preserves existing manual-config behavior, avoids silent schedule resets, and still blocks overflow traps for absurdly large finite values.

**Consequences:** Long but finite work or break durations keep loading from disk, countdown text can represent values beyond 24 hours, extreme finite values still render safely without trapping, and the logger message now reflects the actual supported config contract.

**Alternatives Considered:** Keep the 24-hour validation cap, clamp the displayed countdown to 24 hours forever, or add a new product-level max-duration rule; rejected because each option changes user-visible scheduling semantics without a stated requirement or migration path.

## 2026-05-22 / Timer Precision Bounds

**Date:** 2026-05-22

**Area:** Timer precision bounds

**Context:** The second review pass on the current `HEAD` found that removing the 24-hour validation cap fixed countdown overflow semantics but left a different hot-path gap: `ConfigStore` now accepts arbitrarily large finite `TimeInterval` values, and `BreakTimer` subtracts one-second ticks from those doubles. Above the largest integer range with one-second precision, the timer can stop changing and silently freeze a work or break interval.

**Decision:** Keep long manual schedules valid, but only up to `2^53` seconds (`9_007_199_254_740_992`), the largest `TimeInterval` range that still preserves one-second countdown progress. Reject larger finite values during config loading and keep the countdown formatter safeguards for defensive UI rendering.

**Rationale:** This is the smallest correctness fix that preserves the intent of the previous semantics change without reintroducing the arbitrary 24-hour product cap. It aligns the config contract with what the `Double`-based timer can actually count down reliably.

**Consequences:** Schedules far longer than 24 hours still load correctly, absurdly large finite durations now fall back to defaults before they can wedge the timer, and README/log messaging can describe a precision-based bound instead of a product-level one.

**Alternatives Considered:** Keep accepting any finite duration and tolerate timer freezes, revert to the 24-hour cap, or redesign the timer around a non-`Double` time model; rejected because the first leaves a real runtime bug, the second changes valid user schedules unnecessarily, and the third is much larger than this review fix.

## 2026-05-22 / Overlay Content Centering Fix Plan

**Date:** 2026-05-22

**Area:** Overlay content centering fix plan

**Context:** Manual runtime verification on the built-in MacBook display showed the overlay title, countdown, and `Skip` button shifted horizontally while a connected external monitor looked correct. The background now renders through explicit `NSImage` loading, so the remaining bug points at SwiftUI layout sizing rather than resource packaging.

**Decision:** Create `docs/plans/2026-05-22-overlay-content-centering-fix.md` scoped to explicit fullscreen geometry sizing in `BreakOverlayView`. The plan should keep the existing visual design, avoid hardcoded offsets, and avoid changing AppKit window creation unless a separate follow-up proves that is necessary.

**Rationale:** `scaledToFill()` can crop and expand image layout on non-16:9 displays; foreground content should instead center relative to the overlay window bounds. Geometry-based sizing is display-independent and preserves the external monitor behavior that already works.

**Consequences:** `ralphex` should fix the foreground centering through SwiftUI layout only, then require manual verification on the built-in MacBook display and the external monitor. If this does not solve the issue, the next plan should inspect `NSHostingView` sizing explicitly rather than adding display-specific offsets.

**Alternatives Considered:** Add a manual `.offset` for the MacBook display; rejected as brittle and likely to regress other displays. Start with AppKit window changes; rejected because the existing multi-display window creation is working and the symptom aligns with SwiftUI image/layout sizing.

## 2026-05-22 / Overlay Content Centering Implementation

**Date:** 2026-05-22

**Area:** Overlay content centering implementation

**Context:** Task 1 needed a concrete SwiftUI-only fix for the MacBook centering bug without touching `BreakOverlayManager` or introducing display-specific tweaks. After wrapping the overlay in `GeometryReader`, the previous body-introspection tests no longer had stable access to rendered SwiftUI text literals in XCTest.

**Decision:** Make `BreakOverlayView` explicitly size the background image, fallback color, readability layer, root `ZStack`, and foreground `VStack` to `geometry.size`, with clipping applied to the `scaledToFill()` background. Keep automated proof at the layout-contract level by asserting the view builds through `GeometryReader`, while foreground strings and skip behavior remain covered through the existing view-model and loader tests.

**Rationale:** The bug is caused by image-crop-driven layout expansion, so tying every visual layer to the actual overlay window bounds is the smallest robust fix. XCTest-level reflection of SwiftUI internals became brittle once `GeometryReader` owned the body shape, so stable tests should verify the geometry-sized contract and preserve existing functional coverage rather than overfitting to private rendering details.

**Consequences:** Foreground centering is decoupled from the cropped image size, the external-display path stays untouched, and the test suite remains deterministic in headless macOS runs. Final visual centering on real displays still requires the manual verification already called out in the plan.

**Alternatives Considered:** Use hardcoded offsets, move immediately into AppKit/`NSHostingView` frame changes, or add fragile host-view text scraping tests; rejected because they are respectively display-specific, outside this task's scope, or unstable against SwiftUI implementation details.

## 2026-05-22 / Break Timing Precision Follow-Up

**Date:** 2026-05-22

**Area:** Break timing precision follow-up

**Context:** Review found two linked gaps in the hot path: supported durations near the `Double` precision ceiling could stall on subsecond ticks, and a successful `showBreak()` still let synchronous AppKit work steal part of the newly started rest interval before the next baseline reset.

**Decision:** Accumulate elapsed uptime across ticks inside `AppCoordinator`, stop timer consumption at phase boundaries, consume exact subsecond deltas only while the current phase remains below the `Double` subsecond-precision threshold, and reset both the pending elapsed time and uptime baseline immediately after a successful overlay show.

**Rationale:** This keeps the current large-duration config contract, preserves exact elapsed behavior for normal schedules, and prevents the coordinator from burning hidden break time during synchronous overlay setup on the tick that first presents the break.

**Consequences:** Supported long durations no longer freeze on `<1s` follow-up ticks, delayed work ticks still stop cleanly at the work-to-break boundary, and break time starts from the post-show baseline rather than the pre-show tick timestamp. Manual visibility on real displays and Spaces is still best-effort because public AppKit APIs do not provide a stronger acknowledgement contract here.

**Alternatives Considered:** Reintroduce a lower max-duration cap, quantize all timer progression to whole seconds, or leave the current contract in place and accept precision loss near the ceiling; rejected because those options either change user-visible scheduling semantics too aggressively or keep a confirmed correctness gap.

## 2026-05-22 / Config Diagnostics Privacy

**Date:** 2026-05-22

**Area:** Config diagnostics privacy

**Context:** Review found that malformed `config.json` files silently fell back to defaults even though manual file editing is the only MVP settings path, and the fallback/error logs exposed absolute user paths with `privacy: .public`.

**Decision:** Log decoding failures as warnings and mark config-path and Application Support path values as private in `OSLog` output.

**Rationale:** Users need a concrete operational signal when Mahu ignores a malformed config, but exported logs should not disclose usernames or home-directory structure unnecessarily.

**Consequences:** Config parse failures are now diagnosable without a UI, and log exports no longer reveal absolute user paths by default.

**Alternatives Considered:** Keep silent decode fallback or continue logging full paths publicly; rejected because both options either hide a real operator mistake or leak avoidable local-environment details.

## 2026-05-22 / Hosted Test Startup Control

**Date:** 2026-05-22

**Area:** Hosted test startup control

**Context:** Hosted XCTest still needs the production `AppDelegate` path to stay inert, but relying only on runner-owned environment markers is brittle across Xcode and harness changes.

**Decision:** Add `MAHU_DISABLE_APP_COORDINATOR_STARTUP=1` to the shared test scheme and let `AppRuntime` check that project-owned switch before falling back to XCTest marker detection.

**Rationale:** A project-owned startup contract is easier to reason about, keeps the hosted app inert under tests, and still preserves the old fallback for nonstandard runners that only expose XCTest markers.

**Consequences:** Launch-path tests can now exercise both branches deterministically, and future harness changes can keep using the explicit environment switch instead of depending on undocumented runner details alone.

**Alternatives Considered:** Depend only on XCTest markers or move all launch control behind a larger dependency-injection layer; rejected because the first is too brittle and the second is unnecessary scope for the current app size.

## 2026-05-22 / Overlay Contract Test Seams

**Date:** 2026-05-22

**Area:** Overlay contract test seams

**Context:** Review correctly called out that the centering-fix tests were too weak: they verified `GeometryReader` existed, but not that the real foreground labels/buttons and live window configuration still matched the product contract.

**Decision:** Keep the production view/window code small, but expose internal `BreakOverlayView` foreground/background helpers and the live overlay window instance to `@testable` XCTest so the suite can assert real label/button/background/window contracts without adding a third-party SwiftUI inspection dependency.

**Rationale:** This strengthens the coverage exactly where the review found blind spots while keeping the dependency graph small and the production structure aligned with the existing SwiftUI/AppKit split.

**Consequences:** Overlay tests now verify the shipped `Время отвлечься`/countdown/`Skip` content, fallback/background branch selection, and the critical live `NSWindow` configuration in addition to the existing focus and manager tests.

**Alternatives Considered:** Add `ViewInspector`, keep the existing fake tests, or move entirely to manual-only verification; rejected because they respectively add a new dependency, leave confirmed blind spots, or give up deterministic regression coverage.

## 2026-05-25 / Overlay Visibility Pause Accounting

**Date:** 2026-05-25

**Area:** Active-break timing integrity

**Context:** Review found that Mahu only paused rest-time consumption when a timer tick happened while `hasVisibleOverlayWindows == false`. If every display disappeared and returned entirely between two ticks, the next tick still spent the hidden interval because `lastTickUptime` had never been frozen at the visibility edges.

**Decision:** Add an internal overlay-visibility callback from `BreakOverlayManager` to `AppCoordinator`, settle any visible rest time immediately when overlays become hidden, and reset the uptime baseline again when overlays become visible so zero-display intervals never count against the break.

**Rationale:** The timer policy depends on whether the break was actually visible to the user, not on whether a scheduler callback happened to sample the hidden state. Visibility-edge accounting is the smallest fix that preserves the existing `BreakTimer` model and the overlay manager's ownership of screen-change events.

**Consequences:** Transient hot-plug or fullscreen-Space no-display windows no longer steal hidden rest time even when they start and end between timer callbacks, and a deterministic coordinator test now covers that precise edge case with a real `BreakTimer`.

**Alternatives Considered:** Keep the tick-only check, or move visibility semantics into `BreakTimer`; rejected because the former preserves the bug and the latter mixes AppKit/UI policy into the pure timer state machine.

## 2026-05-25 / Bundle-Aware Tray Icon Loading

**Date:** 2026-05-25

**Area:** Tray icon loading seam

**Context:** Review found that `StatusItemController.makeTrayTemplateStatusIcon(bundle:)` accepted a bundle parameter but ignored it, always using global `NSImage` lookup. That made the seam untestable outside `Bundle.main` and hid failures if the tray asset were ever loaded from another bundle.

**Decision:** Resolve `TrayIconTemplate` through `bundle.image(forResource:)`, keep the default call path on `.main`, and add XCTest coverage for both a custom bundle that contains `TrayIconTemplate.png` and one that does not.

**Rationale:** A seam should either be real or removed. Explicit bundle-aware loading preserves the existing API surface while making the tray asset path deterministic and testable without depending on global image caches.

**Consequences:** The tray icon loader now behaves correctly in test bundles or future extracted modules, and regressions in custom-bundle lookup are caught without changing the menu-bar runtime contract.

**Alternatives Considered:** Remove the `bundle` parameter or keep global `NSImage(named:)`; rejected because the code already exposed the bundle seam and review proved that the existing behavior was misleading rather than intentionally fixed to `Bundle.main`.

## 2026-05-22 / Break Completion Baseline Protection

**Date:** 2026-05-22

**Area:** Break completion timing

**Context:** The second review pass found that a delayed tick during an active break could finish the rest phase and immediately spend the leftover elapsed time from the next work interval before the overlay hid.

**Decision:** Stop `AppCoordinator` consumption at the `rest -> work` boundary and reset both the pending elapsed time and the uptime baseline when a visible break hides.

**Rationale:** The user-facing contract is the visible break duration, so delayed scheduler or AppKit work must not steal time from the next work interval while the overlay is still on screen.

**Consequences:** Late rest ticks no longer shorten the following work session, and the next work interval now starts from the actual overlay dismissal point instead of a stale delayed-tick timestamp.

**Alternatives Considered:** Keep consuming overdue work time or move the fix into `BreakTimer`; rejected because those options either preserve the bug or mix UI visibility policy into the pure timer state machine.

## 2026-05-22 / Overlay Display Hot-Plug Plan

**Date:** 2026-05-22

**Area:** Overlay display hot-plug plan

**Context:** The review follow-up identified that `BreakOverlayManager` reads `NSScreen.screens` only when `showBreak()` starts. If a monitor is connected, disconnected, or resized during an active break, the current overlay windows are not reconciled until a later break cycle. The user explicitly decided not to pursue live config reload because future GUI settings should own runtime configuration changes.

**Decision:** Create `docs/plans/completed/2026-05-22-overlay-display-hotplug.md` around public AppKit screen-parameter notifications, injected test seams, and incremental active-overlay resync inside `BreakOverlayManager`. The plan keeps `AppCoordinator`, timer flow, and config loading out of scope.

## 2026-05-22 / Overlay Hot-Plug Review Fixes

**Date:** 2026-05-22

**Area:** Overlay hot-plug review fixes

**Context:** Parallel review surfaced one concrete hot-plug crash risk and one teardown gap after the plan landed: `BreakOverlayManager` assumed unique display identifiers when reconciling active overlays, and it only removed observers/windows through explicit `hideBreak()` calls. The same review also confirmed that the now-completed hot-plug plan still lived in the active plans folder and README was missing the retry/no-visible-overlay runtime note.

**Decision:** Group active overlays by display id instead of building a trap-prone unique-key dictionary, prefer exact display matches before falling back to same-id overlays, use an ordinal fallback when a live screen lacks `NSScreenNumber`, tear down active overlay resources during manager deinit without restoring the previous app, extract overlay support/window types into a focused sidecar file, and archive the hot-plug plan under `docs/plans/completed/` while updating README behavior/structure notes.

**Rationale:** Mirrored or duplicated display snapshots can legitimately collide on fallback ids, and hot-plug reconciliation should degrade to reuse/rebuild rather than crash. Observer and window cleanup should not depend on app-lifetime ownership alone, especially in a codebase that keeps adding review-driven lifecycle hardening. The file split keeps `BreakOverlayManager.swift` below its previous 366-line size before additional hot-plug edits accumulate.

**Consequences:** Active-break screen-change pings now tolerate identifier collisions, manager teardown no longer leaks observation callbacks or stray windows, regression coverage explicitly protects the no-op and collision paths, and the finished hot-plug plan no longer masquerades as an active task. Manual real-display and fullscreen-Space validation still remains the only proof for WindowServer-specific behavior.

**Alternatives Considered:** Trust `NSScreenNumber` and keep `Dictionary(uniqueKeysWithValues:)`; rejected because the fallback path was still a real crash vector. Leave cleanup bound only to `hideBreak()`; rejected because future ownership changes would silently reintroduce leaks. Keep the finished plan in `docs/plans/`; rejected because it leaves stale queue state for future agents.

**Rationale:** Display hot-plugging is a runtime overlay-window concern, not a timer or config concern. Incremental resync can preserve the active break, shared view model, previous-frontmost app restore, and focus retention while adding/removing/replacing only the affected windows.

**Consequences:** Implementation should add abstraction-level tests for display add/remove/frame-change behavior and still require manual external-display/fullscreen-Space validation. Because `BreakOverlayManager.swift` is near the 300-line refactor signal, new notification/coalescing support should be kept in focused source files or implemented with minimal manager growth.

**Alternatives Considered:** Rebuild all overlay windows on every screen change; rejected because it causes unnecessary churn and increases focus/restore risk. Drive screen changes from `AppCoordinator`; rejected because it couples timer orchestration to AppKit window management. Implement config live reload in the same work; rejected because GUI configuration is planned later and live file watching has separate semantics.

## 2026-05-28 / Break Completion Sound Review Fixes

**Date:** 2026-05-28

**Area:** Break completion sound review fixes

**Context:** External review surfaced one real edge-case runtime bug plus several false-green test and documentation gaps. If an active break reached zero during the visible slice of time that gets settled exactly when overlay visibility flips to hidden, `AppCoordinator` advanced `rest -> work` silently because the visibility-edge accounting path never allowed the completion sound. The same review also exposed weaker-than-needed coverage around `AppDelegate` startup retention, `BreakOverlayManager` visibility callbacks, cancellation of nested notification tasks, `BreakCompletionSoundPlayer` metadata/decode branches, hosted privacy-manifest packaging, and stale `AGENTS.md` menu/deferred-feature guidance.

**Decision:** Preserve the existing hidden-break countdown contract, but treat elapsed rest time settled on the overlay-hide boundary as still visible for sound semantics so a break that naturally ends there plays `sound.wav` once. In the same pass, harden the regression surface with focused XCTest coverage for coordinator retention, visibility-callback sequencing, cancellation no-op guarantees, sound-player metadata/decode branches, and hosted privacy-manifest membership; sync `AGENTS.md` and `README.md` with the shipped pause/resume, completion-sound, and test-startup contracts.

**Rationale:** The sound should track whether the user actually saw the last slice of the break, not which callback happened to account for that time. Settling the final visible second at the visibility edge fixes the real user-facing gap without changing the separate zero-display rule that hidden intervals do not consume break time. The extra tests and doc sync are still the smallest way to prevent future false-green review passes and agent drift around the shipped behavior.

**Consequences:** If every overlay disappears exactly as the visible break reaches zero, Mahu still tears down the break normally and plays the completion sound once; intervals spent fully hidden remain silent and do not consume rest time. Future refactors that drop coordinator retention, stop forwarding overlay visibility changes, loosen observer cancellation, remove the privacy manifest from resources, or bypass the hosted-test startup guard should fail quickly in repository-owned checks. Agent guidance now matches the shipped menu, pause, sound, and test-runner behavior.

**Alternatives Considered:** Keep the old behavior because hidden-overlay timing paths were meant to stay silent; rejected because the elapsed slice in this edge case was still visible to the user right until the hide transition and therefore belongs to the audible natural-completion contract. Leave the suite as-is because current `xcodebuild` is green; rejected because the gaps are specifically about future regressions that present tests would miss. Use the review to simplify unrelated abstractions; rejected because the reported indirection was mostly intentional test seams and changing them would create risk outside the confirmed defects.

## 2026-05-22 / Overlay Screen Observation Seam

**Date:** 2026-05-22

**Area:** Overlay display hot-plug implementation

**Context:** The first hot-plug task needs public AppKit screen-change observation, MainActor coalescing, and test seams without pushing more notification code into `BreakOverlayManager.swift`, which is already near the 300-line refactor signal.

**Decision:** Add a dedicated `BreakScreenObservation.swift` source file that owns the screen-observation typealiases, live NotificationCenter-based registrar, and MainActor coalescer, then inject that registrar into `BreakOverlayManager` with fake/live test coverage.

**Rationale:** This keeps `BreakOverlayManager` focused on break lifecycle while isolating notification mechanics in a reusable seam that can be tested deterministically without real display hot-plug events.

**Consequences:** Future tasks can implement window resync in the manager without reworking observer ownership, and repeated screen-parameter bursts are collapsed before they reach overlay reconciliation.

**Alternatives Considered:** Add screen-notification logic directly to `BreakOverlayManager.swift`; rejected because it would further grow an already-large file and mix lifecycle with observer plumbing. Delay the seam until full resync work; rejected because the plan requires testable observer injection first.

## 2026-05-22 / Overlay Startup Hot-Plug Race

**Date:** 2026-05-22

**Area:** Overlay startup hot-plug race

**Context:** The hot-plug implementation created its initial overlay windows from one display snapshot and only then installed the live screen observer. A monitor attach, detach, or resize during that setup window could miss the only screen-change notification and leave Mahu out of sync until another display event happened.

**Decision:** Run one immediate reconciliation pass against the latest `screenProvider()` result after `showBreak()` installs the focus and screen observers but before the final activation returns.

**Rationale:** This closes the setup race with a local `BreakOverlayManager` change, keeps the shared countdown and `Skip` state intact, and avoids pushing display lifecycle concerns into `AppCoordinator`.

**Consequences:** Active-break hot-plugging now self-heals if the display topology changes during break startup, and a focused registrar-driven regression test protects the edge case. Real hardware is still required to prove exact WindowServer timing around cable plug/unplug events.

**Alternatives Considered:** Register the screen observer before the initial snapshot; rejected because notifications could still arrive before `viewModel` and active overlays exist, which would require a broader lifecycle rewrite. Ignore the race; rejected because it violates the active-break display resync requirement under a realistic timing edge case.

## 2026-05-22 / Review Lifecycle And Focus Docs Fixes

**Date:** 2026-05-22

**Area:** Review lifecycle and focus docs fixes

**Context:** The second review pass found that `AppCoordinator` and `BreakOverlayManager` both perform cleanup from ordinary `deinit` despite being `@MainActor` types, and README/manual-plan text still implied stronger hidden-input protection than the shipped public-API bounce-back approach can actually provide.

**Decision:** Switch both teardown paths to `isolated deinit` so timer invalidation, observer cancellation, window teardown, and previous-app restore cleanup stay on the main actor, and narrow the human-facing focus-retention documentation to best-effort `Cmd+Tab` bounce-back wording instead of promising zero leaked keystrokes.

**Rationale:** Ordinary `deinit` is not actor-isolated, so main-thread-only cleanup in a global-actor type should not rely on release happening on the right thread by accident. The focus-retention implementation intentionally avoids input capture and therefore cannot honestly guarantee that no keystroke reaches another app before Mahu reactivates.

**Consequences:** Teardown no longer depends on `MainActor.assumeIsolated` or off-main `Timer.invalidate()` luck, and future acceptance/manual checks should not pressure agents into undocumented Accessibility/event-tap behavior just to satisfy an overstated requirement.

**Alternatives Considered:** Add explicit `stop()` or `shutdown()` calls and keep ordinary `deinit`; rejected because the current architecture already relies on deallocation cleanup and `isolated deinit` is supported by the toolchain in this repo. Keep the stronger hidden-input wording; rejected because it overpromises behavior that public notifications alone cannot guarantee.

## 2026-05-22 / App Icon Asset Catalog

**Date:** 2026-05-22

**Area:** App icon asset catalog

**Context:** The user provided `icon.png` at the repository root and asked to make it the application icon. The Xcode target already declared `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`, but the project had no asset catalog.

**Decision:** Generate the standard macOS app icon sizes from `icon.png`, store them under `Mahu/Assets.xcassets/AppIcon.appiconset`, and add `Assets.xcassets` to the app target resources.

**Rationale:** App icons are compiled by Xcode from asset catalogs and tied to the target's app-icon build setting. This is the native path for bundle icons and keeps generated sizes explicit in source control.

**Consequences:** The app now builds with a packaged `AppIcon`; if the source artwork changes later, regenerate all appiconset PNG sizes together. The original image was non-square, so generation center-cropped it to a square before resizing.

**Alternatives Considered:** Use a raw PNG or hand-built `.icns`; rejected because the target already expects an asset-catalog `AppIcon` and asset catalogs are easier to validate through `xcodebuild`.

## 2026-05-26 / Reminder Menu Status-Item API

**Date:** 2026-05-26

**Area:** Reminder menu status-item API

**Context:** Task 2 needed the tray menu to switch between `Pause Reminders` and `Resume Reminders` and invoke dedicated handlers, while the implementation plan explicitly kept reminder semantics and timer resets out of the AppKit status-item layer.

**Decision:** Extend `StatusItemController` with injected `pauseRemindersHandler` and `resumeRemindersHandler` callbacks plus a `setRemindersPaused(_:)` view-state method that rebuilds the menu title, while preserving icon loading, icon-only button presentation, and the existing `Quit` action.

**Rationale:** `StatusItemController` should own menu construction and target-action wiring, but not reminder lifecycle policy. A tiny paused-state API is enough to keep AppKit behavior localized and leaves `AppCoordinator` free to implement pause/resume semantics in later tasks without leaking timer logic into the tray layer.

**Consequences:** The status item can now reflect enabled vs paused reminder state and dispatch pause/resume actions deterministically in tests. Future coordinator work can wire the callbacks and state updates without reshaping the status-item abstraction again.

**Alternatives Considered:** Move pause/resume state management into `AppCoordinator` only and have it rebuild AppKit menus directly; rejected because that would blur UI ownership boundaries and make tests depend more heavily on AppKit objects. Add a broader protocol or menu view model now; rejected because Task 2 only needs a minimal seam.

## 2026-05-28 / Reminder Pause Review Fixes

**Date:** 2026-05-28

**Area:** Reminder pause review fixes

**Context:** Review found two contract violations in the shipped pause/resume work. `Resume Reminders` reread `config.json` at runtime even though live config reload remains out of scope, and repeated pause/resume interactions during an active break could reset the uptime baseline and silently extend the break.

**Decision:** Cache the validated config loaded during `start()` and reuse that snapshot for fresh work resets on resume. Treat pause/resume interactions during `.rest` as menu-state-only changes that must not reset `lastTickUptime`, clear break progress, or recreate the timer.

**Rationale:** Pause/reminder toggles should not behave like a hidden runtime settings reload, and tray-menu interaction during a break must not mutate the existing countdown or `Skip` contract.

**Consequences:** Editing `config.json` while Mahu is running still has no effect until the next launch, and active breaks now keep the same duration even if the user toggles pause/resume or repeats those actions from the tray menu. Regression coverage now includes rest-phase toggles and the real `StatusItemController.configureReminderActions(...)` action path.

**Alternatives Considered:** Re-read config on every resume; rejected because it silently introduces runtime settings reload outside the documented scope. Reset the break baseline on any repeated pause/resume action for simplicity; rejected because it changes active-break duration based on menu interaction timing instead of timer state.

## 2026-05-28 / Review Validation Discipline

**Date:** 2026-05-28

**Area:** Review validation discipline

**Context:** A review-agent patch tried to reinterpret the zero-display break contract after a failing `xcodebuild test` run, but the failure was produced while `xcodebuild test` and `xcodebuild build` were running in parallel against shared `DerivedData`. A sequential rerun of the targeted tests passed on the pre-change behavior, and the repository's README plus earlier review decisions already state that active breaks must not consume hidden rest time while every overlay window is unavailable.

**Decision:** Keep the zero-display contract unchanged: active-break countdown consumption pauses while no overlay windows are visible, and review validation must treat parallel `xcodebuild test` plus `xcodebuild build` on shared `DerivedData` as a potentially noisy harness signal that requires sequential confirmation before changing runtime behavior.

**Rationale:** Changing countdown semantics from a noisy harness failure would create a real product regression. The documented behavior, existing manual-check guidance, and prior review fixes all align on preserving the same countdown state without spending hidden rest time during transient all-display loss.

**Consequences:** `AppCoordinator` keeps its visibility guard and only accounts elapsed rest time at the moment overlays disappear, not while the break remains fully hidden. Future review passes should rerun failing macOS tests sequentially before weakening a runtime contract around display visibility.

**Alternatives Considered:** Keep the review-agent patch that consumes hidden rest time; rejected because it contradicts the documented zero-display behavior and silently extends the feature scope. Trust the first parallel red test run without rerunning sequentially; rejected because this repository has already shown `DerivedData` interference when `test` and `build` overlap.

## 2026-05-29 / Break Overlay Skip And Startup Visibility Guards

**Date:** 2026-05-29

**Area:** Break overlay skip and startup visibility guards

**Context:** Review found two edge-case violations in the active-break overlay flow. The `BreakOverlayViewModel.skip()` path tore down visible windows before the coordinator recorded a skip, so a boundary-timed visibility callback could still finish the rest phase and play the natural-completion sound. Separately, `showBreak()` could reactivate Mahu and report success even when a second display snapshot immediately collapsed to zero visible overlays during startup resync.

**Decision:** Run the injected skip callback before any fallback local teardown in `BreakOverlayManager`, and only perform a local `hideBreak()` if that callback did not already clear the active break. After the startup resync pass, treat `hasVisibleOverlayWindows == false` as a failed presentation: tear down observers/windows without restoring the previous app, skip activation, and return `false` so `AppCoordinator` keeps retrying like the documented zero-display start path.

**Rationale:** `Skip` is a user override and must not look like natural completion. Likewise, Mahu should only steal focus when it actually has at least one visible overlay window to show.

**Consequences:** Boundary-timed skip actions stay silent, transient startup zero-display snapshots no longer return a false-positive successful break start, and new tests now cover both paths. This keeps the current hidden-break countdown contract intact; if future product work wants different skip or no-display semantics, it should change them explicitly rather than via callback ordering accidents.

**Alternatives Considered:** Add a richer visibility-change reason enum at the coordinator boundary; rejected for now because the smaller ordering/state guard solves the confirmed bug without reshaping the coordinator protocol. Keep activating Mahu even with zero surviving overlays; rejected because it violates the current break-presentation contract and steals focus without UI.

## 2026-05-29 / Break Overlay Layout Composition

**Date:** 2026-05-29

**Area:** Break overlay layout composition

**Context:** Review hardening exposed that `BreakOverlayViewTests` could only inspect the standalone `foregroundContent` helper, because the real `body` was wrapped in a `GeometryReader` closure that did not expose the rendered text tree for deterministic assertions. The view itself always wants to fill the entire fullscreen overlay window and center one foreground stack over a darkened background image.

**Decision:** Replace the `GeometryReader` body with a direct full-frame `ZStack` that uses `maxWidth: .infinity` / `maxHeight: .infinity` to fill the overlay, keeps the same dark readability layer, and centers the existing foreground stack without explicit geometry plumbing.

**Rationale:** `GeometryReader` added indirection without providing unique behavior for this fullscreen window case. The simpler layout still satisfies the visual contract while making rendered-body checks less artificial.

**Consequences:** Overlay content remains centered over a fullscreen background/readability layer, and the body tree now reflects the actual text/button content directly enough for deterministic test assertions. If future overlay work needs truly geometry-dependent placement, that should be reintroduced for a concrete visual requirement rather than kept pre-emptively.

**Alternatives Considered:** Keep `GeometryReader` and accept test-only reflection on `foregroundContent`; rejected because it let a real body-wiring regression hide behind green tests. Add a third-party SwiftUI inspection dependency; rejected because the simpler native layout change solved the immediate truthfulness problem without introducing a new package.

## 2026-05-29 / Break Overlay Observer Cancellation

**Date:** 2026-05-29

**Area:** Break overlay observer cancellation

**Context:** The live focus-loss and screen-change registrars already removed their `NotificationCenter` observers on teardown, but they coalesced deliveries through `Task { @MainActor ... }`. A notification posted just before cancellation could therefore enqueue a stale task that still fired after `hideBreak()`, `skip`, or a new break start.

**Decision:** Make both coalescers explicitly cancellation-aware by tracking a cancelled flag plus their pending delivery task, and invoke `cancel()` from the registrar teardown closure before removing observers.

**Rationale:** Observer removal alone does not invalidate already queued actor hops. The smallest robust fix is to let queued deliveries self-suppress once teardown has started.

**Consequences:** Focus and screen notifications that were queued for an old break lifecycle become harmless no-ops after cancellation, and new registrar tests now cover the queued-before-cancel case. This works for the current single-consumer overlay manager; if more consumers later share the same coalescers, the same cancellation contract should be preserved.

**Alternatives Considered:** Track and cancel every outer scheduling task handle separately; rejected because the queued work still needs an authoritative in-object cancellation gate even if task handles are cancelled. Remove coalescing entirely; rejected because the project still wants burst suppression for duplicate AppKit notifications.

## 2026-05-29 / Tray Timer Review Hardening

**Date:** 2026-05-29

**Area:** Tray timer review hardening

**Context:** External review of the optional tray-timer work found two real contract holes and several false-green test signals. `AppConfig` decoded `showStatusItemTimerState` with `decodeIfPresent(... ) ?? false`, so a hand-edited `null` value was treated like a missing key instead of falling back through the repo's existing invalid-config path. The same review also showed that `AppCoordinatorStatusItemDisplayTests.swift` and `AppCoordinatorStatusItemPauseResumeTests.swift` existed on disk but were not target members in `Mahu.xcodeproj`, and some tray-timer tests did not yet prove the production call order or exact work/rest transition sequence.

**Decision:** Treat an explicit `showStatusItemTimerState` key as required to decode as a real `Bool`; only a genuinely missing key defaults to `false`. Add the two dedicated coordinator timer-display suites to the `MahuTests` target, strengthen controller tests to cover post-install timer-mode updates and icon-only runtime state updates, and make natural-completion assertions compare exact `StatusDisplayState` sequences instead of ambiguous rendered-text containment.

**Rationale:** Manual config editing is the only settings surface in the MVP, so `null` must be rejected consistently with every other invalid type. Review-proof coverage also needs to fail loudly when the coordinator timer-display suites are missing from the target or when a test only proves that some repeated string appeared rather than the intended work/rest transition order.

**Consequences:** `showStatusItemTimerState: null` now falls back to `.default` alongside other malformed config values, the dedicated tray-timer coordinator tests run under `xcodebuild test`, and the strengthened AppKit/coordinator assertions better match the real startup call order. If future tray text differentiates work vs. rest beyond raw `MM:SS`, the exact-state assertions will keep that seam explicit instead of hiding it behind duplicate strings.

**Alternatives Considered:** Keep treating `null` as "missing" for convenience; rejected because the plan and README both define invalid values as whole-config fallback territory. Leave the missing coordinator suites off-target and rely on plan prose; rejected because that creates silent coverage gaps. Keep the weaker string-based assertions; rejected because identical `00:01` strings can mask a missing rest-phase update.

## 2026-05-29 / Break Overlay Manager Message Wiring

**Date:** 2026-05-29

**Area:** Break overlay manager message wiring

**Context:** The configurable overlay title already lives on `BreakOverlayViewModel`, but active-break window creation and display resync still instantiated the shared view model without any message input. The coordinator-facing overlay protocol and fake manager also could not record which title was shown, which would block the next task's config-to-overlay assertions.

**Decision:** Extend `BreakOverlayManaging.showBreak` and `BreakOverlayManager.showBreak` with a `messageText` parameter, build the shared `BreakOverlayViewModel` from that string, and keep screen-change reconciliation reusing that same view-model instance.

**Rationale:** `BreakOverlayManager` is the smallest seam that owns both initial window creation and active-break display reconciliation. Carrying the title here preserves the existing shared-state model and keeps config access out of SwiftUI views while making the coordinator test seam explicit.

**Consequences:** All display windows for one break continue sharing the same title, countdown, and `Skip` callback even after hot-plug/resync. Coordinator-support fakes now record message text, which enables the next task to verify config wiring without another seam refactor.

**Alternatives Considered:** Keep `showBreak` default-only until coordinator wiring; rejected because Task 3 explicitly needs manager-level message propagation and resync proof. Recompute title per window during resync; rejected because it weakens the existing shared-view-model contract and risks diverging per-display state.

## 2026-05-29 / Overlay Message Review Hardening

**Date:** 2026-05-29

**Area:** Overlay message review hardening

**Context:** Review of the configurable overlay-title work exposed two follow-up gaps. `AppConfig` normalized empty and whitespace-only message text back to `Время отвлечься`, but `BreakOverlayViewModel` still had a weaker `isEmpty` fallback, so direct non-config callers could present an effectively blank overlay title. The same review also found that README manual checks documented the default/custom title cases but not the whitespace fallback or the requirement that a custom title survive display hot-plug and resize resync.

**Decision:** Make `AppConfig.normalizedBreakOverlayMessageText(_:)` the shared normalization helper for both config decoding and `BreakOverlayViewModel` initialization, tighten overlay title presentation with centered multiline rendering plus a bounded maximum width, and strengthen the legacy-config tests so omitted `breakOverlayMessageText` must preserve the rest of the decoded config instead of silently passing on a whole-config fallback. Expand README manual checks and the plan close-out text to cover whitespace fallback and custom-title persistence during display resync, while keeping the finished plan at its current path with an explicit completed-status marker for the active review loop.

**Rationale:** One normalization rule is easier to reason about than layered fallbacks with subtly different semantics. Centered multiline text with a bounded width keeps long custom messages readable without inventing a new config-length limit, stronger legacy-config tests make the backward-compatibility claim truthful, and the missing manual-check bullets were part of the shipped feature contract, not optional commentary.

**Consequences:** Every overlay entry path now treats blank and whitespace-only titles consistently, long custom titles center more predictably when they wrap, the backward-compatible config tests now fail if omitted-message JSON falls all the way back to `.default`, and future reviewers can see the missing manual verification cases directly in README and the completed plan header. If the product later needs a hard maximum title length instead of view-level wrapping, that should be added explicitly at the config boundary.

**Alternatives Considered:** Leave normalization duplicated across `AppConfig` and the view-model; rejected because the weaker lower-layer fallback allowed divergent behavior outside the config path. Add a config-length limit for `breakOverlayMessageText`; rejected for now because the feature contract still allows any non-empty Unicode string and the immediate problem was rendering/readability, not storage size.

## 2026-05-31 / Runtime Settings Review Hardening

**Date:** 2026-05-31

**Area:** Runtime settings review hardening

**Context:** Review of the runtime-settings foundation found two correctness gaps and one false-green test seam. `RuntimeSettingsStore.update(_:)` accepted unsupported schedules that `ConfigStore.load()` would later reject, `ConfigStore.save(_:)` happily persisted finite-but-unsupported durations that the next launch would drop back to defaults, and `FakeRuntimeSettingsStore` still notified observers for identical no-op updates even though the production store did not.

**Decision:** Reject unsupported durations at both the runtime-store update boundary and the disk-save boundary, keep repeated identical runtime-setting updates as no-ops in both production and fake stores, extract runtime-settings policy/pending-action state into `RuntimeSettingsApplicationPolicy`, split dedicated runtime-store tests out of the already-oversized `ConfigStoreTests.swift`, and add regression coverage that identical runtime updates do not recreate timers or duplicate coordinator UI output.

**Rationale:** The runtime settings source of truth must not accept schedules that its own persistence layer rejects on the next launch, and review-proof tests need to mirror production idempotence closely enough to catch repeated-update regressions instead of inventing extra observer churn.

**Consequences:** Invalid runtime schedules now leave the current in-memory settings untouched, invalid finite saves return `false` without touching disk, the fake/runtime tests agree on no-op update behavior, `AppCoordinator.swift` drops back under the local readability threshold, and the runtime-store coverage no longer grows a 300+ line config test file. Future Settings UI work can still decide whether rejected updates surface user-facing errors, but it no longer has to patch over silent live-state corruption first.

**Alternatives Considered:** Leave validation only at JSON load time; rejected because that creates split-brain behavior between current runtime state and the next launch. Let the fake store keep broadcasting no-op updates for convenience; rejected because it made coordinator tests less truthful than the shipped store behavior.

## 2026-05-31 / Runtime Settings Persistence Hardening

**Date:** 2026-05-31

**Area:** Runtime settings persistence hardening

**Context:** Review reproduced that `Data.write(..., .atomic)` against `~/Library/Application Support/Mahu/config.json` replaces the symlink itself with a regular file instead of updating the symlink target, even though `ConfigStore.load()` explicitly supports regular-file symlink configs.

**Decision:** Resolve `config.json` symlinks before saving and write atomically to the resolved target path while preserving the symlink entry itself.

**Rationale:** Users who manage Mahu config through dotfiles or shared symlink targets should not have that setup silently broken by the first in-app save. Resolving the target is the smallest fix that preserves the existing load contract.

**Consequences:** Runtime saves now keep symlink-based config setups intact and update the target file the same way `load()` already reads it. If a symlink resolves to an unwritable or nonsensical target, save still fails deterministically with logging instead of mutating the config path into a different filesystem object.

**Alternatives Considered:** Reject all symlink-backed saves; rejected because `load()` already treats regular-file symlinks as supported config and review exposed real user breakage in that supported path. Keep writing to the symlink path directly; rejected because atomic rename semantics destroy the symlink contract.

## 2026-05-31 / Runtime Settings Plan Close-Out

**Date:** 2026-05-31

**Area:** Runtime settings plan close-out

**Context:** The runtime-settings foundation plan was complete, but the current external review workflow still targeted the original file path under `docs/plans/`. Archiving it immediately would make the folder layout cleaner while also breaking the next automated review pass.

**Decision:** Mark the plan as completed in place, update README and the plan note to explain that the active review loop may temporarily keep a completed plan at its original path, and archive it only after close-out review is finished.

**Rationale:** Preserving a stable review target for the next automated iteration is more important than eager physical archival, as long as the documentation stays explicit about the temporary state.

**Consequences:** Future reviewers can still open the expected plan path during this loop, while humans and agents no longer get a false signal that every file under `docs/plans/` is necessarily in progress. Once the review loop ends, the plan can still move to `docs/plans/completed/` without changing the documented rule again.

**Alternatives Considered:** Move the plan immediately; rejected because the next external review pass is likely to look up the original path. Leave README and the plan note untouched; rejected because that keeps the documented project structure false in the meantime.

## 2026-05-31 / Config Save Size-Limit Parity

**Date:** 2026-05-31

**Area:** Runtime settings persistence hardening

**Context:** A second review pass found that `ConfigStore.load()` rejects `config.json` files larger than 64 KiB, but `ConfigStore.save(_:)` did not enforce the same cap. A future runtime-settings caller could therefore save an oversized `breakOverlayMessageText`, get a `true` result, and still lose all persisted settings on the next launch when load fell back to defaults.

**Decision:** Make `ConfigStore.save(_:)` reject encoded JSON payloads larger than the existing 64 KiB load limit before touching the filesystem, and add regression coverage for oversize save attempts.

**Rationale:** The persistence API must not report success for configs that the same app will immediately treat as invalid on the next launch. Enforcing parity at the save boundary is the smallest fix that preserves the existing load contract and avoids silent persistence corruption.

**Consequences:** Oversized runtime config saves now fail deterministically with logging and a `false` return value instead of producing a self-invalidating `config.json`. Future Settings UI work can surface that failure explicitly without having to debug why a "successful" save vanished after relaunch.

**Alternatives Considered:** Remove the 64 KiB load limit; rejected because that limit already protects config parsing from unbounded file growth and was not part of this review scope. Allow oversized saves and rely on caller-side truncation; rejected because it keeps the persistence contract internally inconsistent and too easy to misuse.

## 2026-06-03 / Sleep Wake Second Review Hardening

**Date:** 2026-06-03

**Area:** Sleep/wake and status-item review hardening

**Context:** A second external review pass on the sleep/wake reconciliation branch surfaced two branch-relevant behavior gaps and one latent crash path. `StatusItemController` published an active pause/resume menu item even when its handlers had not been configured yet, which left an ordinary menu click on a `preconditionFailure` path. The same review also showed that timer-mode pause rendering incorrectly replaced an active break countdown with `Paused`, even though the shipped contract says pause/resume during an active break must change only future reminder state and menu labels. Local verification additionally found that `AppCoordinator.handleDidWake()` reset `runtimeSettingsPolicy` on every wake, so short sleep could silently discard deferred runtime-settings updates that were supposed to apply at the next break or after the current break ended.

**Decision:** Keep the reminder toggle menu item disabled until handlers are configured and rebuild the installed menu once handlers arrive; preserve active-break countdown text in timer mode even when reminders are paused, while still dimming the icon and flipping the menu label; and only reset `runtimeSettingsPolicy` on wake paths that actually perform long-sleep reconciliation instead of on every `didWake`.

**Rationale:** Disabling an unavailable action is the smallest fix that removes a latent crash without inventing a new initializer contract. Preserving the active break countdown keeps the tray UI aligned with the documented break semantics. Restricting runtime-settings-policy reset to true long-sleep reconciliation prevents short sleep from erasing already accepted next-break/post-rest schedule updates while still refreshing the uptime baseline so sleep time is not consumed.

**Consequences:** Install-before-configure call order is now safe for `StatusItemController`, active breaks keep showing live `MM:SS` countdowns in timer mode while reminders are paused, and short sleep or wake-without-long-sleep no longer cancels deferred runtime-settings application policies. Future reviewers can exercise these paths through dedicated status-item and sleep/wake runtime-settings regressions instead of relying on implicit coordinator behavior.

**Alternatives Considered:** Keep the `preconditionFailure`; rejected because a menu action should not crash the app when the safer disabled-state pattern fits naturally. Continue showing `Paused` during active breaks; rejected because it hides the very countdown the product contract says must stay visible. Reset runtime-settings policy on every wake; rejected because it treats non-destructive wake paths as if they had performed a full long-sleep reset and silently loses deferred settings changes.

## 2026-06-03 / Break Overlay Coordinator State

**Date:** 2026-06-03

**Area:** Break overlay coordinator state

**Context:** A second external review pass found that `BreakOverlayManager.showBreak(...)` can intentionally return `false` while still preserving a dormant break session during startup/display races. `AppCoordinator` tracked only a local `isShowingBreak` flag derived from that return value, so later `.work` transitions could skip `hideBreak()` even after the dormant session recreated visible windows. That left overlay teardown and focus/session cleanup out of sync with the real manager state.

**Decision:** Split the coordinator's notion of break presence into two signals: `BreakOverlayManaging.hasActiveBreakSession` for session existence and `hasVisibleOverlayWindows` for actual visible windows. `AppCoordinator` now keys rest/work teardown and hidden-break countdown behavior off the manager's explicit session state instead of the last `showBreak()` return value.

**Rationale:** This is the smallest review fix that closes the dormant-session leak without rewriting the oversized coordinator or broadening the overlay manager contract beyond one additional state signal.

**Consequences:** A startup/display race can still preserve a dormant break session, but the coordinator now tears it down correctly once the break ends or sleep/wake reconciliation resets to work. Regression coverage now proves that a dormant session which later becomes visible does not survive into the next work interval.

**Alternatives Considered:** Keep the local `isShowingBreak` boolean and force `showBreak()` never to return `false` for dormant sessions; rejected because the coordinator still needs an honest visible/non-visible result for rest countdown policy. Replace the whole coordinator/overlay handshake with a richer enum state machine; rejected for this review pass because it would expand scope deep into an already high-friction file.

## 2026-06-03 / Break Completion Overflow Handling

**Date:** 2026-06-03

**Area:** Break completion overflow handling

**Context:** A follow-up external review found that `AppCoordinator.consumeElapsedTime(...)` stopped as soon as a tick advanced `rest -> work`, then `handle(state: .work)` immediately zeroed `pendingElapsedSeconds` while hiding the overlay. If the app was stalled long enough for a single tick to include both the end of the break and part of the next work interval, Mahu silently dropped that already elapsed awake time and restarted work from a falsely full duration.

**Decision:** Preserve any remaining `pendingElapsedSeconds` after a natural `rest -> work` transition, let the normal `.work` path tear down the overlay first, then recursively consume the carried overflow against the current work timer.

**Rationale:** This is the smallest coordinator-local fix that keeps the existing break teardown, sound, and runtime-settings seams intact while restoring correct awake-time accounting after long ticks or debugger pauses.

**Consequences:** Late break-completion ticks now hide the overlay and then continue advancing the next work interval from the same accrued awake time instead of discarding it. Review coverage now proves the carried-overflow path directly, so future timer refactors can catch this under-counting regression without manual reproduction.

**Alternatives Considered:** Keep the current zeroing behavior; rejected because it undercounts work time after any large awake-time delta that crosses the end of a break. Move the overflow logic into `handle(state:)`; rejected because it would further overload the already-large coordinator state handler and blur the difference between natural break completion and other `.work` transitions such as skip or long-sleep reset.

## 2026-06-03 / Sleep/Wake Live Delivery Ordering

**Date:** 2026-06-03

**Area:** Sleep/wake timer reconciliation

**Context:** A second external review pass identified that `LiveSleepWakeObservationRegistrar` received `NSWorkspace.willSleepNotification` and `didWakeNotification`, then re-dispatched them through `Task { @MainActor ... }`. That made the critical bookkeeping asynchronous: `handleWillSleep()` could miss the pre-suspend window entirely, and `handleDidWake()` could run after the first post-wake timer tick had already consumed stale elapsed time.

**Decision:** Keep the public-notification seam, but deliver live sleep/wake callbacks synchronously onto the main actor. The registrar now invokes the handlers immediately on the current thread when already on the main thread, and otherwise blocks through `DispatchQueue.main.sync` before returning from the observer callback. The live-registrar tests now assert synchronous delivery instead of queued-task cancellation semantics.

**Rationale:** The sleep/wake feature is fundamentally ordering-sensitive. Preserving the existing seam but making delivery synchronous is the smallest fix that restores the guarantee that sleep bookkeeping happens before any subsequent timer progression or suspend boundary can overtake it.

**Consequences:** Real `willSleep`/`didWake` handling now preserves the intended causal order relative to the coordinator's timer tick path, so long-sleep detection and baseline refresh no longer depend on task scheduling luck. The tests now prove the stronger contract directly: once `NotificationCenter.post(...)` returns, the corresponding Mahu sleep/wake handler has already run.

**Alternatives Considered:** Keep the `Task { @MainActor ... }` hop and add more regression coverage; rejected because extra tests cannot remove the race itself. Register observers on `OperationQueue.main`; rejected because NotificationCenter still enqueues those callbacks asynchronously, leaving the same ordering hole between lifecycle delivery and the next timer tick.

## 2026-06-03 / Sleep/Wake Cancellation Synchronization

**Date:** 2026-06-03

**Area:** Sleep/wake timer reconciliation

**Context:** A follow-up review of the synchronous live sleep/wake registrar found that `LiveSleepWakeObservationRegistrar` still shared a plain captured `Bool` between the notification callbacks and the cancellation closure. Those closures can run on different threads, so the earlier fix still left teardown and delivery racing on unsynchronized mutable state.

**Decision:** Replace the shared local `Bool` with a small synchronized cancellation state object, and have both observer callbacks and the cancellation closure consult that shared state before delivering or removing observers.

**Rationale:** This is the smallest fix that preserves the current public-notification seam and synchronous-delivery ordering while removing the last shared-mutable-state race from the registrar implementation.

**Consequences:** Sleep/wake observer teardown is now idempotent without relying on unsynchronized captured locals, and future lifecycle fixes can build on the stronger guarantee that late callbacks will observe a thread-safe cancelled state before touching coordinator code.

**Alternatives Considered:** Keep the local `Bool` and rely on main-thread delivery by convention; rejected because the implementation already explicitly handles non-main delivery and therefore needs a real synchronization boundary. Move the whole registrar behind an actor; rejected because that would complicate a currently small seam without improving the synchronous delivery contract.

## 2026-06-03 / External Review Artifact Hygiene

**Date:** 2026-06-03

**Area:** External review workflow

**Context:** The external review loop reported `NO ISSUES FOUND`, and local verification confirmed the sleep/wake branch behavior by re-reading the plan, tracing `AppCoordinator` and `SleepWakeObservation`, and running the full XCTest suite. The only remaining worktree noise was an untracked repo-root `output.txt` scratch file written by the review loop itself, which is not part of Mahu's product or engineering artifacts.

**Decision:** Ignore the review loop's root `output.txt` scratch artifact in `.gitignore`, keep it out of product commits, and treat no-issue review rounds as documentation-only close-out rather than inventing unrelated code changes.

**Rationale:** This is the smallest repo-owned fix that makes clean review passes truthfully look clean while preserving the explicit durable handoff trail required by the workflow.

**Consequences:** Future no-issue review passes no longer leave a misleading dirty worktree because of this one scratch file, and the external-loop completion step can focus on tracked product/docs changes only. If the project later needs a committed root-level `output.txt` for some legitimate reason, this ignore rule should be revisited or the generated artifact should move to a more specific path.

**Alternatives Considered:** Leave `output.txt` untracked and document the ambiguity every time; rejected because it keeps recurring workflow noise in the repo root. Ignore a broader pattern such as `*.txt`; rejected because it could hide legitimate project files.

## 2026-06-03 / Break Overlay Startup Retry Preservation

**Date:** 2026-06-03

**Area:** Break overlay display reconciliation

**Context:** Review of the display-hotplug/startup resync path found that `BreakOverlayManager.showBreak(...)` tore down the entire break session when the immediate post-registration resync temporarily left zero overlay windows. That cleared the original `previousFrontmostApplication`, so the next retry would capture a different frontmost app and violate the break invariant against recapturing during resync.

**Decision:** Keep the current break session state alive when startup-time resync yields zero visible overlay windows, return `false` to the caller, and let the next retry reuse the existing view model and original previous-app capture.

**Rationale:** This is the smallest local fix that matches the existing mid-break zero-window preservation behavior without widening `BreakOverlayManager` responsibilities or changing the coordinator contract.

**Consequences:** A transient no-display startup race no longer loses the original app-restoration target. Future retries during the same break can recreate overlay windows without recapturing frontmost state or replacing the shared countdown/skip session.

**Alternatives Considered:** Keep tearing down the session and accept recapture on the next retry; rejected because it breaks an explicit product invariant. Force `showBreak(...)` to stay `true` even with zero windows; rejected because the coordinator still needs an accurate visible/non-visible signal for countdown and sound behavior.

## 2026-06-03 / Tray Timer Width Stabilization

**Date:** 2026-06-03

**Area:** Status item timer presentation

**Context:** Review of the optional timer-mode tray UI found that `StatusItemController` left the item in `NSStatusItem.variableLength` mode for every title update. With valid long-duration timers, minute digits can cross boundaries such as `100:00 -> 99:59`, which shrinks the item width mid-countdown and makes the tray icon drift horizontally.

**Decision:** Keep the existing countdown text format, but measure timer-mode title width and pin the status item to the widest observed length for the current enabled session instead of letting every countdown tick recalculate a smaller `variableLength` frame.

**Rationale:** This is the smallest fix that restores the documented stable-width tray behavior without changing the existing text contract, introducing a custom status-item view, or narrowing supported schedule durations.

**Consequences:** Timer mode still renders the same title strings, but the menu-bar item no longer shrinks when the countdown crosses minute digit boundaries. Regression tests now lock down both ordinary countdown updates and the `100:00 -> 99:59` edge case directly.

**Alternatives Considered:** Cap supported durations to keep all timer text inside two minute digits; rejected because it would silently narrow Mahu's general schedule contract. Switch to a different display format such as `HH:MM:SS`; rejected because that would expand scope into a user-facing contract change instead of a review hardening fix.

## 2026-06-03 / Launch at Login Desired-State Store

**Date:** 2026-06-03

**Area:** Launch-at-login settings architecture

**Context:** Task 2 of the launch-at-login plan needed a focused store that startup wiring and a future Settings UI can share before the real `SMAppService` adapter exists. The store also had to stay independent from disk persistence and from the actual macOS Login Item status.

**Decision:** Add `LaunchAtLoginSettingsStoring` and `LaunchAtLoginSettingsStore` as a dedicated `@MainActor` in-memory Bool store, seeded either directly from `launchAtLoginEnabled` or from `AppConfig`, with observer callbacks and no-op repeated updates.

**Rationale:** This keeps desired state separate from actual Login Item state, mirrors the existing runtime-settings observer seam closely enough for predictable coordinator wiring, and avoids pulling filesystem or ServiceManagement concerns into the store.

**Consequences:** Later startup reconciliation can consume a small launch-at-login-specific dependency, while future UI work already has observer cancellation and idempotent update behavior locked down by tests.

**Alternatives Considered:** Reuse `RuntimeSettingsStore` for a single Bool field; rejected because it keeps unrelated schedule and overlay settings in scope. Store actual macOS registration/approval state in the same object; rejected because that belongs to the next ServiceManagement layer and would blur intent with external system state.

## 2026-06-03 / Launch at Login Review Hardening

**Date:** 2026-06-03

**Area:** Launch-at-login startup reconciliation

**Context:** Review of the launch-at-login branch found that `LaunchAtLoginController.syncDesiredState()` validated thrown register/unregister errors and a narrow subset of final statuses, but it could still report silent success when `SMAppService` stayed in the wrong end state after a mutation. The same pass also showed the targeted tests covered only pre-mutation approval/unavailable states and thrown errors, leaving post-mutation mismatch paths unguarded.

**Decision:** After `register()` or `unregister()`, always re-read the final manager status and treat any end state that still contradicts the desired launch-at-login value as a non-fatal warning. Keep `.requiresApproval` and `.unavailable` as explicit status-driven warnings, and map all other mismatches onto the existing registration/unregistration failure warnings.

**Rationale:** This is the smallest fix that preserves the current controller contract and diagnostics surface while making startup sync truthful about end-state drift instead of only about thrown errors.

**Consequences:** Mahu now logs/report warnings when macOS leaves the Login Item disabled after a requested enable, or enabled/requires-approval after a requested disable, even if the ServiceManagement call itself returned normally. Regression tests now lock the previously uncovered post-mutation approval, unavailable, and mismatch branches directly.

**Alternatives Considered:** Add a brand-new `stateMismatch` warning enum; rejected because the existing registration/unregistration failure warnings already communicate the actionable outcome without widening the public contract. Keep treating non-throwing mutations as success; rejected because that hides real launch-at-login drift from both logs and tests.

## 2026-06-03 / Sleep-Entry Break-Completion Silence

**Date:** 2026-06-03

**Area:** Sleep/wake active-rest reconciliation

**Context:** Review found a boundary case in `AppCoordinator.settleElapsedAwakeTimeBeforeSleep()`: if Mahu settled the last visible seconds of an active break exactly as the machine was entering sleep, the shared elapsed-time path could cross `rest -> work` and trigger the natural completion sound before the later long-sleep reset. That contradicts the documented contract that long sleep during an active break tears down silently into a fresh work interval.

**Decision:** Keep `willSleep` awake-time settlement for timer truth, but force that path to stay silent even if it completes the current break before the later wake reconciliation resets Mahu to work.

**Rationale:** This is the smallest local change that preserves short-sleep accounting and the existing break timer flow while making sleep-interrupted breaks consistently silent.

**Consequences:** A break that reaches zero during sleep-entry bookkeeping now tears down without playing `break-completion.caf`, and new regression coverage exercises the exact `rest -> work` transition at sleep entry. Natural visible break completion outside the sleep path still follows the existing one-shot sound contract.

**Alternatives Considered:** Skip `willSleep` settlement entirely for active breaks; rejected because short sleep would then lose already-earned awake time. Keep the audible completion because the elapsed slice was technically visible; rejected because sleep entry is an interruption boundary and the shipped long-sleep contract is explicitly silent reset, not natural completion.

## 2026-06-03 / Launch at Login Runtime Source of Truth

**Date:** 2026-06-03

**Area:** Runtime settings / Launch at Login

**Context:** The launch-at-login plan introduced a dedicated desired-state store plus startup reconciliation through `LaunchAtLoginController`, while the broader runtime-settings foundation already documented `RuntimeSettingsStore` as Mahu's single in-process source of truth for future Settings UI work. A second review pass found that `AppCoordinator` seeded the launch-at-login store only once at startup and never forwarded later runtime edits of `AppConfig.launchAtLoginEnabled`, so in-app settings changes could diverge from the Login Item state in memory.

**Decision:** Keep `RuntimeSettingsStore` authoritative for the in-process `AppConfig`, but continue using the dedicated launch-at-login Bool store/controller seam by reconciling it from `handleRuntimeSettingsChange(_:)` whenever `launchAtLoginEnabled` changes at runtime.

**Rationale:** This is the smallest safe fix for the review finding. It preserves the existing launch-at-login-specific seam for future Settings UI and ServiceManagement integration, while restoring the already documented single-source-of-truth contract without a wider refactor during the review loop.

**Consequences:** Runtime settings updates that flip `launchAtLoginEnabled` now update the dedicated launch-at-login store and immediately trigger the same sync/controller path used at startup. Focused coordinator regression tests now guard both enable and disable runtime transitions plus the no-op case when unrelated runtime settings change.

**Alternatives Considered:** Collapse launch-at-login intent directly into `RuntimeSettingsStore` and remove the dedicated Bool store; rejected because it would be a broader architectural rewrite during a review-fix pass and would blur the seam intentionally reserved for future Settings UI. Leave launch-at-login startup-only and defer runtime propagation to the future Settings UI feature; rejected because it violates the current runtime-settings invariant and would preserve a known divergence bug in shipped coordinator behavior.

## 2026-06-03 / Config Save Symlink Hardening

**Date:** 2026-06-03

**Area:** Config persistence security

**Context:** A follow-up review found that the earlier "preserve `config.json` symlinks on save" behavior resolved the link target and wrote through it. If `~/Library/Application Support/Mahu/config.json` is replaced with a symlink to another user-writable file, the next config save becomes an arbitrary local file overwrite outside the Mahu config directory.

**Decision:** Refuse `ConfigStore.save(_:)` when the configured `config.json` path itself is a symbolic link. Continue allowing `load()` to read symlink targets so manual compatibility stays intact, but require writes to target the real Mahu config path directly.

**Rationale:** This is the smallest safe fix for a real local-write primitive. Losing write-through support for shared-dotfile-style symlink setups is acceptable here because Mahu has no shipped Settings UI yet, and silent arbitrary-file overwrite is the higher-risk behavior.

**Consequences:** Saving through a symlinked `config.json` now returns `false`, logs a warning, leaves the symlink untouched, and does not mutate the linked target file. Symlink-based reads still work, so existing manual setups keep launch-time compatibility until a future write path explicitly chooses a safer supported model.

**Alternatives Considered:** Keep resolving and writing through symlinks; rejected because it preserves the overwrite primitive. Allow symlink saves only when the resolved target stays inside the Mahu config directory; rejected for now because it is more code and complexity during a review-fix pass, while outright refusal closes the security gap immediately.

## 2026-06-03 / Config Directory Symlink Hardening

**Date:** 2026-06-03

**Area:** Config persistence security

**Context:** The earlier review fix refused writes only when the final `config.json` path itself was a symbolic link. A follow-up review showed that `~/Library/Application Support/Mahu` could still be replaced with a symlink to another directory, which made both `load()` and `save()` follow that redirected parent path and bypass the intended direct-path safety contract.

**Decision:** Treat `~/Library/Application Support/Mahu` as part of the trusted managed path: require it to be either missing or a real directory, reject loads when it is a symlink or another filesystem object, and refuse saves before directory creation when that managed directory path is not direct.

**Rationale:** This is the smallest targeted hardening that closes the concrete parent-directory bypass without widening the config format or adding heavier fd-based path-walking in the middle of a review-fix pass.

**Consequences:** Symlink-based reads remain supported only at the final `config.json` entry itself; redirecting the whole Mahu support directory no longer works for reads or writes. Review coverage now locks both the old final-file symlink refusal and the new parent-directory guard.

**Alternatives Considered:** Leave parent-directory symlinks untouched and document the risk; rejected because it preserves the same local path-redirection primitive through one level up the tree. Rebuild config I/O around `openat`/`O_NOFOLLOW` for every path component; rejected for now because it is a larger low-level rewrite than needed to close the confirmed bypass in this pass.

## 2026-06-03 / Sleep/Wake Long-Sleep Measurement

**Date:** 2026-06-03

**Area:** Sleep/wake timer reconciliation

**Context:** The shipped sleep/wake policy classified “long sleep” from `Date` values recorded at `willSleep` and `didWake`. Review pointed out that wall-clock deltas can move independently of actual elapsed sleep because of NTP correction, timezone changes, DST shifts, or manual clock edits while the Mac is asleep.

**Decision:** Keep public `NSWorkspace` lifecycle notifications, but measure the elapsed sleep interval from a sleep-inclusive monotonic provider backed by `ContinuousClock` instead of wall-clock `Date`.

**Rationale:** The product contract is about real elapsed sleep reaching the 300-second threshold, not about wall-clock drift. A monotonic source is the smallest truthful measurement change that preserves the rest of the coordinator flow and existing fake-lifecycle tests.

**Consequences:** Long-sleep resets now follow actual recorded elapsed sleep even if the wall clock barely moves or jumps unexpectedly during sleep. Tests gained a focused regression that proves wake reconciliation prefers the monotonic source over a misleading wall-clock delta.

**Alternatives Considered:** Keep wall-clock `Date` because the edge case is rare; rejected because it makes the reset contract nondeterministic under legitimate system time changes. Switch the whole coordinator to a new clock abstraction everywhere; rejected because only long-sleep classification needed the stronger clock source in this pass.

## 2026-06-03 / Config Write TOCTOU Hardening

**Date:** 2026-06-03

**Area:** Config persistence security

**Context:** Earlier review fixes refused obvious symlinked `config.json` and symlinked `~/Library/Application Support/Mahu` paths, but `ConfigStore.save(_:)` and missing-config default creation still validated the path and then wrote through `FileManager`/`Data.write` separately. That left a local race window where another process could swap `Mahu/` or `config.json` between the check and the actual write.

**Decision:** Move config writes onto checked directory file descriptors: create or open the managed Mahu directory with `mkdirat`/`openat(..., O_NOFOLLOW)`, write a temporary file inside that directory, and atomically replace `config.json` with `renameat`. Reuse the same path for default-config creation so the load-on-missing path does not retain the old race.

**Rationale:** This is the smallest truthful hardening that closes the confirmed TOCTOU gap without changing the shipped config-file contract or removing supported final-file symlink reads.

**Consequences:** Saving or creating the default config no longer depends on a path-based preflight remaining true until a later write. The repo keeps the current asymmetric contract: symlinked `config.json` still loads, but writes require the managed Mahu path to be direct and are now race-resistant inside that directory.

**Alternatives Considered:** Keep the existing preflight and only re-check just before `Data.write`; rejected because it still leaves a race between the second check and the actual write. Reject all symlink-based config reads too; rejected because the current product contract intentionally preserves final-file symlink compatibility for launch-time manual setups.

## 2026-06-03 / Status Item Main-Actor Contract

**Date:** 2026-06-03

**Area:** Menu-bar UI threading

**Context:** `StatusItemController` owns `NSStatusItem`, `NSMenu`, and `NSStatusBarButton`, but its protocol surface and fake test double were not explicitly main-actor isolated. Current call sites happen to be on the main actor via `AppCoordinator`, yet nothing in the type system prevented a future background call from mutating AppKit state.

**Decision:** Mark `StatusItemControlling`, `StatusItemController`, and the fake status-item controller used in tests as `@MainActor`, and keep default AppKit-dependent closures resolved from inside actor-isolated initializers/methods rather than from nonisolated default arguments.

**Rationale:** AppKit is a main-thread API surface. Encoding that contract in the type system is the smallest way to prevent future background-call regressions without changing any user-visible behavior.

**Consequences:** Compiler checking now protects the menu-bar controller boundary, and test doubles follow the same threading contract as production code. Existing coordinator wiring stays synchronous because it already runs on the main actor.

**Alternatives Considered:** Leave the contract implicit and rely on current call sites; rejected because it makes future regressions easy and compiler-silent. Remove AppKit access from the controller entirely; rejected because it is a larger architectural rewrite than needed for this review fix.

## 2026-06-03 / Sleep/Wake Wall-Clock Seam Removal

**Date:** 2026-06-03

**Area:** Sleep/wake timer reconciliation

**Context:** After the long-sleep policy switched from wall-clock `Date` to a sleep-aware monotonic time provider, `AppCoordinator.init` and multiple tests still carried an unused `currentWallClockDate` seam. That API surface now implied a dependency the production code no longer had.

**Decision:** Remove `CurrentWallClockDateProvider`, the `currentWallClockDate` initializer parameter, and the corresponding test-only helpers/arguments.

**Rationale:** Dead seams increase cognitive load and mislead future reviews into thinking wall-clock time still influences wake reconciliation. Removing the seam is smaller and safer than keeping fake coverage for a path that no longer exists.

**Consequences:** `AppCoordinator` now exposes only the clocks it actually uses, and the sleep/wake tests no longer carry irrelevant wall-clock plumbing. The existing monotonic-clock regression coverage remains intact through the sleep-aware provider seam.

**Alternatives Considered:** Keep the unused seam “just in case” wall-clock logic returns later; rejected because it adds confusion now and can be reintroduced intentionally if product requirements change.

## 2026-06-03 / Launch at Login Thrown-Error Final Status Reporting

**Date:** 2026-06-03

**Area:** Launch-at-login startup reconciliation

**Context:** `LaunchAtLoginController.syncDesiredState()` already re-read final status after successful register/unregister calls, but the thrown-error branches still returned the pre-mutation status. A review pointed out that ServiceManagement can fail after partially changing the Login Item end state, which made the warning truthful but the reported status stale.

**Decision:** After a thrown register/unregister attempt, re-read the final manager status and return that end state together with the most specific warning available: prefer `.requiresApproval` or `.unavailable` when those are the actual end states, otherwise keep the existing registration/unregistration failure warning.

**Rationale:** This preserves the current warning contract while making diagnostics and tests truthful about the end state Mahu actually observed after the failed call.

**Consequences:** Review and runtime logs can now distinguish “failed but now requires approval” from “failed and still disabled”, or “failed but actually ended disabled” from “failed and still enabled”. Focused tests now cover thrown-error paths where the fake manager changes status before throwing.

**Alternatives Considered:** Keep returning the pre-mutation status on thrown errors; rejected because it hides real end-state drift. Add new warning enum cases for every thrown-plus-final-state combination; rejected because the current warning surface already conveys the actionable outcome without growing the contract unnecessarily.

## 2026-06-03 / Paused Status-Item Icon Readability

**Date:** 2026-06-03

**Area:** Status item timer presentation

**Context:** The paused-reminder implementation dimmed `NSStatusBarButton.alphaValue`, which visually affected both the icon and any timer/`Paused` text. Review found that this contradicted the shipped timer-mode contract that break countdown text should remain readable while only the tray icon conveys the paused cue.

**Decision:** Keep using the same tray icon asset, but render a dimmed copy only for the image slot while leaving the status-item button and text at full opacity.

**Rationale:** This is the smallest AppKit-only fix that restores the documented readability contract without adding a second paused asset or disabling the menu-bar control.

**Consequences:** Paused reminders still look visibly dimmed, but timer-mode text and `Paused` stay fully legible during work and active breaks. Controller and acceptance tests now assert full button opacity plus image-data changes instead of the old whole-button alpha band.

**Alternatives Considered:** Keep dimming the entire button; rejected because it obscures live countdown text. Add a separate paused icon asset; rejected because the product contract already requires reusing the existing tray glyph.

## 2026-06-03 / Break Overlay Dormant-Session Recovery

**Date:** 2026-06-03

**Area:** Break overlay lifecycle

**Context:** Review found one remaining zero-display race at break start. If `screenProvider()` returned no displays on the first entry into `rest`, `BreakOverlayManager.showBreak()` returned `false` before creating any shared session state. That meant there was no `viewModel`, no previous-app capture, and no screen observer, so recovery waited for the next timer tick and could recapture a different frontmost app after displays returned.

**Decision:** Preserve a dormant break session even when break start sees zero active displays: create the shared `viewModel`, capture the previous app once, register screen/focus observation, and only skip activation until windows can be materialized on a later screen-change event.

**Rationale:** This is the smallest fix that restores the documented “do not recapture the previous app during an active break” invariant and lets display recovery happen immediately from screen notifications rather than from the next scheduled tick.

**Consequences:** Break start can now return `false` while still keeping a live dormant session. When a display reappears, the existing break state becomes visible without rebuilding the session or changing the shared countdown/Skip state.

**Alternatives Considered:** Keep the current retry-on-next-tick path; rejected because it delays recovery and can restore the wrong application. Treat zero displays as a hard failure that cancels the break; rejected because it silently loses an already-started rest interval during transient display races.

## 2026-06-03 / Config Write Durability Sync

**Date:** 2026-06-03

**Area:** Config persistence durability

**Context:** Earlier hardening moved config writes onto directory file descriptors and `renameat`, but review found the success path still stopped after fsyncing the temporary file. Without also syncing the containing directory entries, `save()` could return `true` even though a crash or power loss might still lose the renamed `config.json` or a just-created `Mahu/` directory.

**Decision:** After a successful `renameat`, fsync the managed Mahu config directory. If the write created the `Mahu/` directory in the same call, fsync the parent Application Support directory as well before reporting success.

**Rationale:** Atomic replacement alone protects against torn files, but directory fsync is what makes the rename and directory creation durable. This is the smallest truthful fix that closes the remaining data-integrity gap without redesigning the storage layer.

**Consequences:** Successful config saves now mean both file bytes and directory entries were flushed through the same write path. Tests can verify the extra sync contract deterministically through the injected sync hook without depending on power-failure simulation.

**Alternatives Considered:** Leave durability to the filesystem and accept occasional post-crash config loss; rejected because it makes `save()` overclaim success. Introduce a full file-operations abstraction for every POSIX call; rejected because the targeted sync hook covers this fix with much less churn.
