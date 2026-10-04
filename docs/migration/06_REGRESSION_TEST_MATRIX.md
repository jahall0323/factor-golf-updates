# FACTOR GOLF SOFTWARE - REGRESSION TEST MATRIX

Legend:
- PASS = confirmed on Halliseum
- FAIL = confirmed broken
- OPEN = not proven / needs retest
- STATIC = can be checked without Halliseum
- HALLISEUM = requires real machine

| Area | Accepted baseline v0.8.14 | v0.8.15 result | Gate before next release |
|---|---|---|---|
| App launches | PASS | PASS enough to start test | STATIC + smoke |
| Config/settings preservation | PASS historically | OPEN | automated install/upgrade check |
| GSPro normal launch/update path | PASS historically | OPEN | HALLISEUM |
| Practice click | PASS | FAIL/sequence did not reach range | HALLISEUM |
| GS Pro Practice Range click | PASS | FAIL/sequence did not reach range | HALLISEUM |
| Saved range calibration preserved | PASS | OPEN | config diff + HALLISEUM |
| SwingNerds launch | PASS historically | OPEN | HALLISEUM |
| Correct Foresight connector launch | PASS historically | OPEN | HALLISEUM |
| Connector minimization | PASS historically | OPEN | HALLISEUM |
| No startup Driver Cheat Sheet | PASS | OPEN | HALLISEUM |
| Club Selector calibration prompt | PASS | OPEN | HALLISEUM |
| Club Selector click save | PASS | OPEN | HALLISEUM |
| TEST CLUB DETECTION returns visible result | FAIL | not reached | HALLISEUM |
| Actual club identification | FAIL/OPEN | not reached | HALLISEUM |
| I/K club-change sheet | FAIL | not reached | HALLISEUM |
| Boundary presses do not drift | design rule, not proven | not reached | HALLISEUM |
| Coach AI set trigger | PASS | not reached | HALLISEUM |
| Coach Card on Optoma | PASS | not reached | HALLISEUM |
| Coach TTS | PASS | not reached | HALLISEUM |
| Voice follow-up recognition | FAIL | not reached | HALLISEUM |
| Coach Card / Cheat Sheet no stacking | partially proven; club sheet unavailable | not reached | HALLISEUM |
| Display friendly names/routing | PASS historically | OPEN | STATIC + HALLISEUM |
| Update button version comparison | PASS historically | cloud feed had duplicate-manifest issue | STATIC + cloud validation |
| Package SHA-256 | PASS for releases | PASS | automated |
| app_version/config.default version match | PASS | PASS | automated |
| ZIP integrity | PASS | PASS | automated |
| Rollback artifact available | YES | YES | automated |

## Mandatory pre-publish automated/static gate
1. Source tree clean and based on accepted baseline/branch.
2. Show exact changed-file list.
3. Parse `config.default.json`.
4. Verify `app_version.txt` and config Version match target version.
5. PowerShell parser/syntax validation for every `.ps1`.
6. Parse every embedded XAML block.
7. Check required worker files exist.
8. Check removed/deprecated workers are not reintroduced.
9. Compare critical navigation worker hash/diff to accepted baseline when change is unrelated.
10. Compare main Coach Mode launch sequence when change is unrelated.
11. Build ZIP reproducibly.
12. `zip.testzip()` or equivalent.
13. Calculate SHA-256.
14. Generate manifest from build metadata, not hand-edited version strings.
15. Installer self-extraction/integrity test.
16. Ensure updater preserves `config.json`, secrets, calibration/routing/user data.
17. Ensure stable manifest has one authoritative cloud copy.
18. Never update stable feed until Halliseum validation passes for affected hardware-dependent paths.

## Halliseum smoke test for every release
Even when a release "only changes Settings":
1. Start Factor Golf.
2. Start Coach Mode from GSPro closed.
3. Confirm GSPro opens normally.
4. Confirm Practice is selected automatically.
5. Confirm GS Pro Practice Range opens automatically.
6. Confirm connector minimizes.
7. Confirm SwingNerds is running.
8. Confirm no unwanted startup overlay.
9. End a short set and confirm Coach Card/TTS.
10. Confirm Settings opens/saves without overwriting calibration.
11. Check update/version display.

## Feature-specific gates
Club changes:
- calibrate selector;
- test current club;
- I once;
- K once;
- rapid multiple changes;
- repeat down at Lob Wedge boundary;
- repeat up at Driver boundary;
- no guessed/wrong card.

Voice:
- verify expected microphone/device;
- capture recognition engine/culture;
- log recognized phrase + confidence;
- normal conversational sentence;
- `back to golf`;
- low-volume test;
- false/noise rejection;
- repeated-turn follow-up.

## Stop rule
If any previously PASS core behavior becomes FAIL, stop release progression. Do not stack another patch until the regression is understood or the branch is reset to the accepted baseline.
