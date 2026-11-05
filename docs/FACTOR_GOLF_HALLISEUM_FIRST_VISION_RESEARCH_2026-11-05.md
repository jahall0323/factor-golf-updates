# Factor Golf Coach — Halliseum-first product vision and technical research

**Recorded:** 2026-11-05  
**Decision owner:** Josh  
**Status:** Research and product-direction checkpoint; **not** an implemented or tested release  
**Authoritative repository:** `jahall0323/factor-golf-updates`

## 1. Product decision (explicitly confirmed)

Factor Golf changes from a broad simulator control center into a **personal, Halliseum-specific AI golf coach**. The reference is GSCaddie's live GSPro shot tracking and performance history, with materially deeper interactive voice and optional synchronized swing-video coaching. This is initially for one user's existing simulator, **not** for sale or general launch-monitor compatibility. Consumer packaging may be reconsidered after the private build is stable.

**Owner involvement contract:** Josh supplies product vision, reviews the golf experience, and performs physical swings/real-world validation only when genuinely necessary. The engineering workflow must own code, architecture, research, automated tests, diagnostics and deployment automation to the extent its access permits. No repeated manual ZIP downloads, ad hoc screenshot capture, copied logs or speculative PC debugging as the normal workflow.

Do not convert the project into an unmaintainable collection of timing hacks in the name of convenience. Keep the original accepted v0.8.14 baseline immutable and Quick Coach isolated until a deliberate migration plan is verified.

## 2. Desired user experiences

### Live Coach
- Open Factor Golf beside an already running GSPro session; do **not** require launching or navigating GSPro to practice range.
- Automatically acquire each completed shot and its verified club as GSPro receives and/or persists it; show live shot feed on a secondary display.
- Support natural two-way spoken conversations with interruption and follow-up. Example: "How does that compare with my last five 7-irons?"
- Coach conservatively: results from ball flight do not by themselves prove body movement or specific swing faults.
- Optionally enable camera mode and request high-speed swing capture; video is automatically paired to the correct shot.
- Default to voice quietness while the golfer addresses the ball; avoid persistent speech distraction during on-course rounds.

### Structured practice
- Choose a club, start a **10-shot set**, automatically count actual verified shots, then produce a short **spoken** performance assessment, one actionable correction and an optional drill.
- Compare subsequent sets against prior sets and longitudinal club baseline; distinguish random mishits from recurring patterns.
- Handle wrong-club shots, putts, mulligans, duplicate log records, retries, interrupted sessions and missing data rather than silently contaminating the set.

### My Bag / mapping
- Track reliable carry and total distance **separately**, dispersion, start direction, flight, spin and available measured club data.
- Store date/time, shot source, context (range/course, club, lie, environment when available), data quality, shot/video link and confidence.
- Track *recent performance vs older personal baseline* so meaningful changes in actual distances are called out. Example: a 15-yard rise in 7-iron carry over two months.
- Recommend GSPro bag-distance review when demonstrated **current total distances** diverge from configured GSPro bag mapping; do not silently change GSPro's settings.
- Keep a visible reason for alerts: sample counts, date windows, old/new distributions, confidence and exclusion rules.

### Live Caddie
- While playing GSPro, advise club selection **from current personal distances and dispersion**, ideally given current lie, distance to target, wind, elevation and safe miss.
- Caddie should follow round transitions and player/shot events without requiring manual per-shot input.
- **Hard feasibility gate:** Confirm where reliable *pre-shot* hole/target/lie/conditions data comes from. The post-shot telemetry stream alone is insufficient to promise a real-time hazard-aware caddie.
- If required context is unavailable, do not invent hazard, wind or pin details; give a limited distance-only recommendation or say it is unavailable.
- Preserve normal tournament/round behavior: no shot spoofing, automatic gameplay input or alterations to GSPro.

