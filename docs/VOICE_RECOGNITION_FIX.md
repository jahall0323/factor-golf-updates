# Voice recognition recovery candidate

Independent branch from the green rollback candidate; no club/navigation changes. Keeps the working TTS path and existing English (US) Windows recognizer. It adds an explicit exit grammar alongside dictation, validates configuration bounds, and permits exact exit commands at 0.25 confidence while preserving the existing 0.48 question threshold. Extremely weak exit guesses are retried and never sent as questions.

Three consecutive low-confidence results now stop listening rather than loop indefinitely. A recognized question resets this budget for the next turn; accepted turns remain separately bounded. Microphone/recognizer initialization and runtime exceptions produce persistent voice_recognition_status.json with request ID, engine ID, culture, default-input designation, thresholds, recognition state and available text/confidence/error. No audio is recorded, and diagnostic/private data is not checked into the repository. The microphone's physical device name is not available through this implementation; default input is explicitly labeled. The UI reports confidence/attempt count and terminal failure guidance. Disposal is guaranteed around the conversation loop.

Tests execute the production recognition loop using a scripted recognizer, including low-confidence exit, valid questions, three failures, silence, exceptions, phrase boundaries and config bounds. They also construct the real System.Speech exit grammar on Windows. The inherited 11 install/update regressions and source/syntax gates remain required.

This repairs control flow and observability, not the acoustic accuracy of Windows dictation. Live microphone routing, background noise, recognition accuracy and hands-free GSPro return still require Halliseum validation before release. No version bump or release publication.

API reference: https://learn.microsoft.com/en-us/dotnet/api/system.speech.recognition.grammarbuilder?view=netframework-4.8.1

## Windows result

Commit b88c3526c92b10abbf7337f9a9db5c6439b2c6d4 passed the voice-recognition contract job, all 11 install/update cases and the static job (integrity, six mutation tests, PS5.1 parsing) in run 37246590736. The terminal-diagnostic test also verifies that the final rejected phrase and confidence remain available after retries are exhausted. This is synthetic recognition/control-flow coverage and real grammar construction, not microphone accuracy acceptance.

Evidence: https://github.com/jahall0323/factor-golf-updates/actions/runs/37246590736
