# Factor Golf Quick Coach Beta - DECISION / RELEASE LOG

## Product decisions
- Quick Coach is a **separate product** from Factor Golf Sim Control Center.
- Working name: **Factor Golf Quick Coach Beta**.
- Far-right foot pedal is the permanent Quick Coach trigger.
- Trigger key is **F18** so normal GSPro keyboard shortcuts are not reused.
- Quick Coach is intentionally lightweight and optimized for normal tournament/18-hole play.
- Golfer Experience and Persona mirror Factor Golf concepts, but Quick Coach must not depend on Factor Golf runtime code.
- Main Factor Golf accepted baseline must not be modified to fix Quick Coach.
- User should eventually install future Quick Coach releases with one in-app button rather than downloading and moving files manually.
- Natural conversational voice target: **gpt-realtime-2.1-mini**.
- Realtime voice transport and screenshot-analysis transport remain separate concerns.

## v0.1.0
Initial runnable prototype.
Included:
- WPF UI
- Rookie/Amateur/Pro-Advanced
- Persona selection
- F18 trigger
- screenshot capture
- OpenAI analysis
- Windows TTS
- temporary overlay

Real-machine result:
- API key appeared to save in UI but test reported that no API key was available.
- Rejected for continued use.

## v0.1.1
Attempted API-key persistence hotfix plus updater scaffolding.

Real-machine result:
- FAIL.
- Exact error:
  `Unable to find type [Security.Cryptography.ProtectedData]`
- Root cause: incorrect .NET DPAPI type reference in Quick Coach code.
- Do not patch forward blindly from this failure without preserving the exact diagnosis.

## v0.1.2
Current generated candidate.

Changes:
- Explicitly load System.Security.
- Use `System.Security.Cryptography.ProtectedData`.
- Use `System.Security.Cryptography.DataProtectionScope.CurrentUser`.
- Save API key, immediately decrypt it, and verify exact round trip before showing SAVED + VERIFIED.
- Keep screenshot-analysis request separate from planned Realtime Mini voice session.
- Preserve F18 trigger and Quick Coach-only config directory.

Validation completed off Halliseum:
- config JSON parse: PASS
- embedded XAML parse: PASS
- basic PowerShell delimiter/structure checks: PASS
- ZIP integrity: PASS
- exact DPAPI namespace correction present: PASS

Halliseum validation:
- OPEN

Release acceptance rule:
A candidate is not accepted simply because it builds. Halliseum-dependent items remain OPEN until actually tested on Josh's simulator PC.
