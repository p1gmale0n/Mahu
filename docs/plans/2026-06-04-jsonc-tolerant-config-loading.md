# JSONC Tolerant Config Loading

## Overview

Make Mahu's manually edited `config.json` tolerant of common JSONC-style edits on load, while keeping app-generated saves as strict JSON.

This fixes the current user-visible bug where a project-root `config.json` symlink points to the real Application Support config, Zed inserts a `//` comment, and Mahu fails strict `JSONDecoder` parsing before falling back to default 20-20-20 settings with the tray timer disabled.

The change keeps the existing config model, filesystem hardening, and no-live-reload behavior intact. It only changes the read path: raw config bytes are still size-capped, then sanitized from JSONC-like text into strict JSON before `AppConfig` decoding and validation.

## Context (from discovery)

- Files/components involved:
  - `Mahu/ConfigStore.swift` — reads config bytes, decodes via strict `JSONDecoder`, falls back to defaults on decode errors; already large, so only minimal wiring belongs here.
  - `Mahu/AppConfig.swift` — config model and field semantics; required durations stay required, optional fields keep current defaults.
  - New `Mahu/ConfigJSONPreprocessor.swift` — focused scanner for read-only JSONC tolerance.
  - New `MahuTests/ConfigStoreJSONCTests.swift` — focused regression tests for comments, trailing commas, string-literal safety, symlink reads, and malformed JSONC fallback.
  - `README.md` — config documentation and manual edit guidance.
  - `AGENTS.md` — project invariant for config-file behavior.
  - `docs/decisions.md` — durable decision record.
- Related patterns found:
  - Missing optional config keys default safely.
  - Explicit invalid types or `null` values still intentionally trigger whole-config fallback.
  - Final `config.json` symlink reads are allowed when the target is a regular file.
  - Config saves are strict JSON and now intentionally refuse symlink writes for safety.
  - Manual config edits apply only on app relaunch; no live reload exists.
- Dependencies identified:
  - No new third-party dependency is needed.
  - YAML migration was considered and rejected for this fix because it adds parser/package complexity, migration questions, and dual-format precedence for a small config surface.

## Development Approach

- **Testing approach**: TDD.
- Complete each task fully before moving to the next.
- Make small, focused changes.
- **CRITICAL: every task MUST include new/updated tests** for code changes in that task:
  - tests are not optional;
  - write unit tests for new helper behavior;
  - write integration-style config load tests for changed read behavior;
  - cover both success and malformed/error scenarios.
- **CRITICAL: all tests must pass before starting next task** - no exceptions.
- **CRITICAL: update this plan file when scope changes during implementation**.
- Keep `ConfigStore.save(_:)` strict JSON.
- Keep `AppConfig` field semantics unchanged.
- Keep live config reload out of scope.
- Maintain backward compatibility with existing strict JSON configs.

## Testing Strategy

- **Unit tests** are required for every task.
- Add a focused JSONC config test file rather than expanding large existing config test files.
- Required coverage:
  - `//` line comments;
  - `/* ... */` block comments;
  - trailing commas before `}` and `]`;
  - string literals containing `https://`, `//`, `/* */`, escaped quotes, and Unicode;
  - symlinked final `config.json` target containing JSONC;
  - malformed JSONC such as unterminated block comments falls back to defaults;
  - explicit invalid field types and `null` still fall back through existing `AppConfig` decode semantics;
  - oversized raw files remain rejected by the existing 64 KiB cap.
- No UI-based E2E suite exists; manual verification is a local config relaunch scenario.

## Progress Tracking

- Mark completed items with `[x]` immediately when done.
- Add newly discovered tasks with a `➕` prefix.
- Document issues/blockers with a `⚠️` prefix.
- Update this plan if implementation deviates from the original scope.
- Keep the plan in sync with actual work done.

## What Goes Where

- **Implementation Steps**: code changes, tests, project-file wiring, documentation updates, and deterministic verification commands.
- **Post-Completion**: local manual app/config relaunch checks.
- **Checkbox placement**: checkboxes belong only in Task sections. Do not add checkboxes to Overview, Context, Technical Details, or Post-Completion.

## Implementation Steps

### Task 1: Add failing JSONC config-load tests

- [x] create `MahuTests/ConfigStoreJSONCTests.swift` with tests that currently fail for `//` line comments in `config.json`
- [x] add failing tests for `/* ... */` block comments and trailing commas before objects/arrays close
- [x] add failing tests proving strings containing `https://`, comment-like text, escaped quotes, and Unicode are preserved
- [x] add failing tests proving a symlinked final `config.json` target containing JSONC still loads when the target is a regular file
- [x] add failing tests proving malformed JSONC and invalid explicit field types still fall back to `AppConfig.default`
- [x] run targeted config tests and confirm the new JSONC tests fail for the expected parser gap before Task 2

### Task 2: Implement a focused JSONC preprocessor

