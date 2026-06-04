# Decision History

| Date | Area | Decision | Rationale |
| --- | --- | --- | --- |
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

## 2026-05-25 / Tray Icon Retina Asset Verification

## 2026-05-28 / Paused Reminder Icon State

**Date:** 2026-05-28

**Area:** Paused reminder icon state

**Context:** The pause/resume menu feature already exposed the reminder-enabled state through menu titles, but the new follow-up requires a visual paused cue in the tray without changing timer semantics or adding a second asset variant.

**Decision:** Keep the same `TrayIconTemplate` image path and implement the paused cue entirely inside `StatusItemController` by applying a lower alpha value to the existing status item button when reminders are paused, then restoring full opacity when reminders resume.

**Rationale:** The status item layer already owns AppKit presentation state, so dimming there is the smallest correct change. It preserves the existing asset contract and keeps the button/menu interactable, avoiding the misleading disabled-control behavior that `isEnabled = false` would introduce.

**Consequences:** Pause/resume remains a coordinator-owned semantic change, while tray presentation stays localized to the AppKit edge. Manual menu-bar readability validation is still required because XCTest can prove state transitions, not live menu-bar rendering quality.

**Alternatives Considered:** Add a second paused icon asset; rejected because the plan and product constraints require reusing the existing template asset. Disable the status item button to get a dimmed appearance for free; rejected because it risks breaking click/menu interaction and communicates the wrong UI state.

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
