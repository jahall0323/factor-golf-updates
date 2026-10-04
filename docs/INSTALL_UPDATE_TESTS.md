# Install/update regression contracts

The Windows suite executes the unchanged baseline updater in disposable directories. File hashing, extraction, copying, version validation, preservation and rollback are real. Process enumeration returns no processes; launches are counted instead of executed; sleeps and failure dialogs are suppressed. These are explicitly bounded integration tests, not end-to-end runtime proof.

Scenarios: fresh updater target, upgrade, nested package, incorrect/missing hash, version mismatch, missing main script, conflicting sources, non-HTTPS URL, injected partial-copy failure with rollback, and the BAT installer's exact xcopy command against an isolated target. Fixtures exercise config/calibration/routing, opaque secret bytes and learned bag-data preservation. Fixtures are synthetic and do not contain user data.

The installer test validates payload copying only. BAT process cleanup, Windows shortcuts, app launch, downloaded-package HTTP behavior, updater button comparison and real encrypted-secret decryption remain untested. No candidate release package or manifest is published.

The rollback contract requires newly introduced files to be removed when installation fails. Source inspection suggests the baseline rollback copies old files back but does not delete new files; the contract intentionally remains strict and may expose this defect. Do not weaken it to get green CI. This branch changes tests and documentation only.
