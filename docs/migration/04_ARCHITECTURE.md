# FACTOR GOLF SOFTWARE - ARCHITECTURE

## Current implementation style
Factor Golf is currently a Windows PowerShell/WPF application with multiple worker scripts.

### Main process
`Halliseum_Control_Center.ps1`
- Home/Control Center UI
- mode launch orchestration
- app/process cleanup
- starts GSPro, SwingNerds and connector-related workers
- starts Coach Mode workers
- settings/status integration
- update entry point

`Halliseum_Control_Center.vbs`
- normal hidden-console launcher.

### Shared display layer
`workers/FactorGolf_Display_Helper.ps1`
- discovers physical monitors using Windows/EDID/PnP data;
- resolves stable display keys;
- routes Factor Golf windows;
- supports Identify Displays;
- GSPro normally uses AUTO to follow its live window.

### GSPro startup / navigation
`workers/Halliseum_Range_Nav.ps1`
- navigates main GSPro screen -> Practice -> GS Pro Practice Range;
- calibrated window-relative positions are important on this machine;
- v0.8.12 introduced stable-menu wait/retry behavior that passed on the Halliseum;
- regression gate must verify both clicks on every release.

`workers/Halliseum_Range_Calibration.ps1`
- records the user's actual Practice and Practice Range click positions relative to the GSPro window.

`workers/Halliseum_Focus_GSPro.ps1`
- focus/move/maximize helper.

### Foresight/Bushnell connector
`workers/Halliseum_Minimize_Connectors.ps1`
- detects/minimizes the actual connector.
- Known real connector: `GSPconnect`, window title `GSPro x Foresight Sports & Bushnell Golf v1.14`.
- Restore/repair/setup/update executables must not be treated as the live connector.

### Club Cheat Sheet pipeline
`workers/Halliseum_Club_Cheat_Watcher.ps1`
- monitors K/I/U-related club-change activity;
- must treat pedal/key presses as triggers only;
- attempts actual club verification;
- must not infer displayed club identity from click count.

`workers/Halliseum_Club_Selector_Calibration.ps1`
- captures club selector location relative to GSPro window.

`workers/Halliseum_Club_Cheat_Sheet.ps1`
- renders the club information overlay on the configured display.

Current rule:
- no automatic Driver sheet at startup;
- show a club sheet only after a verified real club change;
- wrong club is worse than no card.

### Coaching / shot pipeline
`workers/Halliseum_Direct_Bridge_Hidden.ps1`
- bridge/runtime shot-data path.

`workers/Halliseum_SwingNerds_UIA_Hidden.ps1`
- SwingNerds capture/integration helper.

`workers/Halliseum_Coach_Set_API.ps1`
- builds AI coaching request;
- calls coaching model;
- creates TTS;
- handles optional voice follow-up conversation;
- writes follow-up/runtime state.

`workers/Halliseum_Coach_Card.ps1`
- renders coach feedback overlay.

`workers/Halliseum_Archive_Set.ps1`
- archives completed set/session data.

### Performance / personalization
`workers/Halliseum_Performance.ps1`
- sessions / My Bag / learned performance views.

Settings concepts:
- Golfer Experience = teaching depth/assumed knowledge
- Persona = tone/language
- Voice = TTS voice
These never change golf truth.

### Settings
`workers/Halliseum_Settings.ps1`
- app settings
- display routing
- range calibration/test
- club selector calibration/test
- coach personalization
- update-related preferences

### Update system
`workers/Halliseum_Self_Update.ps1`
- v0.7.7 anti-loop installed-version behavior must remain.
- v0.8.9 added direct-HTTPS concepts.
- target is public HTTPS manifest + package SHA-256, with Drive fallback only.

## State locations
Local app:
`%LOCALAPPDATA%\HalliseumControlCenter`

Cloud/runtime legacy root:
`G:\My Drive\Halliseum Coach Bridge`

Important local persistence:
- `config.json`
- encrypted API key/secrets
- `app_version.txt`
- calibration settings
- display routing
- updater state/logs

Important runtime diagnostics historically include:
- `worker_launch_status.log`
- `range_nav_status.json`
- `range_nav_debug.json`
- `connector_minimize_status.json`
- `club_cheat_status.json`
- `club_detection_events.log`
- club selector calibration/test status
- coach runtime/follow-up state

## Known architecture risk areas
1. Several independent hidden PowerShell workers can compete for focus/timing.
2. Some status exists in both local app storage and Google Drive runtime storage.
3. UI/OCR automation is inherently fragile if used as authoritative state.
4. GSPro screen automation needs explicit state acknowledgement, not assumed click success.
5. Voice follow-up currently depends on Windows `System.Speech.Recognition` and default microphone selection.
6. Releases were historically created by modifying prior ZIPs. Migrate to one version-controlled source tree.

## Desired next architecture direction
- GitHub source of truth.
- Build/package script that produces reproducible ZIP.
- Automated static + regression checks.
- Explicit application event/state model where possible.
- One presentation/overlay manager.
- Authoritative club state source if safely obtainable from existing GSPro/Foresight connector.
- Structured voice input diagnostics and a more reliable transcription path if Windows speech is inadequate.
- Provider-neutral update endpoint.
