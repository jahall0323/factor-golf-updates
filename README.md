# Factor Golf Sim Control Center

Accepted engineering baseline: **v0.8.14**. **v0.8.15 is rejected** after a Halliseum automatic range-navigation regression. This repository has no newly published release or live update manifest.

- `src/`: exact accepted package source; legacy names and relative asset paths preserved.
- `docs/migration/`: original migration instructions, state, architecture, requirements, release log and regression matrix.
- `evidence/`: immutable accepted/rejected ZIPs and rejected changed-file diffs. Archives are provenance, never the normal development source.
- `tools/`, `tests/`: read-only static checks and mutation tests.

Run `python tools/check_regressions.py` and `python -m unittest discover -s tests -v`. On Windows, run `powershell -NoProfile -File tools/check_powershell.ps1`. GitHub Actions runs all three, including Windows PowerShell 5.1 parsing.

The current gate deliberately pins the full original baseline. Before feature development, retain this immutable baseline test and introduce explicit candidate checks against the regression matrix; do not rewrite historical hashes to conceal changes. Syntax/XML checks are not WPF or simulator validation. No automated publishing is configured. Stable promotion requires applicable automated/install/update tests and Halliseum final validation.

Read `docs/MIGRATION_AUDIT.md` and then `docs/migration/00_START_HERE.md` before implementation.
