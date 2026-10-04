# FACTOR GOLF SOFTWARE - PRODUCT REQUIREMENTS

## Product promise
Factor Golf should make the Halliseum feel like one intelligent system:
1. walk in and start it;
2. GSPro / launch monitor / SwingNerds connect automatically;
3. shots and swings are captured with minimal user interaction;
4. useful data is organized automatically;
5. AI Coach gives simple, accurate feedback;
6. voice / pedal control works naturally;
7. technology mostly stays out of the golfer's way.

## Golf truth
- User is a beginner golfer.
- Coaching normally identifies the single biggest recurring issue first.
- Explain simply, give one or two feels, let user hit more shots, then reassess.
- Analyze patterns across multiple shots instead of overreacting to one mishit.
- Separate recurring swing problems from random mishits, setup errors, launch-monitor errors, and normal variation.
- Bushnell Launch Pro uses one-dot club marker.
- Never represent inferred/calculated/estimated data as directly measured.
- Never diagnose from a metric the user's Launch Pro configuration cannot reliably provide.

## Coach personalization
Golfer Experience:
- Rookie
- Amateur
- Pro / Advanced

Persona:
- Professional / Clean
- Golf Buddy
- One of the Boys
- Hood Golf
- Extreme

Voice is separate from teaching level/persona.
Same evidence must produce the same core golf diagnosis regardless of style.

## Coach Mode
Required:
- launch/use normal GSPro beta/update path;
- find final live GSPro window;
- launch SwingNerds;
- launch/minimize the correct Foresight/Bushnell connector;
- automatically navigate `Practice -> GS Pro Practice Range`;
- capture shot/session data;
- trigger AI coaching;
- speak coaching when enabled;
- allow useful conversational follow-up;
- keep overlays from fighting each other.

## Club Cheat Sheets
- No default Driver card at startup.
- K = Club Up; I = Club Down.
- Input is only a signal that GSPro selection may have changed.
- Factor Golf must verify actual selected club before displaying the sheet.
- Repeated boundary presses must not drift internal club state.
- If club cannot be verified, show no card rather than a wrong card.
- Club Cheat Sheet and Coach Card may not stack.
- Experience level changes amount/depth of instruction, not golf truth.

## Display behavior
Current user layout:
- Control Center/Home -> Sceptre K32
- Settings -> Sceptre K32
- Performance -> Sceptre K32
- GSPro -> AUTO / Optoma
- Club Cheat Sheets -> Optoma
- Coach feedback -> Optoma

Customer-facing display labels:
- friendly hardware name;
- current resolution;
- optional `Primary`;
- do not expose low-level DISPLAY# unless diagnostic.

## Voice
- TTS coach feedback currently works.
- Follow-up recognition must be reliable enough for hands-free simulator use.
- App must expose useful microphone/recognition diagnostics when it cannot hear the user.
- Repeated generic `I did not catch that clearly` without diagnostic information is unacceptable.

## Updates
- One-click update from inside Factor Golf.
- Direct HTTPS primary.
- SHA-256 package verification mandatory.
- Preserve settings, secrets, routing, calibration, learned/user data.
- Validate installed version before relaunch.
- Do not create repeated update loops.
- Maintain rollback path.
- Stable feed must never point to a build already rejected by real-machine regression testing.

## Quality bar
A release is not accepted because it installs or passes syntax checks.
Acceptance requires:
- automated/static checks passed;
- relevant regression tests passed;
- Halliseum final validation for hardware/GSPro dependent behavior;
- known failures recorded;
- stable feed updated only after acceptance.
