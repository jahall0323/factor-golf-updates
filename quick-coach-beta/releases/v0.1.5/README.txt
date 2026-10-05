FACTOR GOLF QUICK COACH BETA v0.1.5
======================================

BETA UPDATE-CHANNEL CANDIDATE

WHY v0.1.5
v0.1.4 fixed the v0.1.3 lifecycle defect, but Josh should not have to manually
download/install every candidate. v0.1.5 adds a proper Beta-channel updater
policy so the same desktop app can install dev/candidate/accepted Quick Coach
builds while refusing anything marked rejected.

INCLUDES v0.1.4 FIXES
- Removes main-window Hide() behavior from coaching.
- Keeps the Quick Coach process/window alive while F18 coaching runs.
- Temporarily makes the UI transparent only during the actual screenshot copy.
- Fixes config-load collection-modified warning.
- Logs exact GSPro screen coordinates.
- Adds TTS start/completion/cancel/error logging.
- Fixes dark checkbox text.
- Renames optional context to "Shot note for Coach (optional)".
- Remembers Quick Coach window position.
- Adds EXPORT DIAGNOSTICS without the protected API-key file.

UPDATER
- Product channel: beta
- Accepts release_status: dev, candidate, accepted
- Refuses release_status: rejected
- Downloads immutable per-version files from GitHub.
- Verifies SHA-256 for every downloaded file before replacing installed files.
- Preserves config/API key because user data lives outside the App directory.

TEST
After updating from the existing desktop app:
1. Confirm title/version says v0.1.5.
2. Keep GSPro full-screen on projector.
3. Keep Quick Coach on Sceptre.
4. Hit one shot.
5. Press F18 once.
6. Confirm Quick Coach stays alive, feedback returns, speech completes, popup behaves.
7. If anything fails, use EXPORT DIAGNOSTICS and upload the ZIP.

VOICE
Natural gpt-realtime-2.1-mini conversation remains the next feature after the
core lifecycle/capture/audio path passes Halliseum validation.