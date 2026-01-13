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

### US-302: Audio Tap Verification
As a developer, I want to verify the audio tap is actually being called with real data.

- [ ] Add tap callback counter and log callback frequency
  - Scope: Modify `Sources/WispFlow/AudioManager.swift` to count tap callbacks and log total after recording stops
  - Acceptance: Console shows "Received X tap callbacks in Y seconds" with reasonable count (>100 for 3s recording at 4096 buffer size)
  - Verification: `swift build` passes; record 3 seconds, verify callback count logged

- [ ] Log detailed format info on first tap callback
  - Scope: Modify `Sources/WispFlow/AudioManager.swift` tap callback to log full buffer format (sample rate, channels, frame length, common format) on first callback only
  - Acceptance: Console shows complete format information on first tap
  - Verification: `swift build` passes; start recording, verify format logged

- [ ] Alert if no callbacks received within 2 seconds
  - Scope: Add a Timer in `startCapturing()` that fires after 2 seconds and logs warning if callback counter is still 0
  - Acceptance: Warning logged if audio engine started but no callbacks received
  - Verification: `swift build` passes; (simulate by disconnecting mic) verify warning appears

- [ ] Log if callback receives empty or zero-sample data
  - Scope: Modify tap callback to check if `buffer.frameLength == 0` or if all samples are zero, and log warning
  - Acceptance: Console shows warning for problematic buffers
  - Verification: `swift build` passes; verify warning appears for empty buffers

---

### US-303: Buffer Integrity Logging
As a developer, I want to trace exactly where audio data goes.

**Note:** Much of this logging already exists in stages 1-4. Tasks focus on gaps.

- [ ] Log when audioBuffers array is modified (create, clear, append)
  - Scope: Add logging around `audioBuffers.removeAll()` calls to track when buffer is cleared
  - Acceptance: Console shows "Buffer cleared" each time array is reset
  - Verification: `swift build` passes; record multiple times, verify clear logged between recordings

- [ ] Verify expected vs actual sample count after combining buffers
  - Scope: Already partially implemented; ensure mismatch warning is prominent (current implementation logs but may be missed)
  - Acceptance: Warning is clearly visible if sample count mismatch occurs
  - Verification: `swift build` passes; verify no mismatch warnings during normal recording

- [ ] Add logging if combineBuffersToDataWithStats returns empty data
  - Scope: Modify `combineBuffersToDataWithStats()` to log warning if result is empty despite having buffers
  - Acceptance: Console shows "WARNING: Combined buffer is empty despite X input buffers" if issue occurs
  - Verification: `swift build` passes; verify warning system works

- [ ] Log buffer state summary at capture stop
  - Scope: Add summary log showing: total buffers, total frames expected, actual combined frames, duration
  - Acceptance: Clear summary visible in console when recording stops
  - Verification: `swift build` passes; verify summary logged after recording

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