### On-demand video coaching
- Two existing IFWATER high-FPS cameras; aim for face-on and down-the-line angles as the real-machine setup allows.
- Live preview, recording at the **actual negotiated** device FPS, slow-motion playback, swing comparison and targeted feedback.
- Use a **pre-trigger rolling ring buffer** and a shot event/impact timestamp so the backswing is retained even if a shot appears in GSPro only after ball flight finishes.
- Video timestamp-to-shot matching must be testable and explicit; do not guess which swing belongs to which shot.
- Assess observed positions/changes only when image quality, orientation, timing and visibility support them. Do not present estimated biomechanics as launch-monitor measurements.
- Keep short clips locally with configurable retention, capacity limits, and manual save; do not retain endless 120-FPS source video by default.
- Test device exclusivity/contention with SwingNerds; don't assume independent simultaneous access to the same USB camera.

## 3. Technical findings: verified documentation vs unknowns

### GSPro Open Connect V1: useful specification, **not a passive shot subscription**
Official source: https://gsprogolf.com/GSProConnectV1.html

- Documents socket `127.0.0.1:0921`.
- Launch monitor client **sends** shot data into GSPro; GSPro **responds** with status and player handedness/club info.
- Does **not** document a supported secondary listener subscribing to the Foresight/Bushnell connector's already received shot stream.
- Therefore **do not attempt port takeover, network interception/proxy, DLL hooks or replacing the official connector** as a shortcut.

### Passive local telemetry is promising but must be confirmed for Halliseum
GSCaddie's published description supports the technical feasibility of a passive companion reading shot logs, shot/round SQLite database and current-round working files generated in normal operation, with optional personal portal import; no claim that its private implementation or schemas are known.

Public documentation:
- https://gscaddie.com/
- https://gscaddie.com/terms/
- https://gscaddie.com/wiki/multiple-players/

Existing Factor Golf **v0.8.14 source already reads these potential sources**:
- `src/workers/Halliseum_Direct_Bridge_Hidden.ps1` monitors:
  - `%LOCALAPPDATA%\SwingNerdsClip\gspro_shots.log`
  - `C:\ProgramData\Foresight\FSS_SDK_MANAGED_LOG.txt`
  - `%USERPROFILE%\AppData\LocalLow\GSPro\GSPro\currentRound.dat`
- `src/workers/Halliseum_Coach_Set_API.ps1` reads `[LastShot #N] { ... }` JSON from the SwingNerds log, builds summaries and calls the AI Coach.
- `src/workers/Halliseum_Archive_Set.ps1` also parses the shot log.
- The bridge **copies/tails** data; it is not itself a proven shot-normalization and deduplication engine. Parsing depends on the SwingNerds log format and local availability.
- The isolated Quick Coach prototype (`quick-coach-beta/src/QuickCoach.ps1`) instead uses GSPro screenshot capture.
- **Not yet confirmed:** that the stated log files exist and update reliably in the current GSPro + Bushnell LPI installation, that player/club values are always correct, or that the local GSPro SQLite source is available/readable with stable schema.

**Engineering recommendation:** A single **read-only adapter** for each actually present source, normalized into an internal shot event schema and stored in a local SQLite database. Start by testing historical captured/local files and independently validating against GSPro CSV before implementing any live changes. Treat log polling, rotation, partial writes, retries, deduplication, restart recovery, player attribution, source precedence and crash-safe persistence as explicit QA cases. Never infer selected club by counting I/K pedal presses. Preserve source/provenance for every metric.

### GSPro bag mapping uses TOTAL distance
Official source: https://gspro.gitbook.io/gspro-knowledge-base/settings-main-menu/players-settings

- Manual bag yardages are documented as **TOTAL** yards, not carry.
- GSPro's built-in bag-mapping workflow generally asks for **5 shots per club** and allows removal of mishits.
- Factor Golf's **10-shot** coaching sets and richer trends are separate product features.
- Because carry/game carry/LM carry and total can differ, the product must label both and compare consistent metrics before suggesting a GSPro mapping update.

### Practice-range CSV provides a comparison oracle
Official source: https://gspro.gitbook.io/gspro-knowledge-base/practice-main-menu/practice-range

GSPro's Practice Range can export a shot-data CSV, usable for **validation** during development, not as the permanent live automation or a request for Josh to manually export after every session.

### GSCaddie feature reference
Source: https://gscaddie.com/

