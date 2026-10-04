# FACTOR GOLF SIM CONTROL CENTER - DECISION & RELEASE LOG

Append-only history. Do not erase older decisions. Add newer entries when behavior changes.

## 2026-10-03 - Persistent project state is mandatory
A long build chat reached its limit and the next chat did not receive the full transcript.

Decision:
Conversation continuity is not project memory.
Drive Project State + release files are canonical.

## 2026-10-03 - Built-in updater is the normal release path
Normal releases use:
`G:\My Drive\Halliseum Coach Bridge\Updates`

The user updates from the app's top-right update button.
Manual ZIP/BAT install is fallback/recovery only.

## 2026-10-03 - Personalization layers are separate
- Golfer Experience = assumed golf knowledge, fundamentals taught, explanation depth, performance expectations.
- Persona = tone/personality/language style.
- Voice = TTS voice.

Golf truth must not change across these layers.

## 2026-10-03 - Hood Golf persona
Add `Hood Golf`.
Use strong natural AAVE-style phrasing/slang with the useful/direct One of the Boys foundation.
Keep it readable and natural, not caricatured.
No racial slurs or racial stereotypes.

## 2026-10-03 - Golfer Experience must affect actual teaching
Rookie teaches fundamentals when relevant.
Amateur assumes fundamentals and coaches consistency/cause/effect.
Pro / Advanced assumes strong fundamentals and coaches precision/optimization.

This is not just vocabulary substitution.

## 2026-10-03 - Preview Coach uses whole personalization stack
The old voice test was inadequate because it could say the same lesson regardless of experience.

Decision:
`Golfer Experience + Persona + Voice -> PREVIEW COACH`

## 2026-10-03 - Selected-state UI rule
User reported unreadable selected states.

Decision:
- keep normal background when selected;
- selected font becomes gold;
- optional subtle gold border;
- no light selected fill that destroys contrast.

Also fix clipped update-button text.

## 2026-10-03 - Official product naming
Main brand: **Factor Golf**
App: **Factor Golf Sim Control Center**

Halliseum becomes a legacy/internal compatibility name.

## RELEASE LEDGER
- v0.4.2 - API Fix
- v0.4.3 - API Input Fix
- v0.4.4 - UTF-8 API Fix
- v0.4.5 - Card API Fix
- v0.5.0 - Visual Coach
- v0.5.1 - Hotfix
- v0.6.0 - Illustrated/Golf Illustration Coach
- v0.6.1 - Club Cheat Sheet
- v0.7.0 - Functionality Foundation
- v0.7.1 - Static Home Hotfix
- v0.7.2 - Contrast / Encoding Hotfix
- v0.7.3 - Voice / Persona / Profile Hotfix
- v0.7.4 - Mode / Minimize Hotfix
- v0.7.5 - UI Visibility Audit Hotfix
- v0.7.6 - Extreme Persona Hotfix
- v0.7.7 - Updater Version Fix
- v0.7.8 - Coaching Levels
- v0.7.9 - Hood Golf + Experience-Based Coaching
- v0.8.0 - Factor Golf Sim Control Center

### v0.7.7 - Updater Version Fix
Preserve:
- updater-managed `app_version.txt`;
- installed-version validation before relaunch;
- real installed version in title;
- repeating-update-loop fix.

### v0.7.9 - Hood Golf + Experience-Based Coaching
Added Hood Golf and upgraded experience levels from wording-only to true experience assumptions.

### v0.8.0 - Factor Golf Sim Control Center
Published: 2026-10-03

Package:
`Factor_Golf_Sim_Control_Center_v0_8_0.zip`

SHA-256:
`16cba91f742dfd03ebe7e2afd1ded27725ee464fbfe30604a73ed4514945ac96`

Changes:
- First Factor Golf-branded release.
- Main brand `Factor Golf`; app `Factor Golf Sim Control Center`.
- User-facing `Coaching Level` renamed `Golfer Experience`.
- `PREVIEW COACH` combines Golfer Experience + Persona + Voice.
- Preview teaching materially changes for Rookie, Amateur and Pro / Advanced.
- Hood Golf preserved.
- Club Cheat Sheet experience adaptation preserved.
- Performance selected tabs/list/grid keep dark backgrounds and use gold selected text.
- Settings dropdown selections use gold selected text on dark background.
- Top-right update button widened to avoid `INSTALL vX.X.X UPDATE` clipping.
- User-facing API-key/update/coach/performance/settings branding updated.
- Legacy internal Halliseum filenames and Drive paths retained for compatibility.
- Existing Halliseum shortcut name migrates to `Factor Golf Sim Control Center.lnk` when encountered.
- v0.7.7 updater version-marker behavior preserved.

