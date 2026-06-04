# Session Handoff

## 2026-06-03 / Sleep Wake Dormant Session Review Fix

🏁 Session Handoff:
- Status: Done
- Key Decisions: Treat break-session existence separately from visible overlay windows so startup/display-race dormant sessions cannot survive into the next work interval; suppress the initial `visible=true` callback during first break presentation so existing rest-visibility accounting keeps its previous baseline semantics.
- Validation: `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO -only-testing:MahuTests/AppCoordinatorBreakPresentationTests -only-testing:MahuTests/BreakOverlayManagerTests -only-testing:MahuTests/BreakOverlayDisplayVisibilityTests`; `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `make build`; `git diff --check`; `command -v swiftlint`; `rg -n "(^lint:|swiftlint|make lint)" Makefile README.md`
- Friction/CDD: The coordinator/overlay boundary is still concentrated in `Mahu/AppCoordinator.swift`, so even a small state fix needed a guard for startup callback timing in an already oversized file. The review contract still implies lint proof, but this repo has no tracked lint command and `swiftlint` is not provisioned here, so deterministic validation remains XCTest/build/package plus diff hygiene.
- Next Steps: Let the external review loop rerun from the new fix commit. If lint must stay mandatory, add a repo-owned lint target or provision `swiftlint` in the execution environment. Before the next overlay lifecycle change, split coordinator-facing break session policy from the rest of `AppCoordinator.swift` so visibility/session state stops accumulating there.
