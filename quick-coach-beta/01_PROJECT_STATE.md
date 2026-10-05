# Factor Golf Quick Coach Beta - PROJECT STATE

Checkpoint: 2026-10-05

## Purpose
A lightweight, standalone on-course AI golf coach for GSPro. Josh can play a normal round, press the far-right foot pedal after a shot, let Quick Coach inspect the full visible GSPro screen, and receive concise spoken feedback.

## Required user experience
- No complicated dashboard.
- Runs separately from Factor Golf Sim Control Center.
- Far-right pedal triggers coaching.
- Current trigger key: **F18**.
- Capture the entire visible GSPro window after the shot result/data is shown.
- Give one short useful coaching takeaway rather than a full lesson.
- Respect Golfer Experience and Coach Persona selections.
- Spoken feedback.
- Future natural two-way follow-up conversation.
- Conversation should close automatically after inactivity or an explicit return-to-golf action.
- Future releases should install through an in-app one-click updater.

## Personalization
Golfer Experience:
- Rookie
- Amateur
- Pro / Advanced

Coach Persona:
- Professional / Clean
- Golf Buddy
- One of the Boys
- Hood Golf
- Extreme

Persona may change delivery but never golf truth.

## Golf/data truth
- Bushnell Launch Pro with one-dot club marker.
- Never claim a metric is measured unless it is actually visible/readable or obtained from an authoritative data source.
- Screenshot ball flight can show what happened without proving why.
- Inferences must be labeled as likely/possible/suggested, not measured fact.

## Current candidate
**v0.1.2 - OPEN / not Halliseum accepted**

Implemented in candidate:
- WPF Quick Coach window.
- Skill/persona selectors.
- F18 trigger polling.
- Full visible GSPro-window screenshot capture.
- OpenAI screenshot analysis path.
- Windows spoken-output fallback.
- Temporary feedback overlay.
- Protected API-key storage using Windows DPAPI.
- Save-time API-key read-back verification.
- UI button for future update checks.
- Separate config location under `%LOCALAPPDATA%\FactorGolfQuickCoach`.

## Known current test state
v0.1.0:
- UI launched.
- User entered API key.
- Test still reported no saved API key.

v0.1.1:
- UI launched.
- Halliseum exposed exact failure while saving key:
  `Unable to find type [Security.Cryptography.ProtectedData]`
- Root cause identified as incorrect .NET type qualification / assembly handling.

v0.1.2:
- Changed to `[System.Security.Cryptography.ProtectedData]`.
- Explicitly loads `System.Security`.
- JSON parse passed.
- Embedded XAML parse passed.
- Basic PowerShell structural checks passed.
- ZIP integrity passed.
- Halliseum runtime test is still OPEN.

## Voice architecture
Do not confuse screenshot analysis with realtime voice transport.
- Screenshot analysis is currently a normal request/response path.
- Natural two-way audio is planned through **gpt-realtime-2.1-mini** using the Realtime API.
- Do not merely substitute a realtime model name into the standard Responses request and call that realtime voice.

## Highest-priority next actions
1. Halliseum-test v0.1.2 API-key save and read-back.
2. Confirm TEST SCREENSHOT + COACH captures the correct GSPro window.
3. Confirm returned coaching text is useful and data-honest.
4. Confirm F18 triggers the same flow while GSPro is active.
5. Establish the Quick Coach one-click update feed as an isolated release channel.
6. Add Realtime Mini two-way voice only after the core capture/analyze path is stable.