Validation:
- 8 embedded XAML blocks parse successfully.
- Version markers = 0.8.0.
- Preview passes Golfer Experience.
- Experience branches are distinct.
- Package hash verified before manifest publish.

Installation state at checkpoint:
- Last confirmed installed version remains v0.7.7.
- v0.8.0 is published but installation has not yet been confirmed.

## NEXT LOG ENTRY
After v0.8.0 installation, append:
- install success/failure;
- title/version result;
- branding result;
- updater-button clipping result;
- Performance selected-state result;
- Golfer Experience / Preview Coach test result;
- Hood Golf test result;
- persistence test;
- exact next build target.


## 2026-10-03 - v0.8.1 is a stabilization release, not a finish-line release
User confirmed v0.8.0 is installed and exposed several important issues:
- Coach Mode does not reliably open/navigate GSPro to the Practice/Driving Range.
- Foresight/GSPro connector window does not reliably minimize.
- Club Cheat Sheet did not appear after ending a set and changing clubs with the pedal.
- App-wide contrast/readability is still inconsistent, especially Settings dropdowns.
- Performance explanatory copy needs to sound like golfer-facing guidance rather than database logic.

Decision:
v0.8.1 focuses on functional reliability and readability. Do not describe the product as close to 1.0 based on this pass.

## 2026-10-03 - AI Caddy is a planned core product feature
AI Caddy should appear in the UI now as a disabled / Coming Soon feature even though the full on-course implementation is deferred.

Long-term intent:
Use GSPro course/shot context plus Factor Golf's learned personal club distances, dispersion/miss tendencies, and recent form to give live strategy and club-selection advice. Hazard-aware examples are core to the concept. Putting/green-read guidance is desired but depends on proving a reliable data source before promising exact slope/break recommendations.

The existing Performance / My Bag learning system should become part of the AI Caddy data foundation.

## 2026-10-03 - Separate Factor Golf design project is the visual-design partner
User created a separate ChatGPT project called `Factor Golf logo` for logos, brand identity, graphic elements, icons, and polished UI concepts.

Decision:
- Factor Golf Sim Control Center project = engineering / software / behavior / integrations / technical UX.
- Factor Golf logo project = brand / graphics / visual design / marketing.
- Bridge the projects through shared handoff files/assets rather than assuming cross-project chat access.


### v0.8.1 - Stabilization
Published: 2026-10-04

Package:
`Factor_Golf_Sim_Control_Center_v0_8_1.zip`

SHA-256:
`46a8012030e17753cd353b38a15ae34965076792ca2ac7885cfe11732e63ff82`

Changes:
- Coach Mode range startup now tries UI Automation, then Windows OCR against the live GSPro window, then coordinate fallback.
- Adds range-navigation diagnostics.
- Connector minimizer now enumerates top-level windows, accepts preferred connector PID/path, recognizes VGPconnect/ForesightForm signatures, and logs discovered windows.
- Club Cheat Sheet watcher now observes GSPro I/K/U shortcuts while GSPro is foreground and can infer a club change before the next shot when GSPro UI exposure fails.
- Settings ComboBoxes use a full dark template with gold selected text.
- Performance Recommended Carry explanation rewritten.
- AI Caddy added to home as `COMING SOON`; no live caddie behavior yet.
- Putter Club Cheat Sheet reference added.
- v0.7.7 updater anti-loop behavior preserved.

Validation:
- 8 embedded XAML blocks XML-parse successfully.
- Version markers = 0.8.1.
- Static explicit text/background contrast audit found no explicit combination below 4.5:1.
- Package hash verified before update manifest publication.

Installation state:
- v0.8.0 is the last user-confirmed installed build.
- v0.8.1 is published and awaiting real-machine verification.

Next verification:
- Practice -> Practice Range startup;
- connector minimization;
- pre-shot pedal club-change Cheat Sheet;
- Settings dropdown visibility;
- broader visual pass.

## 2026-10-04 - v0.8.1 failed real-machine Coach Mode verification
Observed:
- connector did not minimize;
- GSPro did not navigate to the range;
- initial Driver Club Cheat Sheet did not appear;
- repeated club up/down pedal changes did not produce Cheat Sheets.

