# Implementation Plan - WispFlow v0.2

## Summary

WispFlow v0.1 (US-001 through US-007) is complete with core functionality: menu bar app, global hotkey, audio capture, WhisperKit transcription, rule-based text cleanup, text insertion, and settings persistence.

**v0.2 focuses on fixing the critical transcription issue** where recordings return "[BLANK_AUDIO]" instead of actual text. The PRD identifies root causes in audio format/preprocessing and WhisperKit configuration. Additionally, v0.2 adds debug capabilities and local LLM cleanup.

### Key Gaps to Address:
1. **Audio debugging** - No audio level meter, silence detection, or waveform visualization
2. **Audio preprocessing** - Need validation of 16kHz conversion and Float32 normalization
3. **Model loading UX** - Auto-load exists but lacks menu bar progress indicator and "Model Ready" status
4. **Error handling** - BLANK_AUDIO provides no helpful feedback; need meaningful error messages
5. **Debug mode** - No audio export or diagnostic logging for troubleshooting
6. **LLM cleanup** - Current cleanup is rule-based; PRD requests local LLM integration

### Priority Order:
1. US-101 & US-102 (Debug Audio + Fix Format) - Critical for fixing BLANK_AUDIO
2. US-104 (Better Error Handling) - Provide meaningful feedback
3. US-103 (Improve Model Loading) - Better UX for model state
4. US-105 (Audio Debug Mode) - Developer diagnostics
5. US-106 (Local LLM Cleanup) - Enhanced feature

---

## Tasks

### US-101: Debug Audio Capture

- [x] Add audio level monitoring to AudioManager
  - Scope: Modify `Sources/WispFlow/AudioManager.swift` to compute peak audio level (dB) from captured buffers in the tap callback. Add `@Published var currentAudioLevel: Float` property.
  - Acceptance: `currentAudioLevel` updates in real-time during recording with values in dB scale (e.g., -60 to 0)
  - Verification: `swift build` passes; log audio levels during recording and verify they change with sound input
  - **DONE:** Added `@Published var currentAudioLevel: Float` property, `calculatePeakLevel()` method, and `amplitudeToDecibels()` conversion. Level updates in real-time via tap callback.

- [x] Add audio level meter to RecordingIndicatorWindow
  - Scope: Modify `Sources/WispFlow/RecordingIndicatorWindow.swift` to display a visual level meter (colored bar or SF Symbol) next to the recording icon. Connect to AudioManager's audio level property.
  - Acceptance: Level meter shows real-time audio activity when speaking into microphone
  - Verification: `swift build` passes; start recording and observe level meter responds to voice
  - **DONE:** Created `AudioLevelMeterView` class with color-coded levels (gray<-40dB, green, yellow, red). Added `connectAudioManager()` method using Combine to subscribe to level updates.

- [x] Add silence detection and warning
  - Scope: Modify `Sources/WispFlow/AudioManager.swift` to track if audio has been below threshold (e.g., peak < -40dB) for entire recording. Add callback `onSilenceDetected: (() -> Void)?`.
  - Acceptance: Callback fires if recording stops with only silence detected
  - Verification: `swift build` passes; record without speaking, verify silence warning appears
  - **DONE:** Added `onSilenceDetected` callback, tracks `peakLevelDuringRecording`, alerts user with actionable message if peak < -40dB threshold.

- [x] Log audio buffer statistics
  - Scope: Modify `Sources/WispFlow/AudioManager.swift` to log buffer details (sample count, duration, peak level, format) in `stopCapturing()` before returning result.
  - Acceptance: Console output shows detailed audio statistics after each recording
  - Verification: `swift build` passes; record audio, check console for detailed buffer stats
  - **DONE:** Added `AudioBufferStats` struct and `logAudioBufferStatistics()` method. Logs formatted table with sample count, duration, sample rate, peak dB, RMS dB, min/max samples, and silence status.

