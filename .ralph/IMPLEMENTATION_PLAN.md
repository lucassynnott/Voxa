# Implementation Plan - WispFlow v0.4

## Summary

WispFlow v0.3 (US-201 through US-205) is complete with accessibility permission detection, audio buffer pipeline verification, audio capture diagnostics, permission flow UX, and silence detection fixes.

**v0.4 focuses on investigating and fixing two critical issues:**
1. **Audio buffer disconnect** - Level meter shows activity, but transcription reports silence
2. **Model download failures** - Whisper and LLM models fail to download silently

### Key Findings from Code Analysis:

1. **Audio Buffer Architecture Already Unified**: The current `AudioManager.swift` implementation already uses a single buffer path. The level meter calculates from the raw input buffer in the tap callback, and the transcription buffer stores the converted (16kHz) version of the same data. This is correct architecture.

2. **Potential Root Cause - Different Data Sources**: The level meter reads the **raw input buffer** (native device sample rate), while transcription uses the **converted buffer** (16kHz). If the audio converter is failing silently or producing zeros, this would explain the disconnect.

3. **WhisperKit Download Progress**: WhisperKit initializes and downloads models internally, but the current code doesn't effectively capture download progress. The `WhisperKitConfig` doesn't expose a progress callback.

4. **LLM Download Already Has Progress**: `LLMManager.swift` has proper download progress tracking via `URLSessionDownloadDelegate`.

5. **Audio Export Already Implemented**: `AudioExporter.swift` and `DebugManager` already support WAV export functionality.

### Priority Order (based on user impact):
1. US-301 (Audio Buffer Architecture) - Verify and fix the converter path
2. US-302 (Audio Tap Verification) - Confirm tap callbacks are firing with data
3. US-303 (Buffer Integrity Logging) - Trace where data may be lost
4. US-304 (Whisper Model Downloads) - Fix download progress and error handling
5. US-305 (LLM Model Downloads) - Enhance error handling (mostly working)
6. US-306 (Audio Debug Export) - Already implemented, verify functionality

---

## Tasks

### US-301: Unify Audio Buffer Architecture ✅ COMPLETE
As a user, I want the audio that shows in the level meter to be the same audio that gets transcribed.

**Implementation (2026-01-13):** Replaced the old `audioBuffers: [AVAudioPCMBuffer]` array with a single unified `masterBuffer: [Float]`. The level meter now calculates from the exact same samples that get appended to masterBuffer, eliminating any possibility of disconnect.

- [x] Remove duplicate/separate audio buffers in AudioManager
  - Removed `audioBuffers: [AVAudioPCMBuffer]` array
  - Created `masterBuffer: [Float]` as the ONLY audio storage
  - Added thread-safe `bufferLock` for concurrent access
  - Verification: `swift build` passes ✓

- [x] Create single masterBuffer that is the ONLY audio storage
  - `private var masterBuffer: [Float] = []` is now the sole buffer
  - All other buffer references have been removed
  - Verification: `swift build` passes ✓

- [x] Audio tap callback appends to masterBuffer
  - Tap callback extracts Float samples from converted buffer
  - Samples are appended directly to masterBuffer with thread safety
  - Verification: `swift build` passes ✓

- [x] Level meter calculates from samples just added to masterBuffer
  - Added `calculatePeakLevelFromSamples()` method
  - Level is calculated from the EXACT same samples added to masterBuffer
  - No separate data path for level meter vs transcription
  - Verification: `swift build` passes ✓

- [x] getAudioBuffer() returns masterBuffer directly
  - Added public `getAudioBuffer() -> [Float]` method
  - Returns masterBuffer contents with thread-safe access
  - Verification: `swift build` passes ✓

- [x] Log sample counts at every stage to verify data flow
  - Added `tapCallbackCount` tracking
  - Logs sample counts every 10th tap callback
  - Logs masterBuffer sample count at capture stop
  - Detailed logging in getMasterBufferDataWithStats()
  - Verification: `swift build` passes ✓

---

### US-302: Audio Tap Verification ✅ COMPLETE
As a developer, I want to verify the audio tap is actually being called with real data.

**Implementation (2026-01-13):** Added comprehensive tap callback verification including a 2-second timer alert, detailed first-callback logging with full format info and sample counts, and improved empty/zero-data detection with counters and structured logging.

- [x] Add tap callback counter and log callback frequency
  - Added `tapCallbackCount`, `emptyCallbackCount`, and `zeroDataCallbackCount` tracking
  - Added `logTapCallbackStats()` method that logs summary after recording stops
  - Summary includes: total callbacks, duration, callbacks/second, expected callbacks, empty count, zero-data count
  - Verification: `swift build` passes ✓

- [x] Log detailed format info on first tap callback
  - First tap callback now logs comprehensive details in a boxed format
  - Includes: input buffer frame count, sample rate, channels; converted buffer details; sample count extracted
  - Works for both converted and non-converted audio paths
  - Verification: `swift build` passes ✓