Confirmed controls:
- GSPro route: `Practice -> GS Pro Practice Range`
- K = Club Up
- I = Club Down

Decision:
Do not close these defects based on static validation. v0.8.2 must remove cross-feature startup dependencies and add worker-start diagnostics.

### v0.8.2 - Coach Mode Reliability Repair
Published: 2026-10-04

Package:
`Factor_Golf_Sim_Control_Center_v0_8_2.zip`

SHA-256:
`04a9c09957078266b45f4ff2a90cc9fcfe16f6ff79b9243cdedb602ed0dbb4d0`

Changes:
- core Coach Mode features re-enabled on upgrade from older builds;
- range, connector minimizer and Club Cheat Sheet workers start independently/immediately;
- exact `GS Pro Practice Range` navigation target added;
- blocking connector filesystem search removed from Coach Mode startup;
- Visual Golf / VGPconnect / ForesightForm connector targeting expanded;
- connector watch extended to 75 seconds;
- Club Cheat Sheet no longer waits on range navigation;
- initial Driver card is independent;
- K=Club Up / I=Club Down implemented explicitly;
- session current-club state updates on detected pedal changes;
- key polling tightened;
- worker start/failure logging added.

Installation state:
- v0.8.1 is last confirmed installed.
- v0.8.2 is published and awaiting simulator-PC verification.

## 2026-10-04 - v0.8.2 startup test exposed worker argument loss and wrong connector executable
Observed:
- GSPro opened but did not navigate to Practice -> GS Pro Practice Range.
- `GSProConnectRestoreFiles.exe` was launched and displayed a restore/restart console.
- Test was stopped before further Cheat Sheet verification.

Root causes:
1. `Start-HiddenWorker` used `$args` as a named parameter. On the real machine, worker launch diagnostics showed every worker's arguments as blank. The hidden workers therefore did not receive required Root/AppDir/etc. parameters.
2. A previously auto-discovered connector path pointed to `GSProConnectRestoreFiles.exe`, which is a repair utility rather than the live connector.

### v0.8.3 - Worker Args + Connector Repair
Published: 2026-10-04

Package:
`Factor_Golf_Sim_Control_Center_v0_8_3.zip`

SHA-256:
`c5c0c143a177571a819e52c821fa5b0b15ece3da96d3961362f765a12be22eb2`

Changes:
- rename hidden-worker parameter `$args` -> `$workerArgs`;
- preserve and pass real worker command arguments;
- log `workerArgs=` for verification;
- reject restore/repair/setup/install/update/uninstall/patch executables as connector targets;
- auto-repair `GSProConnectRestoreFiles.exe` to sibling `GSProConnect.exe` when present;
- otherwise clear the bad connector path;
- stop a stale restore utility process when repairing the saved path;
- preserve v0.8.2 range, connector-minimizer and Club Cheat Sheet logic now that their parameters are actually passed.

Installation state:
- v0.8.2 is last confirmed installed.
- v0.8.3 is published and awaiting simulator-PC verification.

## 2026-10-04 - v0.8.3 real-machine test established multi-monitor calibration requirement
Observed:
- bad restore utility stayed gone;
- initial Driver Club Cheat Sheet appeared;
- connector minimizer successfully minimized `GSPconnect` / `GSPro x Foresight Sports & Bushnell Golf v1.14`;
- GSPro still did not navigate to the Practice Range;
- user did not hit balls during this test;
- user has three monitors and confirmed GSPro is on the projector while the Club Cheat Sheet appeared on the touchscreen.

Diagnostics:
- v0.8.3 worker arguments were correctly passed.
- GSPro exposed no useful UI Automation elements.
- OCR produced no useful navigation text.
- Factor Golf used saved coordinate fallback, but the generic saved coordinates did not match the actual GSPro UI.

Decision:
Make display routing configurable and calibrate the fallback clicks against the real GSPro window instead of the Windows desktop.

### v0.8.4 - Multi-Monitor Routing + GSPro Range Calibration
Published: 2026-10-04

Package:
`Factor_Golf_Sim_Control_Center_v0_8_4.zip`

SHA-256:
`ae65451b15c82b2c6438babb19dd615b36462b4f3575da123256a52c905e1d0c`