- [x] Enforce minimum recording duration (0.5s)
  - Scope: Modify `Sources/WispFlow/AppDelegate.swift` or `AudioManager.swift` to reject recordings shorter than 0.5 seconds with appropriate feedback.
  - Acceptance: Short recordings show "Recording too short" error instead of attempting transcription
  - Verification: `swift build` passes; quick tap hotkey, verify minimum duration warning
  - **DONE:** Added `minimumRecordingDuration` constant (0.5s), `onRecordingTooShort` callback, and validation in `stopCapturing()`. AppDelegate shows informational alert.

---

### US-102: Fix WhisperKit Audio Format

- [ ] Validate audio format before transcription
  - Scope: Modify `Sources/WispFlow/WhisperManager.swift` to add `validateAudioData()` method that checks: sample count > 0, expected Float32 format, reasonable duration (0.5s-120s), values in [-1.0, 1.0] range.
  - Acceptance: Invalid audio data returns descriptive error instead of attempting transcription
  - Verification: `swift build` passes; test with empty/invalid data, verify validation errors

- [ ] Fix audio normalization to [-1.0, 1.0] range
  - Scope: Modify `Sources/WispFlow/AudioManager.swift` in `combineBuffersToData()` to ensure output Float32 samples are normalized. Add `normalizeAudio()` helper if needed.
  - Acceptance: Exported audio data has samples within [-1.0, 1.0] range
  - Verification: `swift build` passes; log sample min/max values, verify normalization

- [ ] Verify 16kHz sample rate conversion
  - Scope: Modify `Sources/WispFlow/AudioManager.swift` to add validation in tap callback that confirms converted buffer is at 16kHz. Log warning if conversion fails.
  - Acceptance: All audio sent to WhisperKit is verified to be 16000 Hz
  - Verification: `swift build` passes; log sample rate in conversion step, verify 16000 Hz

- [ ] Add audio preprocessing diagnostics
  - Scope: Add method `logAudioDiagnostics(audioData: Data)` to WhisperManager that logs: byte count, sample count, duration (samples/16000), peak amplitude, RMS level.
  - Acceptance: Detailed diagnostics logged before each transcription attempt
  - Verification: `swift build` passes; record and transcribe, check console for diagnostics

- [ ] Handle WhisperKit "[BLANK_AUDIO]" response
  - Scope: Modify `Sources/WispFlow/WhisperManager.swift` `transcribe()` to detect "[BLANK_AUDIO]" in results and convert to meaningful error with possible causes (silent audio, format issue, model problem).
  - Acceptance: "[BLANK_AUDIO]" is never shown to user; replaced with actionable error message
  - Verification: `swift build` passes; if BLANK_AUDIO occurs, verify helpful error shown

---

### US-103: Improve Model Loading

- [ ] Show model loading status in menu bar
  - Scope: Modify `Sources/WispFlow/StatusBarController.swift` to update status item tooltip or add secondary icon state showing model status (loading spinner, checkmark, error).
  - Acceptance: Menu bar icon/tooltip reflects model state: "Loading model...", "Model ready", "Model error"
  - Verification: `swift build` passes; launch app, observe menu bar reflects model loading progress

- [ ] Block recording until model is ready
  - Scope: Modify `Sources/WispFlow/AppDelegate.swift` `handleRecordingStateChange()` to check `whisperManager.isReady` before starting recording. Show alert if model not ready.
  - Acceptance: Cannot start recording if model is not loaded; clear message guides user to wait or open settings
  - Verification: `swift build` passes; try to record before model loads, verify blocking alert

- [ ] Add model loading progress indicator
  - Scope: Modify `Sources/WispFlow/WhisperManager.swift` to expose download progress via `@Published var downloadProgress: Double`. Update StatusBarController to show progress percentage.
  - Acceptance: During model download, progress percentage is visible in menu bar or settings
  - Verification: `swift build` passes; download new model, observe progress updates