- [x] add `Mahu/ConfigJSONPreprocessor.swift` with a scanner-based helper that strips comments outside string literals
- [x] implement support for `//` line comments and `/* ... */` block comments without using naive whole-file regex stripping
- [x] implement removal of trailing commas before `}` or `]` outside strings/comments
- [x] make malformed JSONC such as unterminated block comments throw a small preprocessor error for `ConfigStore` to treat as invalid config
- [x] add focused helper-level tests if useful for edge cases not covered through `ConfigStore` integration tests
- [x] run the targeted JSONC/preprocessor tests - must pass before Task 3

### Task 3: Wire JSONC preprocessing into ConfigStore load only

- [x] update `ConfigStore.loadRegularConfig(from:)` to read raw bytes with the existing 64 KiB cap before preprocessing
- [x] decode raw bytes as UTF-8 text, preprocess JSONC text into strict JSON data, and pass sanitized data to existing `JSONDecoder`
- [x] keep existing unsupported-duration, decoding-error, and filesystem fallback behavior unchanged
- [x] keep `ConfigStore.save(_:)` and default config creation strict JSON with no comments/trailing commas
- [x] add new source/test files to `Mahu.xcodeproj/project.pbxproj` target membership as needed
- [x] run targeted config test suite - must pass before Task 4

### Task 4: Harden regressions and preserve existing contracts

- [ ] verify missing optional fields still default safely after preprocessing
- [ ] verify explicit `null` or wrong-type values for optional fields still trigger whole-config fallback
- [ ] verify raw config files over 64 KiB still fall back before successful parsing/preprocessing can occur
- [ ] verify symlinked Mahu config directory and symlinked-save refusal behavior remain unchanged
- [ ] verify strict JSON without comments still loads exactly as before
- [ ] run all config-related tests - must pass before Task 5

### Task 5: Update documentation and decision history

- [ ] update `README.md` to document JSONC-style comments and trailing commas tolerated on load, strict JSON saves, and relaunch-required behavior
- [ ] update `AGENTS.md` to preserve the project invariant: config read is JSONC-tolerant, app writes strict JSON, no live reload
- [ ] update `docs/decisions.md` if implementation choices differ from the decision recorded when this plan was created
- [ ] run `git diff --check` - must pass before Task 6

### Task 6: Verify acceptance criteria

- [ ] verify the reported project-root symlink config with a commented-out line loads custom `workDurationSeconds`, `breakDurationSeconds`, and `showStatusItemTimerState` values
- [ ] verify malformed JSONC still falls back to defaults and does not crash Mahu
- [ ] verify no YAML dependency or config filename migration was introduced
- [ ] run full unit test suite with `xcodebuild test -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [ ] run build with `xcodebuild build -project "Mahu.xcodeproj" -scheme "Mahu" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO`
- [ ] run `make build`
- [ ] run `git diff --check`

## Technical Details

### Supported read-time JSONC tolerance

The config read path should accept:

```jsonc
{
  "breakDurationSeconds": 5,
  "workDurationSeconds": 10,
  "showStatusItemTimerState": true,
  // "breakOverlayMessageText": "temporarily disabled",
}
```

Rules:

- `//` comments are removed outside strings.
- `/* ... */` comments are removed outside strings.
- trailing commas before `}` and `]` are removed outside strings/comments.
- string content remains byte-for-byte semantically intact after decoding, including URLs and comment-like text.
- invalid UTF-8 or malformed JSONC should be handled like invalid config and fall back to defaults.

### Preserved config semantics

- `workDurationSeconds` and `breakDurationSeconds` remain required and must be supported finite durations.
- Missing optional keys retain their defaults:
  - `showStatusItemTimerState: false`
  - `breakOverlayMessageText: "Время отвлечься"`
  - `launchAtLoginEnabled: false`
- Explicit invalid optional values, including `null`, still cause whole-config fallback through decoding failure.
- `ConfigStore.save(_:)` keeps writing strict JSON without comments.

### Rejected alternatives

- **YAML migration**: rejected for this fix because it requires a new parser dependency, a migration plan, precedence rules if both JSON/YAML exist, and future Settings UI write-format decisions.
- **Third-party JSON5 parser**: rejected as unnecessary for this small config surface.
- **Regex-only stripping**: rejected because it can corrupt strings like `"https://example.com"` or `"text /* not comment */"`.

## Post-Completion

*Items requiring manual intervention or external systems - no checkboxes, informational only.*

**Manual verification**:

- Keep the project-root `config.json` symlink pointing at the real Application Support config.
- Use Zed to comment out an optional config line with `//`.
- Relaunch Mahu and verify custom short timings and tray timer display still apply.
- Add a trailing comma after the last active property, relaunch, and verify config still loads.
- Confirm app-generated save paths, once used by future Settings UI, still emit strict JSON.

**Future follow-up**:

- A Settings UI remains the long-term safer UX for non-technical users; this plan only makes the current manual config workflow less brittle.
