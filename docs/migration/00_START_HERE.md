# FACTOR GOLF SOFTWARE - START HERE

This folder is the migration handoff from the ChatGPT Project **Golf Coach and Home Golf Simulator Pro** into the dedicated software-engineering Project **Factor Golf Software**.

## Read order before changing code
1. `02_PROJECT_STATE.md`
2. `03_DECISION_RELEASE_LOG.md`
3. `04_ARCHITECTURE.md`
4. `05_PRODUCT_REQUIREMENTS.md`
5. `06_REGRESSION_TEST_MATRIX.md`
6. `07_GITHUB_AND_RELEASE_PLAN.md`
7. Inspect `source_baseline_v0.8.14/` or the matching baseline ZIP.
8. Inspect the rejected v0.8.15 diff before reusing any v0.8.15 change.

## Hard migration rule
Do **not** start a new release just because the version number 0.8.15 exists. v0.8.15 is rejected because the first real-machine test regressed automatic Practice Range navigation.

The accepted engineering baseline for the migration is **v0.8.14**.

v0.8.14 is not feature-complete. It is simply the safest current baseline because:
- automatic Coach Mode navigation to `Practice -> GS Pro Practice Range` passed;
- no startup Driver Cheat Sheet appeared;
- AI Coach feedback card worked;
- Club Selector calibration successfully saved the user's selector click;
- Club Detection Test still did not return a visible club result;
- voice follow-up recognition still repeatedly failed with `I did not catch that clearly`.

## First engineering objective in the new project
Do not immediately build v0.8.16.

First:
1. establish the GitHub source repository;
2. import v0.8.14 as the accepted baseline;
3. tag/mark v0.8.15 as rejected;
4. install a regression harness/checklist around the behaviors already proven on the Halliseum;
5. analyze the v0.8.14 -> v0.8.15 diff and the real-machine navigation regression;
6. only then implement the club-detection and voice fixes.

## Truth hierarchy
When sources disagree:
1. real-machine user test result;
2. checked-in source + reproducible build artifacts;
3. regression matrix / project state;
4. release notes;
5. conversation recollection.

Never promote an untested build to "good" based only on static validation.