- [ ] Add "Model Ready" visual indicator
  - Scope: Modify `Sources/WispFlow/StatusBarController.swift` to show a small badge or change icon color when model is ready. Add checkmark badge to menu item.
  - Acceptance: User can clearly see when model is loaded and ready for transcription
  - Verification: `swift build` passes; wait for model to load, verify visual indicator appears

---

### US-104: Better Error Handling

- [ ] Surface WhisperKit errors to user
  - Scope: Modify `Sources/WispFlow/WhisperManager.swift` to catch specific WhisperKit errors and translate to user-friendly messages with actionable suggestions.
  - Acceptance: All WhisperKit errors show helpful alerts with next steps
  - Verification: `swift build` passes; simulate errors, verify user-friendly alerts

- [ ] Add "No speech detected" error handling
  - Scope: Modify `Sources/WispFlow/AppDelegate.swift` or WhisperManager to detect empty/blank transcription results and show "No speech detected - check microphone" message.
  - Acceptance: Empty transcription shows helpful error, not empty insertion
  - Verification: `swift build` passes; record silence, verify "No speech detected" message

- [ ] Add "Model not loaded" specific error
  - Scope: Modify `Sources/WispFlow/AppDelegate.swift` `processTranscription()` to show specific error when `whisperManager.isReady` is false with button to open Settings.
  - Acceptance: Clear error message with Settings shortcut when model not loaded
  - Verification: `swift build` passes; delete model, try to transcribe, verify error with Settings button

- [ ] Implement error logging to .ralph/errors.log
  - Scope: Create `Sources/WispFlow/ErrorLogger.swift` utility that appends errors with timestamps to `~/.ralph/errors.log`. Integrate with all managers' `onError` callbacks.
  - Acceptance: All errors are logged to file with timestamps for debugging
  - Verification: `swift build` passes; trigger errors, verify entries in errors.log

- [ ] Add retry option for failed transcriptions
  - Scope: Modify error alerts to include "Try Again" button that re-attempts transcription with the same audio data (requires keeping audio data until transcription succeeds).
  - Acceptance: User can retry failed transcription without re-recording
  - Verification: `swift build` passes; fail transcription, click retry, verify re-attempt

---

### US-105: Audio Debug Mode

- [ ] Add Debug Mode toggle in Settings
  - Scope: Modify `Sources/WispFlow/SettingsWindow.swift` to add "Debug Mode" section with toggle switch. Store in UserDefaults. Add `isDebugMode` property to AppDelegate or create DebugManager.
  - Acceptance: Debug mode can be enabled/disabled in Settings
  - Verification: `swift build` passes; toggle debug mode in settings, verify setting persists

- [ ] Show audio waveform visualization
  - Scope: Create `Sources/WispFlow/AudioWaveformView.swift` SwiftUI view that displays audio buffer as waveform. Show in debug panel or recording indicator when debug mode enabled.
  - Acceptance: Audio waveform visible during/after recording in debug mode
  - Verification: `swift build` passes; enable debug mode, record audio, observe waveform

- [ ] Display raw transcription before cleanup
  - Scope: Modify `Sources/WispFlow/AppDelegate.swift` or create debug panel to show raw WhisperKit output before text cleanup when debug mode enabled.
  - Acceptance: Can compare raw transcription vs cleaned text in debug mode
  - Verification: `swift build` passes; enable debug, transcribe, verify raw output shown

- [ ] Add audio export as WAV file
  - Scope: Create `Sources/WispFlow/AudioExporter.swift` utility to convert Float32 audio data to WAV format and save to file. Add "Export Audio" button to debug panel or Settings.
  - Acceptance: User can export recorded audio as WAV file for offline analysis
  - Verification: `swift build` passes; record audio, export, verify WAV file is playable

