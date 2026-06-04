# Session Handoff

## 2026-06-03 / Sleep Wake Sync Delivery Review Fix

🏁 Session Handoff:
- Status: Done
- Key Decisions: Deliver live `willSleep` and `didWake` callbacks synchronously onto the main actor instead of routing them through fire-and-forget `Task` hops; keep the existing `SleepWakeObservation` seam and fake registrar contract, but strengthen live tests to assert synchronous delivery because ordering against the first post-wake tick is the real product risk.
- Validation: `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO -only-testing:MahuTests/LiveSleepWakeObservationRegistrarTests -only-testing:MahuTests/AppCoordinatorTests -only-testing:MahuTests/AppCoordinatorSleepWakeAccountingTests`; `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`; `make build`; `git diff --check`; `command -v swiftlint`; `rg -n "(^lint:|swiftlint|make lint)" Makefile README.md`
- Friction/CDD: The repo still has no tracked lint target and `swiftlint` is not provisioned in this environment, so the strongest reproducible proof here remains build/test/package plus diff hygiene. Real lid-close/open timing is still hardware-sensitive even after the synchronous delivery fix, so manual sleep/wake verification on a real Mac remains the final confidence step.
- Next Steps: Let the external review loop rerun from the next fix commit. If lint must be a hard gate, add a repo-owned lint target or provide `swiftlint` in the execution environment. During manual validation, specifically re-check lid-close and Apple-menu sleep/wake flows to confirm the first post-wake tick no longer overtakes lifecycle reconciliation.
