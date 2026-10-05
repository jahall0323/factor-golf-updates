# Factor Golf Quick Coach Beta - REGRESSION TEST MATRIX

Legend:
- PASS = actually proven
- FAIL = actually broken
- OPEN = not yet proven
- STATIC = can be checked off Halliseum
- HALLISEUM = requires Josh's simulator PC / GSPro / pedal / audio

| Area | Current status | Gate |
|---|---|---|
| Config JSON parses | PASS v0.1.4 | STATIC |
| Embedded WPF/XAML parses | PASS v0.1.4 | STATIC |
| ZIP integrity | PASS v0.1.4 | STATIC |
| API key saves without exception | PASS v0.1.3 Halliseum | HALLISEUM |
| API key decrypts/read-backs correctly | PASS v0.1.3 Halliseum | HALLISEUM |
| UI only says SAVED + VERIFIED after round-trip | PASS v0.1.3 Halliseum | HALLISEUM |
| GSPro window is found | PASS v0.1.3 Halliseum | HALLISEUM |
| GSPro screenshot capture | PASS v0.1.3 at 1920x1080 | HALLISEUM |
| OpenAI screenshot request completes | PASS v0.1.3 | HALLISEUM |
| Coaching text is returned | PASS v0.1.3 | HALLISEUM |
| Main UI remains alive after F18 cycle | FAIL v0.1.3 / fix candidate v0.1.4 | HALLISEUM |
| Full TTS response completes | FAIL v0.1.3 / instrumented v0.1.4 | HALLISEUM |
| F18 causes one request | OPEN | HALLISEUM |
| Repeat presses work independently | OPEN | HALLISEUM |
| Temporary overlay appears correctly | OPEN | HALLISEUM |
| Overlay disappears automatically | OPEN | HALLISEUM |
| Quick Coach window position persists | OPEN v0.1.4 | HALLISEUM |
| Dark-theme checkbox labels readable | OPEN v0.1.4 | HALLISEUM |
| EXPORT DIAGNOSTICS excludes API secret | PASS static v0.1.4 | STATIC |
| Main Factor Golf remains untouched | PASS by separation | STATIC |
| In-app update check reaches manifest | FAIL/404 in v0.1.3; feed bootstrap still OPEN | integration |
| Realtime Mini natural voice | NOT IMPLEMENTED | future |
| Voice follow-up conversation | NOT IMPLEMENTED | future |
| Inactivity auto-close | NOT IMPLEMENTED | future |

## v0.1.4 focused Halliseum gate
1. Install v0.1.4.
2. GSPro full-screen on projector.
3. Quick Coach on Sceptre.
4. Hit one shot and wait for result data.
5. Tap F18 once.
6. Confirm Quick Coach main UI remains alive/visible.
7. Confirm coaching response returns.
8. Confirm full spoken response completes.
9. Confirm popup behaves normally if enabled.
10. If anything fails, export diagnostics and stop forward patching.

## Stop rule
If a previously proven Quick Coach behavior regresses, stop forward patching, identify the cause, and restore the last accepted behavior before adding more changes.
