# Factor Golf Quick Coach Beta - DECISION / RELEASE LOG

## Product decisions
- Quick Coach is a separate product from Factor Golf Sim Control Center.
- Product name: **Factor Golf Quick Coach Beta**.
- Far-right foot pedal is the permanent Quick Coach trigger.
- Trigger key: **F18**.
- Quick Coach is optimized for normal tournament/18-hole GSPro play.
- Golfer Experience and Persona mirror Factor Golf concepts but Quick Coach does not depend on Factor Golf runtime code.
- Main Factor Golf baseline must not be modified to fix Quick Coach.
- User-facing goal: after one bootstrap install, future accepted releases update with one in-app button.
- Screenshot analysis and realtime voice are separate transports.
- Natural conversational voice target: **gpt-realtime-2.1-mini**.

## v0.1.0
Initial prototype.
Real-machine result: API key appeared to save but was unavailable to the test path.
Status: REJECTED.

## v0.1.1
Attempted key-persistence hotfix.
Real-machine result: FAIL.
Exact error: `Unable to find type [Security.Cryptography.ProtectedData]`
Root cause: wrong .NET DPAPI type reference.
Status: REJECTED.

## v0.1.2
Changes included correct fully-qualified DPAPI type and save-time key verification.
Before Halliseum validation, source inspection found a malformed startup/config migration block that could break launch/parsing.
Status: SUPERSEDED / DO NOT TEST.

## v0.1.3
Current candidate.

Changes:
- Correct malformed v0.1.2 startup/config migration block.
- Preserve corrected Windows DPAPI key storage and read-back verification.
- Screenshot analysis uses gpt-6-luna via Responses API.
- reasoning.effort set to none for this low-latency screenshot task.
- gpt-realtime-2.1-mini remains reserved for future Realtime audio conversation.
- Better API error diagnostics.
- Hide Quick Coach during manual screenshot test to prevent self-capture.
- Stable install directory + desktop shortcut bootstrap installer.
- Future updater rewritten around immutable per-version files + SHA-256 verification.

Off-machine validation:
- JSON parse PASS
- embedded XAML parse PASS
- targeted regression assertions PASS
- delimiter sanity PASS
- ZIP integrity PASS

Halliseum validation: OPEN.

Release acceptance rule:
Never call a Quick Coach build accepted because it packages or passes static checks. Hardware/Windows/GSPro/OpenAI-dependent behavior remains OPEN until actually proven on the Halliseum.


## Halliseum finding: v0.1.3
Real-machine evidence on 2026-10-05:
- API key save/read-back verification: PASS.
- GSPro capture: PASS at 1920x1080.
- OpenAI Responses API request: PASS.
- Model response returned successfully.
- Main Quick Coach UI disappeared during/after the coaching cycle.
- Windows TTS started but speech was cut off almost immediately.

Source diagnosis:
- v0.1.3 called the main WPF window Hide() before capture.
- The pedal path did not restore that main window.
- The main window is hosted with ShowDialog(), so hiding the modal window can end the dialog lifetime and allow process teardown, which can also truncate asynchronous TTS.
- This lifecycle defect is the primary fix target. TTS truncation will remain instrumented until Halliseum proves the fix.

Status: v0.1.3 REJECTED FOR FORWARD TESTING.

## v0.1.4
Current candidate.

Changes:
- Removes main-window Hide() from the coaching cycle.
- Uses temporary opacity only during the actual screen copy, then restores immediately.
- Keeps the main WPF lifetime intact during F18 coaching.
- Fixes config-load enumeration warning.
- Logs GSPro window coordinates.
- Adds TTS start/completion/cancel/error diagnostics.
- Fixes unreadable dark-theme checkbox labels.
- Renames shot context field for clarity.
- Persists Quick Coach window position.
- Adds EXPORT DIAGNOSTICS; API-key secret is explicitly excluded.

Off-machine gates passed:
- config JSON parse
- embedded XAML parse
- targeted lifecycle regression assertions
- diagnostics secret-exclusion allowlist check
- ZIP integrity

Halliseum validation: OPEN.
