# Factor Golf Quick Coach Beta - RELEASE AND CONTINUITY PLAN

## Goal
Josh should be able to remain almost entirely hands-off:
- describe desired behavior;
- run only the hardware-dependent Halliseum validation;
- use one-click updates after bootstrap.

Engineering work, documentation, packaging, manifests, hashes, regression tracking, and source history should be maintained outside chat.

## Source of truth
GitHub is the durable engineering source.
Quick Coach lives under its own top-level `quick-coach-beta/` area and must not share version numbers or release status with Factor Golf Sim Control Center.

## Continuity files
Every development checkpoint must update:
- START_HERE
- PROJECT_STATE
- DECISION_RELEASE_LOG
- ARCHITECTURE when architecture changes
- REGRESSION_TEST_MATRIX
- release/update state

## New-chat recovery
A new chat should:
1. Read all Quick Coach continuity files.
2. Inspect the authoritative Quick Coach source/release candidate.
3. Identify the last Halliseum-accepted version.
4. Identify current OPEN and FAIL items.
5. Continue from that state without asking Josh to reconstruct prior work from memory.

## Release states
- dev: off-machine/static tests only
- candidate: ready for Halliseum validation
- accepted: Halliseum-required gates passed
- rejected: regression or required function failed

## Release rule
Never call a build accepted, published, verified, or working unless that step actually occurred.

## Chat-length rule
Chat history is disposable. Project state is not.
Important technical decisions and real-machine results must be written to durable project files as they happen, not saved up for a giant migration when the conversation is already near its limit.

## Current bootstrap gap
The Quick Coach one-click update feed still needs to be fully published and verified end-to-end. Until that is proven, do not tell Josh that manual downloads are permanently eliminated.
