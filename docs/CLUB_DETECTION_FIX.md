# Club detection candidate

Based on the green rollback candidate, on its own branch. Settings launches each test with a unique request ID and result path. Timer polling prioritizes that result over old calibration messages, retains the terminal message, reports launch/exit failures, and stops only its own test worker after 30 seconds. The normal watcher cannot overwrite the result. No automatic result popup steals focus.

Selector OCR requires a complete normalized club label and rejects multiple different clubs. Offscreen UI elements are ignored and conflicting UI candidates are rejected. The live selection path no longer falls back to arbitrary whole-screen OCR text. A blank or ambiguous selector therefore remains unverified instead of being filled from unrelated text. No startup card, key-count inference or navigation change is introduced.

Regression coverage executes the actual Settings polling function against a stale calibration fixture, plus request correlation, timeout/exit handling, retained feedback, and actual selection-source fallback logic. Windows CI also runs the 11 install/update cases, source integrity and PS5.1 parsing.

Remaining hardware gate: the saved private crop shows scenery, not a selector. These changes fix result visibility and unsafe fallback; they do not prove a fix for the capture location or live club recognition. Physical window/capture coordinates and visible selector state must be correlated on Halliseum before changing calibration/DPI behavior. No release is authorized by these tests.

## Windows result

Commit cf69b3c6c63c93c3c419bd5053bfbb406c8df730 passed the club-detection contract job, all 11 install/update cases and the static job (integrity, six mutation tests, PS5.1 parsing) in run 37246286081. This is automated behavioral coverage with synthetic input, not GSPro hardware acceptance.

Evidence: https://github.com/jahall0323/factor-golf-updates/actions/runs/37246286081