Changes:
- add Display & Screen Routing settings;
- route Control Center, Settings, Performance, Club Cheat Sheets, Coach cards and Coach controls to selected monitors;
- surface GSPro/projector display reference with Auto mode;
- add GSPro range calibration that records real Practice and GS Pro Practice Range clicks relative to the GSPro window;
- add Test Range Navigation button;
- record GSPro window/monitor info in diagnostics;
- block uncalibrated generic fallback clicks when UI Automation/OCR cannot navigate;
- preserve fresh calibration values when Settings is saved after calibration;
- preserve v0.8.3 connector and worker-launch repairs.

Installation state:
- v0.8.3 is last confirmed installed.
- v0.8.4 is published and awaiting calibration + simulator-PC verification.

## 2026-10-04 - Monitor identity must be hardware-driven, not numeric-order driven
User questioned whether Factor Golf's `Display 1 / Display 2 / Display 3` matched Windows Display Settings -> Identify and noticed the shown resolution did not appear to match the known 4K projector mode.

Decision:
- Stop presenting `.NET Screen.AllScreens` order as meaningful Windows display numbering.
- Prefer real monitor-friendly names from EDID/PnP/Windows.
- Show actual current display mode when possible instead of only DPI-scaled logical bounds.
- Add an in-app Identify Displays function.
- Persist stable display identities, with old indexes only as compatibility fallback.
- Rename `GSPro / projector` to `GSPro` because not every customer will use a projector.
- Keep `GSPro = AUTO (Recommended)` as the default. AUTO follows the actual live GSPro window; a specific monitor selection becomes an intentional override.

### v0.8.5 - Display Identification + Stable Monitor Routing
Published: 2026-10-04

Package:
`Factor_Golf_Sim_Control_Center_v0_8_5.zip`

SHA-256:
`5576490e05f40cdef140bf3b22d70afcb29910b06e092501440896ffd6b32ddb`

Changes:
- hardware-friendly monitor names in display-routing dropdowns;
- actual current display mode + Windows device ID shown as secondary context;
- Identify Displays overlay;
- stable physical-display keys for Factor Golf windows;
- legacy numeric index fallback retained;
- `GSPro / projector` renamed `GSPro`;
- GSPro AUTO clarified as recommended live-window-following behavior;
- manual GSPro display becomes an explicit move/maximize override;
- existing v0.8.4 GSPro range calibration preserved.

Installation state:
- v0.8.4 is last confirmed installed.
- v0.8.5 is published and awaiting real-machine display-identification verification.

## 2026-10-04 - Display dropdowns should hide low-level Windows DISPLAY IDs
User verified friendly names work in v0.8.5, but reported garbled-looking glyphs and questioned why customer-facing choices still showed Primary / DISPLAY2 / DISPLAY3.

Decision:
- Keep `Primary` because it is a meaningful Windows main-display status.
- Remove `DISPLAY1 / DISPLAY2 / DISPLAY3` from normal UI; retain them only in diagnostics.
- Use ASCII-only separators and resolution notation to avoid rendering/encoding artifacts.

### v0.8.6 - Display Label Cleanup
Published: 2026-10-04

Package:
`Factor_Golf_Sim_Control_Center_v0_8_6.zip`

SHA-256:
`b931a3d70254f11e09361b913ed8bd3914480722cad92474cced7379075057f0`

Changes:
- clean display labels: friendly hardware name + current resolution + optional Primary;
- remove low-level Windows DISPLAY IDs from customer-facing dropdowns;
- keep low-level IDs internally for diagnostics;
- clean Identify Displays overlay;
- remove Unicode bullet and multiplication symbols from display helper;
- preserve stable hardware routing keys and GSPro AUTO behavior.

Installation state:
- v0.8.5 is last confirmed installed.
- v0.8.6 is published and awaiting real-machine verification.


## 2026-10-04 - Coach Mode must navigate GSPro before visual overlays appear
Real-machine v0.8.6 test proved the saved GSPro range calibration works in the dedicated Test Range Navigation flow, but full Coach Mode still failed after reporting that saved clicks were sent. The initial Driver Club Cheat Sheet appeared over GSPro while startup navigation was still in progress.

Decision:
- treat a completed user calibration as the preferred navigation path on that machine;
- wait for the real GSPro window to be responsive/stable, then restore GSPro focus before each calibrated click;
- delay the initial Club Cheat Sheet until range startup finishes or reaches a bounded terminal failure state;
- remove floating Factor Golf Coach Controls completely because the Control Center, voice, and foot-pedal workflows make the extra window unnecessary and it creates another focus-stealing surface;
- prefer a matching Windows GSPro shortcut when available so normal beta/update shortcut behavior is not intentionally bypassed.

