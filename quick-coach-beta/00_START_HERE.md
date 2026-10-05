# Factor Golf Quick Coach Beta - START HERE

## Product separation
Factor Golf Quick Coach Beta is a separate product from Factor Golf Sim Control Center.
Do not modify, package, publish, or debug the main Factor Golf Sim Control Center as part of Quick Coach work unless Josh explicitly asks.

Main Factor Golf accepted baseline remains v0.8.14. Quick Coach has its own versions, state, tests, and release path.

## Required read order before changing Quick Coach
1. `00_START_HERE.md`
2. `01_PROJECT_STATE.md`
3. `02_DECISION_RELEASE_LOG.md`
4. `03_ARCHITECTURE.md`
5. `04_REGRESSION_TEST_MATRIX.md`
6. `05_RELEASE_AND_CONTINUITY_PLAN.md`

## Current Quick Coach truth
- Product name: **Factor Golf Quick Coach Beta**
- Current generated candidate: **v0.1.2**
- v0.1.2 is **NOT Halliseum-accepted yet**.
- v0.1.1 failed on the Halliseum while saving the OpenAI API key because the script referenced the wrong .NET DPAPI type.
- v0.1.2 corrects that exact type reference and passed available static/package checks, but still requires real Windows/Halliseum validation.
- Far-right PCsensor pedal is mapped to **F18**.
- Quick Coach must remain usable during normal GSPro tournament/18-hole play without launching full Factor Golf Coach Mode.

## Continuity rule
Do not rely on chat history as the source of truth. Every accepted decision, release result, regression, and next action must be written back to these files before ending a development checkpoint.

If a chat gets long, starts losing context, or a new chat is opened, the new chat should read this folder first and continue from the recorded state rather than reconstructing the project from conversation memory.
