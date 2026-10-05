# Halliseum integration candidate 1

Built from accepted v0.8.14, rollback PR #2, club PR #3 and voice PR #4. Exact input commits are in INTEGRATION_INPUTS.json. All inherited source bytes match those PR heads; only the navigation hooks and two new diagnostic helpers differ. No release or stable-feed mutation is part of this workflow.

The normal app version remains 0.8.14 for compatibility with its numeric version comparison. The package adds candidate_build.json containing the distinct candidate ID, full source commit, input commits and hashes of every source file. Navigation run.json records this build manifest plus fresh hashes of the running launcher/navigator/diagnostic code. Installer identifies the candidate, even though the app title remains v0.8.14.

## Navigation invariants

The automated token-equivalence test removes only explicitly marked FGDIAG blocks and requires every remaining PowerShell token to match the immutable accepted navigator. Click positions, sleeps, timeouts, retry counts, fallback order, calibration, focus calls, DPI context and success criteria remain unchanged. Main launcher, calibration and display helper bytes are unchanged.

Hooks record status and click-request/release or UI Automation action events, with an ordered sequence, UTC timestamp, foreground handle/PID/title, target-window handle/title, reported GetWindowRect bounds, physical DWM visible bounds, target DPI and caller/target DPI awareness. DWM visible bounds exclude invisible resize borders; they are evidence, not replacement navigation coordinates.

A separate bounded recorder captures GSPro window screenshots every two seconds and after observed event changes (maximum 160 images), polling foreground changes every 250ms. Only the recorder temporarily enters a physical per-monitor-aware context for screen capture and restores it in a finally block. No diagnostic path issues input or changes foreground focus. Screenshots are asynchronous: capture timestamps and the latest observed event count show their timing. Disk/process overhead exists; token equivalence is not a claim of zero timing impact.

The recorder retains changed navigation, launch, club, coach and voice files for 15 minutes. It ignores stale runtime files from before this run and never copies config.json, secrets, API keys or the whole desktop. Runtime evidence stays local under diagnostics/navigation/<run ID> and is copied to the configured Drive root at UltimateCoach/Diagnostics/<run ID>. The original mutable status files remain available. If Drive is unavailable, local evidence remains. Recorder failures are recorded where possible and do not change navigation success/failure. Run IDs prevent later launches from replacing older evidence.

## Installation and packaging

Deterministic ZIPs use sorted paths and fixed timestamps. The outer ZIP contains a verified updater bootstrap, a hash-checked application payload, a manifest, installation CMD/PS1 and the short validation guide. It does not contain private runtime state. The bootstrap is the exact PR #2 updater, including rollback protection, so even a currently installed v0.8.15 uses the repaired updater for this test. The wrapper verifies every installed payload file (version marker by normalized value because the updater writes its own line ending). Existing settings, secrets and unrelated learned data are preserved by the tested updater. No network download or update feed is needed for installation.

Windows CI tests the actual packaged wrapper and payload in isolated paths containing spaces, from accepted and rejected version markers, then reinstalls. It checks preserved settings/calibration/routing/secrets/learned fixtures and verifies payload/bootstrap tampering is rejected before changes. Launch/process side effects are intercepted; this is not hardware or live desktop-launch acceptance. The original 11 install/update regressions and rollback assertion remain intact.

The candidate artifact job depends on all regression jobs succeeding. No release API or stable manifest write is present. Halliseum acceptance remains open until the user's four-part run is complete; a runtime regression blocks promotion.

API references:
- https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getwindowrect
- https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setthreaddpiawarenesscontext
