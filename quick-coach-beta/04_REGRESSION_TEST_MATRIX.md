# Factor Golf Quick Coach Beta - REGRESSION TEST MATRIX

Legend:
- PASS = actually proven
- FAIL = actually broken
- OPEN = not yet proven
- STATIC = can be checked off Halliseum
- HALLISEUM = requires Josh's simulator PC / GSPro / pedal / audio

| Area | v0.1.2 status | Gate |
|---|---|---|
| Config JSON parses | PASS | STATIC |
| Embedded WPF/XAML parses | PASS | STATIC |
| ZIP integrity | PASS | STATIC |
| App launches on Halliseum | OPEN | HALLISEUM |
| API key saves without exception | OPEN | HALLISEUM |
| API key decrypts/read-backs correctly | OPEN | HALLISEUM |
| UI only says SAVED + VERIFIED after round-trip | OPEN | HALLISEUM |
| GSPro window is found | OPEN | HALLISEUM |
| Full GSPro screenshot is correct | OPEN | HALLISEUM |
| TEST SCREENSHOT + COACH returns feedback | OPEN | HALLISEUM |
| Feedback respects visible/measured data | OPEN | HALLISEUM |
| F18 is detected while GSPro is active | OPEN | HALLISEUM |
| One F18 press causes one request | OPEN | HALLISEUM |
| Repeat presses work independently | OPEN | HALLISEUM |
| Temporary overlay appears correctly | OPEN | HALLISEUM |
| Overlay disappears automatically | OPEN | HALLISEUM |
| Spoken fallback works | OPEN | HALLISEUM |
| Main Factor Golf is untouched | PASS by design / verify packaging | STATIC |
| Quick Coach settings survive restart | OPEN | HALLISEUM |
| In-app update check reaches manifest | OPEN | integration |
| Update ZIP SHA-256 verification | OPEN | automated/integration |
| Update preserves settings/API key | OPEN | automated + HALLISEUM |
| Realtime Mini natural voice | NOT IMPLEMENTED | future |
| Voice follow-up conversation | NOT IMPLEMENTED | future |
| Inactivity auto-close | NOT IMPLEMENTED | future |

## Stop rule
If a previously proven Quick Coach behavior regresses, stop forward patching, identify the cause, and restore the last accepted Quick Coach baseline before adding more changes.
