# FACTOR GOLF SOFTWARE - GITHUB AND RELEASE PLAN

## Repository
Planned repo:
`jahall0323/factor-golf-updates`

The GitHub account is connected to ChatGPT, but at migration time no repository is visible to the connector. The only manual bootstrap step is to create the repository in GitHub and make it available to the ChatGPT GitHub connection.

Recommended:
- Public repository initially, because the app's raw HTTPS updater is not configured for GitHub authentication.
- Add README when creating it so a default branch exists.
- Default branch: `main`.

## Source layout after migration
Recommended:
- `/src/` application source
- `/src/workers/`
- `/assets/`
- `/docs/`
- `/tests/`
- `/tools/` build/release scripts
- `/releases/` optional manifests only, not the authoritative source
- root README

Do not keep creating the source tree by unpacking the previous release ZIP.

## First commit
Import the exact v0.8.14 source as the accepted baseline.
Add:
- migration docs;
- v0.8.14 SHA-256;
- rejected v0.8.15 diff;
- regression matrix.

Create a tag/marker such as:
`baseline-v0.8.14`

Do not tag v0.8.15 as stable.

## Update feed
Target:
`https://raw.githubusercontent.com/jahall0323/factor-golf-updates/main/latest.json`

Eventually prefer GitHub Releases or Factor Golf/CDN for binary packages, but keep manifest/provider abstraction so changing host does not require app redesign.

## Current Google Drive cleanup completed during migration
- Canonical cloud `latest.json` rolled back to v0.8.14.
- Duplicate `latest.json` removed.
- v0.8.15 ZIP renamed with `REJECTED_` prefix.
- Drive remains development archive/fallback, not long-term primary distribution.

## Promotion model
Suggested channels:
- dev: local automated tests only
- candidate: Halliseum validation
- stable: promoted only after required real-machine checks pass

A build should not be published directly to stable as part of the coding step.