- [ ] Add detailed debug logging window
  - Scope: Create `Sources/WispFlow/DebugLogWindow.swift` NSWindow that displays real-time log messages. Show audio stats, transcription results, model status. Only visible in debug mode.
  - Acceptance: Debug window shows detailed logs during recording/transcription
  - Verification: `swift build` passes; enable debug mode, open debug window, verify log output

---

### US-106: Local LLM Text Cleanup

- [ ] Research and select local LLM framework
  - Scope: Evaluate llama.cpp Swift bindings vs MLX Swift for local LLM inference. Consider: SPM compatibility, model size, inference speed, memory usage. Document choice in Notes.
  - Acceptance: Clear decision on framework with justification documented
  - Verification: Document framework choice and reasoning in implementation plan Notes section

- [ ] Integrate local LLM framework
  - Scope: Add LLM dependency to `Package.swift`. Create `Sources/WispFlow/LLMManager.swift` wrapper for model loading and inference.
  - Acceptance: LLM framework compiles and links with app
  - Verification: `swift build` passes with LLM dependency

- [ ] Implement model download and management
  - Scope: Add small LLM model (Phi-3-mini, Gemma 2B, or similar) download capability to LLMManager. Store in Application Support. Add model selection to Settings.
  - Acceptance: User can download and manage LLM models in Settings
  - Verification: `swift build` passes; download model from Settings, verify file exists

- [ ] Create text cleanup prompt system
  - Scope: Create prompt template in LLMManager for text cleanup: remove fillers, fix grammar, maintain meaning. Test with sample transcriptions.
  - Acceptance: LLM produces cleaned text that maintains meaning while improving grammar
  - Verification: `swift build` passes; test cleanup prompt with sample text

- [ ] Integrate LLM with TextCleanupManager
  - Scope: Modify `Sources/WispFlow/TextCleanupManager.swift` to use LLMManager when available, fallback to rule-based cleanup if LLM unavailable or disabled.
  - Acceptance: Text cleanup uses LLM when available, falls back to rules otherwise
  - Verification: `swift build` passes; test with/without LLM, verify both paths work

- [ ] Add LLM cleanup mode toggle
  - Scope: Modify `Sources/WispFlow/SettingsWindow.swift` to add toggle between "Rule-based" and "AI-powered" cleanup modes. Persist setting.
  - Acceptance: User can choose between rule-based and LLM cleanup
  - Verification: `swift build` passes; toggle modes, verify cleanup behavior changes

---

## Notes

### Discoveries

1. **Current AudioManager** already converts to 16kHz mono Float32 format via AVAudioConverter. However, the converter may silently fail or produce empty buffers - need validation.

2. **WhisperManager.transcribe()** already handles empty results but returns empty string rather than meaningful error. The "[BLANK_AUDIO]" issue likely occurs in WhisperKit itself when audio format is incorrect.

3. **Current implementation** does not preserve audio data after transcription attempt, making retry impossible. Need to cache audio until transcription succeeds.

4. **Rule-based TextCleanupManager** is already comprehensive with 3 cleanup modes. LLM integration (US-106) should be additive, not replacement.

### Risks

1. **Local LLM memory usage** - Running both WhisperKit and LLM may strain memory on 8GB Macs. Consider model size limits and sequential (not parallel) inference.

2. **Audio format edge cases** - Some microphones may produce non-standard formats that AVAudioConverter doesn't handle well. Debug mode will help identify these.

3. **WhisperKit dependency** - WhisperKit requires macOS 14.0+ which limits user base. Cannot downgrade.

### Framework Evaluation for US-106

**llama.cpp Swift**
- Pros: Mature, well-tested, cross-platform
- Cons: C++ core, bridging complexity

**MLX Swift**
- Pros: Apple-native, optimized for Apple Silicon
- Cons: Apple Silicon only, newer/less tested

Recommendation: Start with llama.cpp for broader compatibility, evaluate MLX if performance issues arise on Apple Silicon.
