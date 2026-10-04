# Migration audit — 2026-10-04

## Accepted source and provenance
All 74 entries in the original migration hash manifest match. Both embedded ZIPs pass CRC/integrity testing. The source tree is byte-identical to the accepted v0.8.14 ZIP. Its version marker and default configuration both read 0.8.14. Assets remain under src/assets to preserve the exact application's relative paths.

Original documents are immutable historical snapshots. The current project instruction addresses the owner as Josh; the imported instruction's older “Big Daddy” wording is preserved as evidence.

## Rejected changes
v0.8.15 changed exactly:
- workers/Halliseum_Club_Cheat_Watcher.ps1
- workers/Halliseum_Settings.ps1
- app_version.txt
- config.default.json (only Version changed)

The main launcher, navigation worker, display helper, connector minimizer and updater are byte-identical across packages. This excludes a direct edit to those files, not a runtime interaction. v0.8.15 introduced smaller OCR crops/local diagnostics and Settings result popups. The real-machine navigation failure is recorded; its cause is not proven. Do not reuse the rejected changes without investigation.

A directly inspected v0.8.14 defect: Update-ClubSelectorCalibrationStatus returns the saved calibration message before checking club detection results. A saved calibration file can mask a newer detection result. This explains a visibility failure, not failed recognition or the navigation regression.

## Preserved failures and acceptance
v0.8.14 remains the accepted engineering baseline, not feature-complete software. Actual club identification and club-change sheets remain unproven/broken; voice follow-up recognition failed. TTS, Coach Card, no startup Driver card, range navigation and selector-click saving have historical Halliseum passes, not new runtime validation in this environment.

## Regression gates established
- Exact source/evidence/document SHA-256 verification and source inventory.
- Version/default-config consistency.
- Required worker references and removed Coach Controls exclusion.
- Both archived ZIP integrity checks and exact rejected-package changed-file inventory.
- Seven embedded XAML here-string blocks XML-parse in the supplied baseline. Older release notes reported eight; the current imported source contains seven such blocks. XML parsing does not instantiate WPF.
- Windows PowerShell parser gate for every application PS1, on Windows CI.
- Mutation tests prove detection of navigation tampering, missing workers, version drift, removed-worker reintroduction and malformed XAML.

The baseline pin is deliberately strict. Preserve it as a provenance gate when introducing separate candidate-source regression checks later. This first harness is not the complete release gate: install/upgrade preservation, updater integration, deterministic candidate packaging and hardware behavior still need dedicated checks. No publishing workflow or latest.json is introduced.

## Execution limits
Local Python static checks and mutation tests are run before import. PowerShell is unavailable locally; Windows CI results must be read before claiming syntax success. GSPro, Windows/WPF, audio recognition, display routing and Halliseum behavior cannot be validated on this Linux host. Existing cloud stable-feed rollback is a handoff statement, not independently verified by this import.

## Next engineering step
Confirm Windows CI, preserve the accepted baseline marker, and build candidate install/update/packaging tests before feature fixes. For navigation investigation collect existing worker_launch_status.log, range_nav_status.json, range_nav_debug.json and relevant configuration from the failed run if retained; avoid asking for another speculative build test. Club truth and voice changes belong on controlled branches after the regression is understood or changes are safely based on the accepted baseline.
