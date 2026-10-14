FACTOR GOLF - HALLISEUM INTEGRATION CANDIDATE 1
Accepted base: v0.8.14. Private test candidate, not an accepted release.

INSTALL (ON THE SIMULATOR PC)
1. Close GSPro, download this ZIP and choose Extract All.
2. Open the extracted folder and double-click INSTALL_CANDIDATE.cmd.
   Factor Golf's own processes close, files are hash-checked, a rollback
   snapshot is made, and Factor Golf reopens. Settings, API key, calibration,
   display routing and learned data stay in place. No administrator required.
   The normal app title still says v0.8.14; the installer identifies Candidate 1.
   Do not use CHECK FOR UPDATE to install this candidate.

ONE SHORT TEST (WITHIN 15 MINUTES OF STARTING COACH MODE)
1. Start COACH MODE with GSPro closed. Let automatic navigation finish.
   Confirm Practice -> Practice Range, connector minimized, SwingNerds running,
   and no startup Driver card. If navigation stalls, wait until Factor Golf
   reports failure before opening the range manually to finish the other tests.
   Do not recalibrate during this first run.
2. On the range, open Settings and click TEST CLUB DETECTION. Compare its
   visible result with GSPro's actual club. Close Settings. Press I once,
   then K once, allowing each to settle. Only the actual club may get a card.
   At Lob Wedge, press I again: the club/card must not drift.
3. Hit 3-4 shots with one club. Click END SET & COACH ME (or the usual pedal).
   Confirm the Coach Card is on the projector, spoken feedback works and
   Coach/Card and Club Sheet do not stack.
4. After the coach finishes speaking, ask "What should I focus on next?"
   Listen for the answer, then say "back to golf". Confirm control returns.

SEND BACK JUST: Navigation / Club / Coach / Voice: PASS or what failed.
No manual screenshots or uploads should be needed. Evidence is captured
locally under %LOCALAPPDATA%\HalliseumControlCenter\diagnostics\navigation,
then copied into your configured Drive root under
UltimateCoach\Diagnostics\<run ID>. Keep Drive running for sync.
Screenshots are limited to GSPro's window (including anything over it).
The recorder observes navigation and collects changed diagnostic/status files
for 15 minutes; then it stops. It never clicks or changes window focus.
Local evidence remains available if Drive is temporarily unavailable.

NAVIGATION NOTE
Navigation coordinates, retry counts, sleeps and success criteria are unchanged.
Diagnostic file writes and a separate observer add some overhead; this is
instrumented behavior, not proof of a zero-timing-impact run. Screenshot times
are recorded separately from exact click-event times. Frames may show a later
state; they are not represented as synchronous pre-click images.

LIMITS / RECOVERY
Automated checks cannot prove GSPro behavior, club OCR or microphone accuracy.
A clear club-detection failure is useful evidence, not a successful club read.
Rollback on failed copying is automatic. The previous app-owned snapshot is at
%LOCALAPPDATA%\FactorGolfUpdater\Backups (the exact path is in update.log).
If this test regresses anything, stop using the candidate and report it; do not
publish/promote it. No release, stable manifest or cloud update feed is changed.
