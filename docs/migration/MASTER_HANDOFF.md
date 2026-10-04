# FACTOR GOLF SOFTWARE - MASTER HANDOFF

This is the one-file continuity summary for moving Factor Golf development into a dedicated ChatGPT Project.

## What to trust
- Accepted engineering baseline: **v0.8.14**
- v0.8.15: **REJECTED** because the first Halliseum run regressed automatic Practice Range navigation.
- Current stable Drive feed has been rolled back to v0.8.14.
- The migration bundle contains the exact v0.8.14 source plus the v0.8.14 -> v0.8.15 changed-file diffs.

## Where we left off
v0.8.14 real-machine PASS:
- Coach Mode auto-navigation to GSPro Practice Range
- no startup Driver cheat sheet
- AI Coach trigger/card/TTS
- Club Selector calibration captures and saves the user's click

v0.8.14 OPEN/FAIL:
- TEST CLUB DETECTION did not return a visible detected club
- club-change Cheat Sheets therefore still do not work reliably
- voice follow-up repeatedly says `I did not catch that clearly`

v0.8.15:
- attempted to fix club-test result visibility/OCR sizing
- first Halliseum run failed automatic range navigation
- reject and investigate, do not blindly patch forward

## Engineering reset, not product reset
Nothing is being thrown away. The new project should:
1. import v0.8.14 into GitHub as the accepted baseline;
2. use the regression matrix before publishing;
3. analyze v0.8.15 changes without promoting them;
4. solve club truth and voice recognition from a controlled branch;
5. keep coaching logic and Halliseum hardware knowledge intact.

## Required read order
00_START_HERE.md
02_PROJECT_STATE.md
03_DECISION_RELEASE_LOG.md
04_ARCHITECTURE.md
05_PRODUCT_REQUIREMENTS.md
06_REGRESSION_TEST_MATRIX.md
07_GITHUB_AND_RELEASE_PLAN.md

## New Project instructions
Use the exact text in `01_PROJECT_INSTRUCTIONS.txt`.

## First message
Use the exact text in `08_FIRST_MESSAGE_FOR_NEW_PROJECT.txt`.

## Durable cloud handoff
A Google Drive folder named **Factor Golf Software Migration** is being created and populated with this material. The new Project should use that folder plus GitHub as its continuity sources.

## Key current source paths
Accepted source baseline:
`source_baseline_v0.8.14/`

Rejected change evidence:
`rejected_v0.8.15_diff/`

## Important release hashes
v0.8.14 SHA-256:
`d6b2e6fd285e7b7b482ad51042e7f1c83de2021ffa309565d1cb5410de0c9634`

v0.8.15 SHA-256:
`1e696eb10f8381066db35935ef5707396fd0df512e775fd8ee41f421b87d520a`