GSCaddie documents live session tracking, round and range history, per-club dispersion/gapping, session comparisons, strokes gained, drills, and mobile/second-screen access. These validate *product utility* rather than implying those particular GSPro data fields will be available locally to Factor Golf. Use original implementation and UX.

### Live voice technology
Official sources:
- https://developers.openai.com/api/docs/guides/audio
- https://developers.openai.com/api/docs/guides/realtime
- https://developers.openai.com/api/docs/guides/realtime-mcp
- https://developers.openai.com/api/docs/guides/voice-latency-cost
- https://developers.openai.com/api/docs/pricing

The current API offers **GPT-Live** for natural full-duplex voice with separate reasoning/tool delegation, and **Realtime API** for speech-to-speech, event-driven conversation and tool calling. Benchmark both against Halliseum hardware, microphone and actual golf-session usage. Realtime's tool calls can query Factor Golf's locally stored shot statistics; model output must not be its own authoritative data source.

Legacy System.Speech dictation in v0.8.14 repeatedly failed voice follow-up recognition; do not base the redesigned flagship interaction on unchanged legacy dictation.

**Cost/billing caution:** ChatGPT Pro and separate API usage are not the same thing. The official price sheet currently lists GPT-Live 1 at **$0.05/minute** of *session duration*, plus separately charged backend work. Active silence counts. Keep clear session controls, automatic idle closure, budget ceilings, usage display and explicit microphone state. Review rates again before implementation.

### On-course context
GSPro UI shows lie, distance, data tiles and rangefinder, but that **does not establish** an authorized structured data feed for *current pre-shot conditions*:
- https://gspro.gitbook.io/gspro-knowledge-base/in-game-information/in-game-user-interface
- https://gspro.gitbook.io/gspro-knowledge-base/in-game-information/data-tiles

Test local round records first. Only use a **bounded, optional visual fallback** for genuinely unavailable on-screen pre-shot facts if necessary, rather than making OCR the shot-data source. Hazard-aware, wind/elevation aware and exact-target caddie features remain **conditional**.

## 4. Architectural sketch (proposed, not implementation)

```
GSPro + Bushnell/Foresight (unmodified)
          |
      passive read-only adapters <--- SwingNerds data (if useful)
          |
    normalized shot-event pipeline
    / player + session + club identity / deduplication / provenance
          |
       local SQLite (offline-first)
          |
  +-------+----------------+-----------------------+
  |       |                |                       |
Live Feed 10-Shot Coach   Bag/Progression         Caddie (gated on course context)
          |                |
  Realtime/Live voice      Club distance history
          |
  On-demand dual-camera ring buffers -> shot-linked clips
          |
  Video findings (observed vs inferred) -> contextual coaching
```

The local collection and storage system must remain useful if cloud AI is temporarily unavailable. The voice agent reads verified data through narrowly scoped tool functions; it does not control GSPro or fabricate metrics. Use one recorder and one presentation/overlay owner, with explicit application state, not competing invisible workers.

## 5. Prioritized engineering phases and objective gates

**Phase 0: Research and source audit (this checkpoint).** Preserve `src/` accepted v0.8.14, rejected 0.8.15 evidence, Quick Coach separation. Establish an explicit Halliseum-only target and technical unknowns. No application code touched.

**Phase 1: Shot truth, offline first.** Inspect historical available diagnostics and read-only local data samples; compare shot counts, club, timestamps and key metrics with trusted GSPro exports. Build an adapter contract, replay fixture, deduplication tests and disconnected/restart recovery. **Exit:** consecutive shots attributed accurately, no spurious duplicates, provenance/absences visible. Never claim live PASS until the Halliseum validates.

**Phase 2: Live Coach + 10-shot sets.** Compact secondary-display UI, shot counter and spoken feedback. Real conversation with interruption, persistent only-verified context, idle closure and cost control. **Exit:** a complete session flows from shot -> saved metrics -> voice explanation, with correct club attribution and no manual exports.

