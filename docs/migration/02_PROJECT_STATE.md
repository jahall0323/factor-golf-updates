# FACTOR GOLF SOFTWARE - PROJECT STATE
Checkpoint: 2026-10-04

## Product
- Brand: **Factor Golf**
- App: **Factor Golf Sim Control Center**
- Legacy internal compatibility name: Halliseum Control Center
- Owner/tester: Big Daddy
- Halliseum = user's home simulator and final real-machine validation environment.

## Migration version truth
- **Current user-machine build at last report:** v0.8.15, installed for testing.
- **v0.8.15 status:** REJECTED. First test failed automatic Coach Mode range navigation.
- **Accepted migration baseline:** v0.8.14.
- **Cloud stable feed:** intentionally rolled back to v0.8.14 during migration cleanup.
- **v0.8.15 cloud ZIP:** retained but renamed `REJECTED_Factor_Golf_Sim_Control_Center_v0_8_15.zip`.
- Duplicate cloud `latest.json` created during earlier release work was deleted. Canonical manifest is the original `latest.json`.

## v0.8.14 real-machine result
PASS:
- Coach Mode navigated GSPro to `Practice -> GS Pro Practice Range`.
- No Club Cheat Sheet popped at range startup.
- User hit 3-4 balls.
- Ending the set triggered AI Coach.
- Coach feedback card appeared on the GSPro/projector display.
- Spoken coach feedback played.
- Coach card dismissed normally.
- Club Selector calibration button worked and the user's selector click was saved.

OPEN/FAIL:
- Club Cheat Sheets still did not appear from manual club changes.
- `TEST CLUB DETECTION` returned no visible club/result.
- Voice follow-up conversation repeatedly failed. Every spoken reply was treated as low-confidence and runtime showed:
  `I did not catch that clearly. Try again, or say back to golf.`
- The app uses Windows `System.Speech.Recognition` on the default audio device for this follow-up path, with `VoiceRecognitionMinConfidence` default 0.48.

## v0.8.15 real-machine result
- Built to expose Club Detection Test results and tighten focused selector OCR.
- Only source changes versus v0.8.14 were:
  - `workers/Halliseum_Club_Cheat_Watcher.ps1`
  - `workers/Halliseum_Settings.ps1`
  - version/default-config markers.
- On first test, Coach Mode failed to perform the previously working automatic range navigation.
- Because an unrelated confirmed behavior regressed, v0.8.15 is not accepted as a baseline.
- Root cause of that navigation regression has NOT been proven. Do not invent one.

## Highest-priority open defects
1. Establish reproducible GitHub source/release workflow.
2. Explain and prevent the v0.8.15 range-navigation regression before reusing its changes.
3. Club selector truth:
   - pedal/key events are triggers only, never authoritative club identity;
   - calibration click save works in v0.8.14;
   - actual club read/test remains unproven.
4. Voice follow-up recognition:
   - coach TTS works;
   - user follow-up speech recognition does not;
   - instrument microphone/device, recognized text, confidence, engine failures, and consider replacing Windows speech recognition with a more reliable transcription path.
5. Build automated/static regression checks so Halliseum testing is final validation, not primary debugging.

## Confirmed simulator-specific behavior that must be preserved
- Bushnell Launch Pro with one-dot club marker.
- Right-handed fixed BLP position.
- GSPro route: `Practice -> GS Pro Practice Range`.
- Club controls:
  - `K` = Club Up
  - `I` = Club Down
- GSPro does not wrap beyond the end clubs. Repeated Club Down at Lob Wedge can leave GSPro on Lob Wedge.
- Therefore Factor Golf must never calculate displayed club identity from pedal-count alone.
- Real connector:
  - process `GSPconnect`
  - title `GSPro x Foresight Sports & Bushnell Golf v1.14`
- Connector minimization has previously passed and must remain preserved.
- Automatic startup Driver Cheat Sheet is intentionally disabled.
- Coach Card and Club Cheat Sheet must never stack over one another.

## Display routing baseline
Three displays:
- Pisichen 27" QHD touchscreen, EDID/friendly name `PX27SH`
- Sceptre K32
- Optoma projector, detected as `Optoma UHD`

User routing:
- Control Center/Home -> Sceptre K32
- Settings -> Sceptre K32
- Performance -> Sceptre K32
- GSPro -> AUTO / Optoma
- Club Cheat Sheets -> Optoma
- Coach feedback cards -> Optoma
- Touchscreen will eventually mirror Optoma, so no unique Factor Golf windows should depend on it.

## Halliseum hardware baseline relevant to software
- Bushnell Launch Pro
- Optoma UHZ35ST projector
- RTX 5070 Ti simulator PC
- Intel i7-8700K
- 32 GB RAM
- 2 IFWATER 120 FPS global-shutter cameras
- PCsensor triple USB foot pedal
- SwingNerds Vision
- GSPro + beta/course library
- FSX Play / FSX Pro / FSX Premier

## Current local app architecture
- App dir: `%LOCALAPPDATA%\HalliseumControlCenter`
- Main entry: `Halliseum_Control_Center.ps1`
- Launcher: `Halliseum_Control_Center.vbs`
- Local config: `config.json`
- Default config: `config.default.json`
- Version marker: `app_version.txt`
- Google Drive runtime root: `G:\My Drive\Halliseum Coach Bridge`
- Legacy names remain for compatibility. Do not mass-rename them during migration.

## Update architecture target
Target:
`Factor Golf -> HTTPS latest.json -> direct ZIP download -> SHA-256 verification -> staged install -> installed-version validation -> relaunch`

Requirements:
- direct HTTPS primary;
- provider-neutral manifest;
- local Google Drive update folder fallback/dev archive only;
- preserve config, secrets, calibration, display routing, user data;
- preserve v0.7.7 anti-repeat-loop behavior;
- surface useful source/error information.

Planned public GitHub repository:
`jahall0323/factor-golf-updates`

At this checkpoint the GitHub account is connected, but no repository is visible to the connector yet. Repository creation remains the only manual GitHub bootstrap step.

## Release freeze
Do not publish another release until the migration checklist and regression matrix are in place.
