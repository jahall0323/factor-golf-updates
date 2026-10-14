# Install/update regression contracts

The Windows suite executes the unchanged baseline updater in disposable directories. File hashing, extraction, copying, version validation, preservation and rollback are real. Process enumeration returns no processes; launches are counted instead of executed; sleeps and failure dialogs are suppressed. These are explicitly bounded integration tests, not end-to-end runtime proof.

Scenarios: fresh updater target, upgrade, nested package, incorrect/missing hash, version mismatch, missing main script, conflicting sources, non-HTTPS URL, injected partial-copy failure with rollback, and the BAT installer's exact xcopy command against an isolated target. Fixtures exercise config/calibration/routing, opaque secret bytes and learned bag-data preservation. Fixtures are synthetic and do not contain user data.

The installer test validates payload copying only. BAT process cleanup, Windows shortcuts, app launch, downloaded-package HTTP behavior, updater button comparison and real encrypted-secret decryption remain untested. No candidate release package or manifest is published.

The rollback contract requires newly introduced files to be removed when installation fails. Source inspection suggests the baseline rollback copies old files back but does not delete new files; the contract intentionally remains strict and may expose this defect. Do not weaken it to get green CI. This branch changes tests and documentation only.

## Observed Windows results

Executed on Windows PowerShell 5.1 in GitHub Actions run 37233396610 against commit c0ee0a69cb4b9e5768996d219c163254bb853299. Ten of eleven scenarios passed. The static job also passed, including baseline integrity, six mutation tests and application PowerShell syntax.

Failed contract: rollback. The test installed aa_new_file.txt, injected a copy exception later in the same update, verified that the old application and version were restored and that the updater logged rollback completion, then found aa_new_file.txt still present. The rollback loop restores snapshot contents but does not remove files introduced by the failed package. This is a reproduced baseline updater defect, not a source change caused by this test branch. Keep the strict check failing until a reviewed updater fix is tested. Do not promote a release on these results.

Passing scenarios: fresh updater target, upgrade, nested package, incorrect hash, missing hash, version mismatch, missing main script, conflicting sources, non-HTTPS source rejection, and installer payload copying. Preservation assertions passed in these scenarios. Rollback preservation assertions after the failed removal assertion were not reached, so full rollback data preservation is not claimed.

Evidence: https://github.com/jahall0323/factor-golf-updates/actions/runs/37233396610
