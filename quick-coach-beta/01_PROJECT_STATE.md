# Factor Golf Quick Coach Beta - PROJECT STATE

Checkpoint: 2026-10-05

## Purpose
A lightweight, standalone on-course AI golf coach for GSPro. Josh plays a normal round, presses the far-right foot pedal after a shot, Quick Coach inspects the full visible GSPro screen, and returns concise spoken feedback.

## Product separation
Quick Coach is separate from Factor Golf Sim Control Center. Do not modify the main Factor Golf baseline to fix Quick Coach.

## Required user experience
- Far-right pedal trigger: **F18**.
- Capture the full visible GSPro window after shot data is displayed.
- Short useful coaching, not a long lesson.
- Golfer Experience: Rookie / Amateur / Pro-Advanced.
- Persona: Professional-Clean / Golf Buddy / One of the Boys / Hood Golf / Extreme.
- Spoken feedback.
- Future natural two-way conversation.
- Future accepted releases update in place from the app.

## Golf/data truth
- Bushnell Launch Pro uses a one-dot club marker.
- Never claim a metric is measured unless it is actually visible/readable or comes from an authoritative source.
- Ball flight can show what happened without proving why.
- Inferences must be labeled likely/possible/suggested.

## Current candidate
**v0.1.4 - OPEN / current Halliseum candidate**

### Why v0.1.3 replaced v0.1.2 before Halliseum testing
Source inspection found a malformed v0.1.2 startup/config migration block. That candidate should not be tested or promoted.

### v0.1.3 candidate changes
- Corrected the malformed startup/config block.
- Keeps Windows DPAPI API-key protection using System.Security.Cryptography.ProtectedData.
- Saves the key and immediately decrypts/read-backs it before claiming SAVED + VERIFIED.
- Screenshot analysis model: **gpt-6-luna** through the Responses API.
- Screenshot request uses reasoning effort none for lower latency.
- Natural conversation target remains **gpt-realtime-2.1-mini** through a future Realtime API connection.
- Better API error reporting and a persisted last API response diagnostic.
- Hides Quick Coach before the manual screenshot test so the app does not photograph itself over GSPro.
- F18 remains the far-right pedal trigger.
- Introduces a stable install location under %LOCALAPPDATA%\FactorGolfQuickCoach\App.
- Adds a one-time installer that preserves existing Quick Coach settings/API key and creates a desktop shortcut.
- Future updater design uses an isolated GitHub per-file manifest with SHA-256 verification rather than moving ZIPs manually.

### Off-Halliseum validation completed for v0.1.3
- config.default.json parse: PASS
- embedded WPF/XAML parse: PASS
- targeted regression assertions: PASS
- delimiter/structure sanity checks: PASS
- ZIP integrity: PASS
- Windows/GSPro/OpenAI runtime validation: OPEN

## Known history
### v0.1.0
API key appeared to save but test reported no saved API key. Rejected.

### v0.1.1
Halliseum exact error:
`Unable to find type [Security.Cryptography.ProtectedData]`
Root cause: incorrect .NET DPAPI type reference. Rejected.

### v0.1.2
Corrected DPAPI namespace, but later source inspection found a separate malformed startup/config block before Halliseum validation. Superseded by v0.1.3.

## Highest-priority next actions
1. Bootstrap-install v0.1.3 on Halliseum.
2. Save API key and confirm SAVED + VERIFIED.
3. Run TEST SCREENSHOT + COACH with GSPro visible.
4. Inspect OPEN LAST SCREENSHOT if capture is wrong.
5. Hit one real shot, wait for GSPro result data, tap F18 once.
6. Confirm one press causes one response and spoken feedback.
7. After those pass, finish/publish the accepted one-click updater feed.
8. Only then add Realtime Mini two-way voice.


## 2026-10-05 Halliseum evidence from v0.1.3
Confirmed:
- API key secure save/read-back works.
- Quick Coach captured GSPro at 1920x1080.
- OpenAI request completed and returned coaching text.
- The captured image was a valid GSPro projector image.

Failure:
- Quick Coach main UI disappeared.
- Windows TTS began and was cut off almost immediately.

Root cause found in v0.1.3 source:
- coaching flow hid the modal main WPF window;
- F18 path never restored it;
- process/dialog lifetime could therefore end while asynchronous speech was still running.

## v0.1.4 current changes
- no main-window Hide() in coaching path;
- temporary opacity only during screen copy;
- config enumeration fix;
- readable checkbox text;
- clearer shot-note label;
- persistent Quick Coach window position;
- TTS completion/cancel/error logging;
- GSPro capture rectangle logging;
- EXPORT DIAGNOSTICS button that excludes the protected API-key file.

## Next Halliseum test
1. Install v0.1.4.
2. Keep GSPro full-screen on projector.
3. Keep Quick Coach on Sceptre.
4. Hit one shot and wait for result data.
5. Tap F18 once.
6. Confirm UI stays alive, response returns, full speech completes, popup behavior is normal.
7. If any failure occurs, use EXPORT DIAGNOSTICS and upload the ZIP.