- [x] Alert if no callbacks received within 2 seconds
  - Added `noCallbackAlertTimer` property with `startNoCallbackAlertTimer()` and `stopNoCallbackAlertTimer()` methods
  - Timer fires after 2 seconds and checks if `tapCallbackCount == 0`
  - Logs prominent boxed warning with possible causes if no callbacks received
  - Added `onNoTapCallbacks` callback for external notification
  - Timer is properly cleaned up in `stopCapturing()` and `cancelCapturing()`
  - Verification: `swift build` passes ✓

- [x] Log if callback receives empty or zero-sample data
  - Added `emptyCallbackCount` counter for callbacks with empty buffers
  - Added `zeroDataCallbackCount` counter for callbacks where all samples are near-zero
  - Logs first occurrence immediately, then every 10th occurrence
  - Uses `zeroThreshold` of 1e-7 to detect near-zero samples
  - Counters are reset at start of each recording session
  - Verification: `swift build` passes ✓

---

### US-303: Buffer Integrity Logging ✅ COMPLETE
As a developer, I want to trace exactly where audio data goes.

**Implementation (2026-01-13):** Added comprehensive buffer integrity logging throughout the audio capture lifecycle. All masterBuffer operations are now traced with prominent boxed log messages including: buffer clear events (with previous/current counts), every append operation (first 5 + every 10th), buffer read events with empty warnings, and expected vs actual sample count comparison.

- [x] Log when masterBuffer is created/cleared
  - Added prominent boxed log in `startCapturing()` showing previous and current sample counts
  - Added logging in `stopCapturing()` after buffer is read for transcription
  - Added boxed log in `cancelCapturing()` showing discarded samples and callback count
  - Verification: `swift build` passes ✓

- [x] Log every append with sample count and running total
  - Enhanced tap callback logging: logs first 5 appends, then every 10th
  - Format: `[US-303] APPEND #N: +X samples | masterBuffer: before → after total | level: Y.YdB`
  - Provides traceability while avoiding excessive log spam
  - Verification: `swift build` passes ✓

- [x] Log when buffer is read for transcription
  - Added prominent boxed header when `getMasterBufferDataWithStats()` is called
  - Logs total samples retrieved from masterBuffer
  - Verification: `swift build` passes ✓

- [x] Log if buffer is empty when read
  - Added explicit warning box when masterBuffer is empty at read time
  - Includes possible causes: no tap callbacks, all empty/zero buffers, unexpected clear
  - Provides guidance to check callback counts
  - Verification: `swift build` passes ✓

- [x] Compare final buffer count to expected count (duration * 16000)
  - Added boxed comparison log in `stopCapturing()` after duration is calculated
  - Shows: duration, target sample rate, expected samples, actual samples, difference, variance %
  - Status indicator: ✓ for within 10%, ⚠️ for mismatch > 10%, ❌ for no samples
  - Verification: `swift build` passes ✓

---

### US-304: Fix Whisper Model Downloads
As a user, I want Whisper models to download successfully.

- [ ] Add WhisperKit initialization error logging with full context
  - Scope: Modify `Sources/WispFlow/WhisperManager.swift` `loadModel()` to log detailed error info including model path, directory permissions, network status
  - Acceptance: Console shows comprehensive error context when download/load fails
  - Verification: `swift build` passes; (simulate by disconnecting network) verify detailed error logged

- [ ] Improve download progress visibility (workaround for WhisperKit limitation)
  - Scope: Modify `Sources/WispFlow/WhisperManager.swift` to show intermediate status messages ("Connecting...", "Downloading model files...", "Verifying...") during load
  - Acceptance: User sees progress indication even without byte-level progress
  - Verification: `swift build` passes; download model, verify status messages update during process

- [ ] Verify model directory exists and is writable before download
  - Scope: Add pre-download check in `loadModel()` to verify `modelsDirectory` exists and is writable
  - Acceptance: Clear error message if directory issue prevents download
  - Verification: `swift build` passes; verify directory check logged

- [ ] Add model file verification after download
  - Scope: After WhisperKit init succeeds, verify model files exist in expected location and log their sizes
  - Acceptance: Console shows model files found with sizes after successful download
  - Verification: `swift build` passes; download model, verify file verification logged

- [ ] Show clear error message in UI when download fails
  - Scope: Modify `Sources/WispFlow/SettingsWindow.swift` `TranscriptionSettingsView` to show error alert with specific failure reason
  - Acceptance: User sees descriptive error message (not just status badge changing to "Error")
  - Verification: `swift build` passes; (simulate failure) verify error alert shown

- [ ] Add retry mechanism for failed downloads
  - Scope: Add "Retry Download" button that appears when modelStatus is .error, which resets status and calls loadModel() again
  - Acceptance: User can retry failed download without restarting app
  - Verification: `swift build` passes; after error, verify retry button works

---

