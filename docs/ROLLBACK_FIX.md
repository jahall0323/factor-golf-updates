# Candidate rollback repair

Based on accepted v0.8.14 plus the test-only branch. The original failing rollback assertion remains intact; nested replaced/new files and directories now have additional checks.

The updater records package-owned paths before mutating them. Rollback restores exact overwritten file paths from a complete snapshot, deletes newly introduced files, then deletes only newly introduced directories that are empty. Preserved config/secrets/log paths are excluded; unrelated data is untouched. A snapshot-complete flag prevents an incomplete backup from being restored. Snapshot names include a GUID to avoid same-second collisions.

No release version bump or publishing. Candidate source hashes live in CANDIDATE_CHANGES.json; the original migration manifest and archived baseline remain immutable. Static checks verify both the historic artifact and the explicit candidate changes. Windows results are recorded in CI.