### v0.8.7 - Coach Mode Startup Sequence Fix
Published: 2026-10-04

Package:
`Factor_Golf_Sim_Control_Center_v0_8_7.zip`

SHA-256:
`042ba7cfd0bfde741dd5c0ddeb0e48a263dab86e868a00a6e6de01cf2da03a2c`

Changes:
- remove Coach Controls UI/worker/default settings;
- calibrated GSPro navigation runs before UIA/OCR when calibration exists;
- GSPro readiness uses actual process responsiveness/stable window state;
- re-focus GSPro before both saved clicks;
- hold initial Driver Cheat Sheet until range navigation is done, with a bounded timeout;
- prefer matching Windows GSPro shortcut with executable fallback;
- preserve working display routing and connector-minimization fixes.

Installation state:
- v0.8.6 is last confirmed installed and tested.
- v0.8.7 is published and awaiting real-machine Coach Mode verification.

## 2026-10-04 - Remove startup Driver Cheat Sheet entirely

v0.8.7 real-machine result:
- the Driver Club Cheat Sheet still appeared before GSPro finished automatic range navigation;
- full Coach Mode still failed to reliably reach the Practice Range.

Decision:
Do not attempt to delay or gate a default Driver card. Eliminate it. Driver remains the internal starting club, but Club Cheat Sheets appear only after a detected club change.

### v0.8.8 - No Startup Driver Cheat Sheet
Published: 2026-10-04

Package:
`Factor_Golf_Sim_Control_Center_v0_8_8.zip`

SHA-256:
`5151930bb834ed9cd67892722d0eea6f010dd9c99d1401a4224a26f3c5fa1018`

Changes:
- remove automatic startup Driver Club Cheat Sheet;
- remove startup Driver reminder from Settings;
- remove the setting from new defaults and strip it from upgraded configs;
- initialize the watcher silently to the current club / Driver;
- preserve club-change sheets, K/I mapping, reappear modes, range calibration, GSPro focus/navigation, connector minimization, display routing, GSPro update-friendly launch behavior, and updater protections.

Installation state:
- v0.8.7 is last confirmed installed and tested.
- v0.8.8 is published and awaiting real-machine Coach Mode verification.

# MIGRATION CHECKPOINT ADDENDUM - 2026-10-04

## v0.8.9
- Corrected self-contained installer succeeded after the first wrapper had a deterministic payload-marker bug.
- Direct-HTTPS updater foundation introduced, but public GitHub feed was not yet live.

## v0.8.10
- Automatic Coach Mode range navigation passed.
- Club Cheat Sheet identity could drift from GSPro because fallback inference counted pedal/key changes.

## v0.8.11
- Product rule established: pedal/key input is a change trigger only, never club identity.
- If club cannot be verified, show no Cheat Sheet rather than a wrong one.
- Coach Card and Club Cheat Sheet should share one presentation lane.
- A cold-start run reached Practice but missed the second Practice Range click.

## v0.8.12
- Practice submenu settle/retry logic added.
- Real-machine test: automatic navigation to Practice Range passed.
- No startup cheat sheet, as intended.
- AI Coach card path passed.
- Club Cheat Sheets did not appear because actual GSPro club verification failed.

## v0.8.13
- Added one-time GSPro Club Selector calibration and focused selector OCR.
- Calibration action initially failed silently because the worker path had poor diagnostics.

## v0.8.14
- Calibration worker made explicit/self-confirming.
- Real machine confirmed the selector click was saved.
- Club Detection Test produced no visible club/result.
- Voice follow-up recognition repeatedly returned low-confidence `I did not catch that clearly`.

## v0.8.15 - REJECTED
- Intended to expose Club Detection Test results and tighten 4K OCR sizing.
- Source diff against v0.8.14 touched only Club Cheat Watcher, Settings, and version/default markers.
- First real-machine run regressed automatic Coach Mode Practice Range navigation.
- Release rejected. Do not use it as the migration baseline.
- Root cause of the range-navigation regression remains unproven.

## Migration engineering decisions
- Accepted baseline = v0.8.14.
- Stable cloud manifest rolled back to v0.8.14.
- Cloud v0.8.15 artifact renamed with `REJECTED_` prefix.
- Duplicate cloud `latest.json` removed.
- Stop ZIP-to-ZIP patching as the normal development model.
- Establish one authoritative GitHub source repository before normal development resumes.
- Every release gets a regression gate before publication.