**Phase 3: Personal bag + progression.** Full-swing classifier with reviewable exclusions; per-club carry/total medians, dispersion, sample count, timeframe and quality. Detect robust distance changes using comparable conditions and sufficient samples; distinguish *statistical improvement* from temporary anomalies. **Exit:** explainable old-vs-new 15-yard gain notification and a justified GSPro TOTAL-yardage mapping mismatch warning, without automatically editing GSPro.

**Phase 4: On-demand high-speed camera.** Read-only capability enumeration and device negotiation, pre-buffer capture, shot/video association, slow motion, observed-versus-inferred analysis, clip retention controls. **Exit:** one real shot reliably produces the correct video and grounded voice conversation, without degrading GSPro or SwingNerds.

**Phase 5: Live Caddie.** First prove real-time active-player/lie/target context. Then match target distance to current reliable carry/total, dispersion and landing risk. **Exit:** a real on-course recommendation with stated data sources and clear confidence, and no unsupported claims about hazards or green contours.

**Phase 6: Optional later commercial planning.** Only by new explicit decision from Josh; no current effort.

## 6. Acceptance and safeguards

- Halliseum hardware target: existing GSPro installation, Bushnell Launch Pro LPi, 2 high-FPS IFWATER USB cameras, SwingNerds, multiple local displays and foot pedal, on the dedicated simulator Windows PC.
- Never overwrite or patch official GSPro/Foresight executables or course assets; avoid proprietary schema circumvention, interception, or code injection.
- No API keys, personal gameplay logs, swing video, audio/transcripts, camera frames, secrets or private configuration should be committed to **this public GitHub repository**. Prefer synthetic fixtures and redacted diagnostics.
- Treat missing/unmeasured numbers as unknown, not zeros. Separate directly measured launch monitor facts, GSPro-calculated/game results, third-party camera-derived estimates and model inferences.
- Formal tests for restarted GSPro, restart/reconnect, simultaneous camera ownership, delayed event notifications, multiple players, clock offsets, repeated shots/mulligans, putting, chip shots and unexpected error states.
- Automated tests and code review before candidate packaging; final hardware validation at the Halliseum; no promotion of a previously failed build.
- Continue honoring prior accepted v0.8.14 behavior **until** an intentional replacement is accepted; keep a rollback path.
- Avoid replacing a stable component merely to create a 'modern' tech stack. Assess a maintainable Windows local service and UI architecture when implementation begins.

## 7. Unresolved questions that engineering must solve without dumping routine work on Josh

1. What unprotected local shot/round sources exist on the **current** Halliseum GSPro and BLP installations, and which fields/players/club IDs are dependable?
2. Is the SwingNerds log continuously available without SwingNerds UI needing to stay running, and does any newer GSPro local database expose more reliable shot history?
3. What lawful/approved pre-shot course, target, distance, wind, lie and elevation context can Factor Golf acquire without intrusive screen automation?
4. What resolutions, frame rates, pixel formats, timestamps and simultaneous device-open semantics do Josh's exact two cameras support on his existing USB controllers?
5. What is the minimum useful video representation (full clip + selected keyframes) for accurate swing analysis? Must measure inference accuracy instead of believing plausible coaching prose.
6. How will voice audio avoid TTS echo, false starts, conversations while addressing the ball, long idle billing and failure when the network drops?
7. What local retention limit protects SSD free space without sacrificing meaningful historical stats?
8. How will GSPro configured bag-total distances be read accurately? Do not automatically modify GSPro configuration merely to synchronize Factor Golf.

## 8. Honest status at this checkpoint

**Completed:** Read-only inspection of the authoritative GitHub repo, original shot-data parser, direct bridge, and Quick Coach screenshot design; research of GSPro Open Connect, GSPro range CSV and mapping documentation, GSCaddie product/public policy descriptions, and current voice API documentation.

**Not performed:** No live Halliseum connection, no testing of actual camera feeds or microphone, no real shot-data verification, no new application code, no deployment or release, and no claim that the private technical feasibility gates are already passed.

**Next implementation entry point:** Re-read current project state and this record; retain baseline; inspect candidate telemetry sources and add a **read-only replay/verification test harness** without touching GSPro or requiring Josh to collect files by hand.
