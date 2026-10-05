# Factor Golf Quick Coach Beta - ARCHITECTURE

## Separation boundary
Quick Coach must not import, overwrite, or patch Factor Golf Sim Control Center runtime files.
Its state lives under:
`%LOCALAPPDATA%\FactorGolfQuickCoach`

Main Factor Golf state lives elsewhere and remains independent.

## Current flow
1. User plays normal GSPro.
2. Shot finishes and GSPro displays result/data.
3. User taps far-right PCsensor pedal mapped to F18.
4. Quick Coach finds the live GSPro window.
5. Quick Coach captures the full visible GSPro window.
6. Screenshot + coaching instructions are sent to the screenshot-analysis model.
7. Short feedback is returned.
8. Feedback is spoken and optionally displayed temporarily.
9. Quick Coach returns to idle.

## Current implementation style
Windows PowerShell + WPF prototype.

## Secrets
OpenAI API key:
- stored outside the install folder;
- protected for the current Windows user with DPAPI;
- must be immediately decrypted/read back after save;
- UI must not claim success unless round-trip verification succeeds;
- never commit API keys to GitHub or Google Drive.

## Screen capture
Current candidate captures pixels from the visible GSPro window rectangle.
Known limitation:
If another window covers GSPro, the captured pixels may include the covering window.
This is acceptable for the MVP test but should be improved later if necessary.

## AI paths
### Screenshot analysis
Normal image + text request/response path.
Purpose: inspect current GSPro result and produce concise coaching.

### Realtime conversation
Separate future Realtime API connection using gpt-realtime-2.1-mini.
Purpose:
- natural spoken coach response;
- microphone follow-up;
- interruptions / back-and-forth;
- automatic inactivity close;
- optional explicit return-to-golf command.

Do not implement realtime voice as repeated Windows Speech Recognition plus TTS if the Realtime API path is available and reliable.

## Update architecture target
Quick Coach:
`installed app -> HTTPS latest.json -> version compare -> ZIP download -> SHA-256 verify -> staged replacement -> relaunch`

Requirements:
- isolated Quick Coach manifest path;
- preserve API key and user settings;
- validate downloaded hash;
- do not overwrite user data;
- rollback-friendly package history;
- one-click user experience.
