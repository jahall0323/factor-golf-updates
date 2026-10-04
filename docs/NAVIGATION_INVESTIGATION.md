# Navigation investigation — 2026-10-04

The three requested files were accessible directly through connected Drive in Halliseum Coach Bridge/UltimateCoach. JSON files were absent from keyword search results but present in the folder listing. No manual upload is necessary. Raw private logs are not copied into the public repository; this document records only relevant technical observations.

## Observed evidence
The available run starts at 12:41:41 local time. Range navigation and club watcher launch 32 ms apart, followed by the connector minimizer. Required Root and AppDir arguments are present. This does not reproduce the old missing-worker-arguments bug.

At 12:42:03, navigation diagnostics show calibrated=true and identical positions for both menu clicks: x=0.326562, y=0.734259. Window bounds and reported screen bounds are 1920x1080, with origin (-3840,0). These can reflect window/DPI coordinate reporting and do not establish actual projector signal resolution. UI Automation exposes no useful elements.

At 12:42:47, final status is calibration_needed with the generic automatic-navigation-did-not-complete message. The adjacent OCR dump contains PRACTICE but no recognized Practice Range tile. That dump is the most recent capture, not a complete frame-by-frame trace.

## Interpretation and limits
The worker ran, reached diagnostics and exhausted navigation methods. Saved duplicate coordinates and coordinate-space handling warrant investigation. Identical coordinates alone are not proof of invalid calibration; different screens can place tiles at the same location. The logs do not record app version, effective source hashes, click-by-click status history or foreground-window history, so their association with the rejected build is contextual, not proven from the files themselves.

v0.8.14 and v0.8.15 have identical navigation/main-launcher code and only the default Version value changed. The root cause remains unproven. Inspect calibration capture/debounce, preserved live config, window/DPI handling and worker focus interactions before attempting a fix. Preserve the baseline and do not ask for speculative rebuild testing.