### US-305: Fix LLM Model Downloads
As a user, I want LLM models to download successfully.

**Note:** LLM download already has proper progress tracking. Focus on error handling improvements.

- [ ] Improve download error messages with specific failure reasons
  - Scope: Modify `Sources/WispFlow/LLMManager.swift` `downloadModel()` to parse HTTP errors and show user-friendly messages (404 = "Model not found", 403 = "Access denied", timeout = "Network timeout")
  - Acceptance: User sees specific error message instead of generic "Download failed"
  - Verification: `swift build` passes; (simulate 404) verify specific error shown

- [ ] Add network reachability check before download attempt
  - Scope: Add pre-download check to verify network connectivity to huggingface.co
  - Acceptance: Clear message if network unavailable before download starts
  - Verification: `swift build` passes; (disconnect network) verify pre-check error shown

- [ ] Log actual download URL being used
  - Scope: Already logs URL; ensure it's visible in debug mode and shown in error messages
  - Acceptance: URL visible in console when download starts and in error messages
  - Verification: `swift build` passes; start download, verify URL logged

- [ ] Verify model file exists and has expected size after download
  - Scope: After download completes, verify file exists and size is reasonable (>100MB for most models)
  - Acceptance: Warning if downloaded file is suspiciously small (may indicate partial download)
  - Verification: `swift build` passes; download model, verify size check logged

- [ ] Add manual model path option as fallback
  - Scope: Add UI option in `TextCleanupSettingsView` to manually specify path to a pre-downloaded GGUF file
  - Acceptance: User can load model from custom path if downloads fail
  - Verification: `swift build` passes; verify manual path option works

---

### US-306: Audio Debug Export
As a user, I want to export my recorded audio to verify capture is working.

**Note:** This is already implemented in `AudioExporter.swift` and accessible via Settings > Debug. Tasks verify and enhance.

- [ ] Verify WAV export produces playable audio file
  - Scope: Test existing export functionality; verify exported WAV plays correctly in QuickTime/other players
  - Acceptance: Exported WAV file contains audible speech when speech was recorded
  - Verification: Manual test: record speech, export, play back in external player

- [ ] Add "Export Last Recording" status message after export
  - Scope: Modify export completion handler to show file path in a more prominent way (toast or inline message)
  - Acceptance: User clearly sees where file was saved
  - Verification: `swift build` passes; export file, verify clear confirmation shown

- [ ] Add option to auto-save recordings in debug mode
  - Scope: Add toggle in DebugSettingsView to automatically save each recording to a debug folder
  - Acceptance: When enabled, each recording is saved to ~/Documents/WispFlow/DebugRecordings/ with timestamp
  - Verification: `swift build` passes; enable auto-save, record, verify file saved automatically

- [ ] Log export success/failure with file details
  - Scope: Add logging when export completes with file size and duration
  - Acceptance: Console shows "Exported X samples (Y.Zs) to path" on success
  - Verification: `swift build` passes; export file, verify details logged

---

## Notes

### Discoveries

1. **Audio Buffer Architecture is Correct**: The code already implements a unified buffer approach. The level meter and transcription buffer use the same tap callback. The disconnect may be in the **audio converter** (converting native sample rate to 16kHz) rather than separate buffers.

2. **Converter Silent Failure Theory**: The audio converter in the tap callback may be:
   - Producing zeros when conversion fails
   - Not being called (inputBlock not triggered correctly)
   - Returning empty frames on some devices

3. **WhisperKit Progress Limitation**: WhisperKit doesn't expose download progress through its API. The current implementation simulates progress with status messages. A better solution would be to manually download the model files with progress tracking, then point WhisperKit to the local files.

4. **LLM Download Working**: The LLM download code in `LLMManager.swift` has proper progress tracking and error handling. The issue may be specific to certain models or network conditions.

5. **Audio Export Ready**: The `AudioExporter.swift` implementation is complete and functional. It converts Float32 samples to 16-bit PCM WAV format correctly.

### Risks

1. **Converter Device Compatibility**: The audio converter may behave differently on different Mac hardware (M1/M2 vs Intel, built-in mic vs external mic). Need to test on multiple configurations.

2. **WhisperKit API Changes**: WhisperKit may change its model download behavior in future versions. Current workarounds may need updating.

3. **Network-dependent Downloads**: Model downloads depend on Hugging Face availability. Consider adding fallback URLs or local model bundling for reliability.

4. **Sample Rate Mismatch**: If the input device sample rate changes mid-recording (e.g., switching devices), the converter may produce incorrect output.

### Technical Notes

- Audio tap callback runs on audio thread - minimize work and use DispatchQueue.main for UI updates
- WhisperKit expects 16kHz mono Float32 audio with samples in [-1.0, 1.0] range
- AVAudioConverter requires matching formats between input and output nodes
- LLM models are ~1-2GB - downloads may take several minutes on slow connections
- WAV export uses 16-bit PCM format (standard compatibility)
