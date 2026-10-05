# Voice recognition recovery candidate

Independent branch from the green rollback candidate; no club/navigation changes. Keeps the working TTS path and existing English (US) Windows recognizer. It adds an explicit exit grammar alongside dictation, validates configuration bounds, and permits exact exit commands at 0.25 confidence while preserving the existing 0.48 question threshold. Extremely weak exit guesses are retried and never sent as questions.

Three consecutive low-confidence results now stop listening rather than loop indefinitely. A recognized question resets this budget for the next turn; accepted turns remain separately bounded. Microphone/recognizer initialization and runtime exceptions produce persistent voice_recognition_status.json with request ID, engine ID, culture, default-input designation, thresholds, recognition state and available text/confidence/error. No audio is recorded, and diagnostic/private data is not checked into the repository. The microphone's physical device name is not available through this implementation; default input is explicitly labeled. The UI reports confidence/attempt count and terminal failure guidance. Disposal is guaranteed around the conversation loop.

Tests execute the production recognition loop using a scripted recognizer, including low-confidence exit, valid questions, three failures, silence, exceptions, phrase boundaries and config bounds. They also construct the real System.Speech exit grammar on Windows. The inherited 11 install/update regressions and source/syntax gates remain required.

This repairs control flow and observability, not the acoustic accuracy of Windows dictation. Live microphone routing, background noise, recognition accuracy and hands-free GSPro return still require Halliseum validation before release. No version bump or release publication.

API reference: https://learn.microsoft.com/en-us/dotnet/api/system.speech.recognition.grammarbuilder?view=netframework-4.8.1
